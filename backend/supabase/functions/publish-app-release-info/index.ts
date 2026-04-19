import {
  createAdminClient,
  jsonResponse,
  safeChannel,
  toInt,
} from "../_shared/common.ts";

type PublishPayload = {
  latest_version_code?: number | string;
  latest_version_name?: string;
  minimum_supported_version_code?: number | string;
  apk_download_url?: string;
  release_page_url?: string;
  release_notes_url?: string;
  update_message?: string;
  force_update_message?: string;
  release_summary?: string;
  checksum_sha256?: string;
  apk_size_bytes?: number | string;
  build_sha?: string;
  channel?: string;
  release_metadata?: Record<string, unknown>;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const webhookSecret = Deno.env.get("RELEASE_WEBHOOK_SECRET") ?? "";
  if (webhookSecret !== "" && request.headers.get("x-release-webhook-secret") !== webhookSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  let payload: PublishPayload;
  try {
    payload = await request.json() as PublishPayload;
  } catch (_error) {
    return jsonResponse({ error: "Invalid payload." }, 400);
  }

  const latestVersionCode = toInt(payload.latest_version_code, 0);
  const latestVersionName = String(payload.latest_version_name ?? "").trim();
  const apkDownloadUrl = String(payload.apk_download_url ?? "").trim();
  const releasePageUrl = String(payload.release_page_url ?? "").trim();
  const releaseNotesUrl = String(payload.release_notes_url ?? releasePageUrl).trim();
  if (latestVersionCode <= 0 || latestVersionName === "" || apkDownloadUrl === "" || releasePageUrl === "") {
    return jsonResponse({ error: "Missing required release fields." }, 400);
  }

  const channel = safeChannel(payload.channel);
  const minimumSupportedVersionCode = Math.max(
    toInt(payload.minimum_supported_version_code, latestVersionCode),
    latestVersionCode,
  );
  const supabase = createAdminClient();
  const upsertPayload = {
    channel,
    latest_version_code: latestVersionCode,
    latest_version_name: latestVersionName,
    minimum_supported_version_code: minimumSupportedVersionCode,
    apk_download_url: apkDownloadUrl,
    release_page_url: releasePageUrl,
    release_notes_url: releaseNotesUrl,
    update_message: String(payload.update_message ?? "A new build is ready."),
    force_update_message: String(
      payload.force_update_message ?? "This version is too old to play. Please update to continue.",
    ),
    release_summary: String(payload.release_summary ?? "").trim(),
    checksum_sha256: String(payload.checksum_sha256 ?? "").trim() || null,
    apk_size_bytes: toInt(payload.apk_size_bytes, 0) || null,
    build_sha: String(payload.build_sha ?? "").trim() || null,
    release_metadata: payload.release_metadata ?? {},
    updated_at: new Date().toISOString(),
  };

  const response = await supabase
    .from("app_release_channels")
    .upsert(upsertPayload, { onConflict: "channel" })
    .select("*")
    .single();

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  return jsonResponse(response.data);
});
