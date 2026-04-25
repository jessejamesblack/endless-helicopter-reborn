import { GoogleAuth } from "npm:google-auth-library@9";
import {
  createAdminClient,
  jsonResponse,
  requireEnv,
  safeChannel,
  toInt,
  truncate,
} from "../_shared/common.ts";

type AppUpdatePayload = {
  latest_version_code?: number | string;
  latest_version_name?: string;
  minimum_supported_version_code?: number | string;
  apk_download_url?: string;
  release_page_url?: string;
  release_notes_url?: string;
  release_summary?: string;
  channel?: string;
};

type PushDeviceRow = {
  id: number;
  family_id: string;
  player_id: string;
  device_id: string;
  fcm_token: string;
  platform: string;
  notifications_enabled: boolean;
  app_version_code: number | null;
  release_channel: string | null;
};

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const FCM_SEND_URL = "https://fcm.googleapis.com/v1/projects/%s/messages:send";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const webhookSecret = Deno.env.get("RELEASE_WEBHOOK_SECRET") ?? "";
  if (webhookSecret !== "" && request.headers.get("x-release-webhook-secret") !== webhookSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  let payload: AppUpdatePayload;
  try {
    payload = await request.json() as AppUpdatePayload;
  } catch (_error) {
    return jsonResponse({ error: "Invalid payload." }, 400);
  }

  const latestVersionCode = toInt(payload.latest_version_code, 0);
  const latestVersionName = String(payload.latest_version_name ?? "").trim();
  const apkDownloadUrl = String(payload.apk_download_url ?? "").trim();
  const releasePageUrl = String(payload.release_page_url ?? "").trim();
  const releaseNotesUrl = String(payload.release_notes_url ?? releasePageUrl).trim();
  const minimumSupportedVersionCode = Math.max(
    latestVersionCode,
    toInt(payload.minimum_supported_version_code, latestVersionCode),
  );
  const channel = safeChannel(payload.channel);
  if (latestVersionCode <= 0 || latestVersionName === "" || apkDownloadUrl === "" || releasePageUrl === "") {
    return jsonResponse({ error: "Missing required release fields." }, 400);
  }

  const supabase = createAdminClient();
  const devicesResponse = await supabase
    .from("family_push_devices")
    .select("id, family_id, player_id, device_id, fcm_token, platform, notifications_enabled, app_version_code, release_channel")
    .eq("platform", "android")
    .eq("notifications_enabled", true)
    .eq("release_channel", channel);

  if (devicesResponse.error) {
    return jsonResponse({ error: devicesResponse.error.message }, 500);
  }

  const devices = ((devicesResponse.data ?? []) as PushDeviceRow[])
    .filter((device) => toInt(device.app_version_code, 0) < latestVersionCode);
  if (devices.length === 0) {
    return jsonResponse({ delivered: 0, skipped: true, reason: "No outdated devices." });
  }

  const historyResponse = await supabase
    .from("app_update_push_history")
    .select("device_id")
    .eq("channel", channel)
    .eq("version_code", latestVersionCode);

  if (historyResponse.error) {
    return jsonResponse({ error: historyResponse.error.message }, 500);
  }

  const alreadySent = new Set((historyResponse.data ?? []).map((row) => String(row.device_id)));
  const eligibleDevices = devices.filter((device) => !alreadySent.has(device.device_id));
  if (eligibleDevices.length === 0) {
    return jsonResponse({ delivered: 0, skipped: true, reason: "Push already sent for this version." });
  }

  const auth = new GoogleAuth({
    credentials: JSON.parse(requireEnv("FCM_SERVICE_ACCOUNT_JSON")),
    scopes: [FCM_SCOPE],
  });
  const client = await auth.getClient();
  const accessToken = await client.getAccessToken();
  if (!accessToken.token) {
    return jsonResponse({ error: "Could not obtain FCM access token." }, 500);
  }

  const sendUrl = FCM_SEND_URL.replace("%s", requireEnv("FCM_PROJECT_ID"));
  const notificationTitle = "Update Available";
  const notificationBody = makeUpdateNotificationBody(latestVersionName, payload.release_summary);
  const historyRows: Record<string, unknown>[] = [];
  const invalidTokenIds: number[] = [];

  for (const device of eligibleDevices) {
    const fcmResponse = await fetch(sendUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: device.fcm_token,
          data: {
            type: "app_update",
            latest_version_code: String(latestVersionCode),
            latest_version_name: latestVersionName,
            minimum_supported_version_code: String(minimumSupportedVersionCode),
            apk_download_url: apkDownloadUrl,
            release_page_url: releasePageUrl,
            release_notes_url: releaseNotesUrl,
            title: notificationTitle,
            body: notificationBody,
            release_summary: truncate(payload.release_summary ?? "", 240),
          },
          android: {
            priority: "high",
          },
        },
      }),
    });

    const responseText = await fcmResponse.text();
    const status = classifyFcmStatus(fcmResponse.status, responseText);
    historyRows.push({
      channel,
      version_code: latestVersionCode,
      family_id: device.family_id,
      player_id: device.player_id,
      device_id: device.device_id,
      status,
    });
    if (status === "invalid_token") {
      invalidTokenIds.push(device.id);
    }
  }

  if (historyRows.length > 0) {
    await supabase.from("app_update_push_history").upsert(historyRows, {
      onConflict: "channel,version_code,device_id",
      ignoreDuplicates: false,
    });
  }

  if (invalidTokenIds.length > 0) {
    await supabase.from("family_push_devices").delete().in("id", invalidTokenIds);
  }

  return jsonResponse({
    delivered: historyRows.filter((row) => row.status === "sent").length,
    invalidated: invalidTokenIds.length,
    skipped: eligibleDevices.length === 0,
  });
});

function makeUpdateNotificationBody(versionName: string, releaseSummary?: string): string {
  const summary = truncate(String(releaseSummary ?? "").trim(), 120);
  if (summary !== "") {
    return `Version ${versionName} is ready. ${summary}`;
  }
  return `Version ${versionName} is ready to install.`;
}

function classifyFcmStatus(statusCode: number, responseText: string): string {
  if (statusCode >= 200 && statusCode < 300) {
    return "sent";
  }
  if (
    responseText.includes("UNREGISTERED") ||
    responseText.includes("registration-token-not-registered") ||
    responseText.includes("Requested entity was not found")
  ) {
    return "invalid_token";
  }
  return "failed";
}
