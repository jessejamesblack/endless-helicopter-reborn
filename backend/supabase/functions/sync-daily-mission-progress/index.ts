import { createAdminClient, jsonResponse } from "../_shared/common.ts";
import { resolvePlayerContext } from "../_shared/account_linking.ts";
import {
  getCurrentVersionCode,
  getReleaseChannel,
  getReleaseConfig,
  isVersionSupported,
  versionGateResponse,
} from "../_shared/version_gate.ts";

type SyncDailyMissionPayload = {
  current_version_code?: number | string;
  release_channel?: string;
  p_family_id?: string;
  p_player_id?: string;
  p_mission_date?: string;
  p_missions?: unknown;
  p_completed_count?: number | string;
  p_total_count?: number | string;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: SyncDailyMissionPayload;
  try {
    payload = await request.json() as SyncDailyMissionPayload;
  } catch (_error) {
    return jsonResponse({ error: "Invalid payload." }, 400);
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

  const response = await supabase.rpc("sync_daily_mission_progress", {
    p_family_id: playerContext.family_id,
    p_player_id: playerContext.player_id,
    p_mission_date: payload.p_mission_date,
    p_missions: payload.p_missions ?? [],
    p_completed_count: payload.p_completed_count ?? 0,
    p_total_count: payload.p_total_count ?? 5,
  });

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  return jsonResponse(response.data ?? {});
});
