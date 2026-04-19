import { createClient } from "jsr:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

type DailyMissionPayload = {
  type: string;
  family_id?: string;
  mission_date?: string;
};

type PushDeviceRow = {
  id: number;
  family_id: string;
  player_id: string;
  device_id: string;
  fcm_token: string;
  platform: string;
  notifications_enabled: boolean;
  daily_missions_enabled: boolean;
};

type MissionProgressRow = {
  player_id: string;
  completed_count: number;
  total_count: number;
};

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const FCM_SEND_URL = "https://fcm.googleapis.com/v1/projects/%s/messages:send";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const webhookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
  if (webhookSecret !== "" && request.headers.get("x-push-webhook-secret") !== webhookSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const payload = await parsePayload(request);
  if (!payload) {
    return jsonResponse({ error: "Invalid payload." }, 400);
  }

  const familyId = payload.family_id ?? "global";
  const missionDate = payload.mission_date ?? new Date().toISOString().slice(0, 10);
  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
  const fcmProjectId = requireEnv("FCM_PROJECT_ID");
  const serviceAccountJson = requireEnv("FCM_SERVICE_ACCOUNT_JSON");
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const devicesResponse = await supabase
    .from("family_push_devices")
    .select("id, family_id, player_id, device_id, fcm_token, platform, notifications_enabled, daily_missions_enabled")
    .eq("family_id", familyId)
    .eq("platform", "android")
    .eq("notifications_enabled", true)
    .eq("daily_missions_enabled", true);

  if (devicesResponse.error) {
    return jsonResponse({ error: devicesResponse.error.message }, 500);
  }

  const progressResponse = await supabase
    .from("family_daily_mission_progress")
    .select("player_id, completed_count, total_count")
    .eq("family_id", familyId)
    .eq("mission_date", missionDate);

  if (progressResponse.error) {
    return jsonResponse({ error: progressResponse.error.message }, 500);
  }

  const progressByPlayer = new Map<string, MissionProgressRow>();
  for (const row of (progressResponse.data ?? []) as MissionProgressRow[]) {
    progressByPlayer.set(row.player_id, row);
  }

  const eligibleDevices = ((devicesResponse.data ?? []) as PushDeviceRow[]).filter((device) => {
    const progress = progressByPlayer.get(device.player_id);
    if (!progress) {
      return true;
    }
    return (progress.completed_count ?? 0) < (progress.total_count ?? 3);
  });

  if (eligibleDevices.length === 0) {
    await supabase.from("family_push_delivery_log").insert({
      family_id: familyId,
      target_player_id: "daily_missions",
      notification_type: "daily_missions",
      status: "no_eligible_devices",
      response_code: 200,
      response_body: `No Android devices were eligible for ${missionDate}.`,
    });
    return jsonResponse({ delivered: 0, skipped: true }, 200);
  }

  const auth = new GoogleAuth({
    credentials: JSON.parse(serviceAccountJson),
    scopes: [FCM_SCOPE],
  });
  const client = await auth.getClient();
  const accessToken = await client.getAccessToken();
  if (!accessToken.token) {
    return jsonResponse({ error: "Could not obtain FCM access token." }, 500);
  }

  const sentLogRows: Record<string, unknown>[] = [];
  const invalidTokenIds: number[] = [];
  const sendUrl = FCM_SEND_URL.replace("%s", fcmProjectId);

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
            type: "daily_missions",
            family_id: familyId,
            mission_date: missionDate,
            title: "Daily Missions Ready",
            body: "New missions are live. Complete them to unlock vehicles and finishes.",
          },
          android: {
            priority: "high",
          },
        },
      }),
    });

    const responseText = await fcmResponse.text();
    const status = classifyFcmStatus(fcmResponse.status, responseText);
    sentLogRows.push({
      family_id: device.family_id,
      target_player_id: device.player_id,
      device_id: device.device_id,
      fcm_token: device.fcm_token,
      notification_type: "daily_missions",
      status,
      response_code: fcmResponse.status,
      response_body: responseText,
    });

    if (status === "invalid_token") {
      invalidTokenIds.push(device.id);
    }
  }

  if (sentLogRows.length > 0) {
    await supabase.from("family_push_delivery_log").insert(sentLogRows);
  }

  if (invalidTokenIds.length > 0) {
    await supabase.from("family_push_devices").delete().in("id", invalidTokenIds);
  }

  return jsonResponse({
    delivered: sentLogRows.filter((row) => row.status === "sent").length,
    invalidated: invalidTokenIds.length,
  });
});

async function parsePayload(request: Request): Promise<DailyMissionPayload | null> {
  try {
    const payload = await request.json() as DailyMissionPayload;
    if (payload.type !== "daily_missions") {
      return null;
    }
    return payload;
  } catch (_error) {
    return null;
  }
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

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
