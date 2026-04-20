import { createAdminClient, jsonResponse } from "../_shared/common.ts";
import {
  getCurrentVersionCode,
  getReleaseChannel,
  getReleaseConfig,
  isVersionSupported,
  versionGateResponse,
} from "../_shared/version_gate.ts";

type GetDailyMissionPayload = {
  current_version_code?: number | string;
  release_channel?: string;
  p_family_id?: string;
  p_player_id?: string;
  p_mission_date?: string;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: GetDailyMissionPayload;
  try {
    payload = await request.json() as GetDailyMissionPayload;
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

  const response = await supabase.rpc("get_daily_mission_progress", {
    p_family_id: payload.p_family_id,
    p_player_id: payload.p_player_id,
    p_mission_date: payload.p_mission_date,
  });

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  return jsonResponse(response.data ?? {});
});
