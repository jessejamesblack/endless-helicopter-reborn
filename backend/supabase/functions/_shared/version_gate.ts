import { jsonResponse, safeChannel, toInt } from "./common.ts";

export async function getReleaseConfig(
  supabaseClient: any,
  channelInput: unknown = "stable",
): Promise<Record<string, unknown>> {
  const channel = safeChannel(channelInput);
  const requested = await supabaseClient
    .from("app_release_channels")
    .select("*")
    .eq("channel", channel)
    .maybeSingle();

  if (!requested.error && requested.data) {
    return requested.data as Record<string, unknown>;
  }

  if (channel !== "stable") {
    const fallback = await supabaseClient
      .from("app_release_channels")
      .select("*")
      .eq("channel", "stable")
      .maybeSingle();
    if (!fallback.error && fallback.data) {
      return fallback.data as Record<string, unknown>;
    }
  }

  return {
    channel,
    latest_version_code: 0,
    latest_version_name: "",
    minimum_supported_version_code: 0,
    apk_download_url: "",
    release_page_url: "",
    release_notes_url: "",
    update_message: "A new build is ready.",
    force_update_message: "This build is too old. Please update to continue.",
  };
}

export function isVersionSupported(
  currentVersionCode: number,
  minimumSupportedVersionCode: number,
): boolean {
  if (currentVersionCode <= 0) {
    return false;
  }
  if (minimumSupportedVersionCode <= 0) {
    return true;
  }
  return currentVersionCode >= minimumSupportedVersionCode;
}

export function versionGateResponse(releaseConfig: Record<string, unknown> = {}): Response {
  return jsonResponse({
    error: "upgrade_required",
    message: String(
      releaseConfig.force_update_message ??
        "This build is too old. Please update to continue.",
    ),
    minimum_supported_version_code: toInt(
      releaseConfig.minimum_supported_version_code,
      0,
    ),
    latest_version_code: toInt(releaseConfig.latest_version_code, 0),
    latest_version_name: String(releaseConfig.latest_version_name ?? ""),
    release_page_url: String(releaseConfig.release_page_url ?? ""),
    apk_download_url: String(releaseConfig.apk_download_url ?? ""),
    release_notes_url: String(releaseConfig.release_notes_url ?? ""),
    channel: safeChannel(releaseConfig.channel),
  }, 426);
}

export function getCurrentVersionCode(
  payload: Record<string, unknown> = {},
  request?: Request,
): number {
  return toInt(
    payload.current_version_code ??
      request?.headers.get("x-current-version-code") ??
      0,
    0,
  );
}

export function getReleaseChannel(
  payload: Record<string, unknown> = {},
  request?: Request,
): "stable" | "beta" | "dev" {
  return safeChannel(payload.release_channel ?? request?.headers.get("x-release-channel"));
}
