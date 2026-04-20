import { createAdminClient, jsonResponse } from "../_shared/common.ts";
import { resolvePlayerContext } from "../_shared/account_linking.ts";
import {
  getCurrentVersionCode,
  getReleaseChannel,
  getReleaseConfig,
  isVersionSupported,
  versionGateResponse,
} from "../_shared/version_gate.ts";

type MarkNotificationsReadPayload = {
  current_version_code?: number | string;
  release_channel?: string;
  family_id?: string;
  player_id?: string;
  ids?: Array<number | string>;
  read_at?: string;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: MarkNotificationsReadPayload;
  try {
    payload = await request.json() as MarkNotificationsReadPayload;
  } catch (_error) {
    return jsonResponse({ error: "Invalid payload." }, 400);
  }

  const ids = Array.isArray(payload.ids)
    ? payload.ids
      .map((value) => Number(value))
      .filter((value) => Number.isFinite(value) && value > 0)
    : [];
  if (ids.length === 0) {
    return jsonResponse({ ok: true, updated: 0 });
  }

  const supabase = createAdminClient();
  const releaseConfig = await getReleaseConfig(
    supabase,
    getReleaseChannel(payload as Record<string, unknown>, request),
  );
  const currentVersionCode = getCurrentVersionCode(payload as Record<string, unknown>, request);
  if (!isVersionSupported(currentVersionCode, Number(releaseConfig.minimum_supported_version_code ?? 0))) {
    return versionGateResponse(releaseConfig);
  }

  const playerContext = await resolvePlayerContext(supabase, request, payload as Record<string, unknown>);
  if (!playerContext.ok) {
    return playerContext.response ?? jsonResponse({ error: "Could not resolve player context." }, 500);
  }
  if (playerContext.family_id === "" || playerContext.player_id === "") {
    return jsonResponse({ error: "Family id and player id are required." }, 400);
  }

  const response = await supabase
    .from("family_notifications")
    .update({
      read_at: String(payload.read_at ?? new Date().toISOString()),
    })
    .eq("family_id", playerContext.family_id)
    .eq("target_player_id", playerContext.player_id)
    .in("id", ids);

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  return jsonResponse({ ok: true, updated: ids.length });
});
