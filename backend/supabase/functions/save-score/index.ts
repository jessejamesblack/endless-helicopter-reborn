import { createAdminClient, jsonResponse } from "../_shared/common.ts";
import { resolvePlayerContext } from "../_shared/account_linking.ts";
import {
  getCurrentVersionCode,
  getReleaseChannel,
  getReleaseConfig,
  isVersionSupported,
  versionGateResponse,
} from "../_shared/version_gate.ts";

type SubmitScorePayload = {
  current_version_code?: number | string;
  release_channel?: string;
  p_family_id?: string;
  p_player_id?: string;
  p_name?: string;
  p_score?: number | string;
  p_run_summary?: Record<string, unknown>;
  p_equipped_skin_id?: string | null;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: SubmitScorePayload;
  try {
    payload = await request.json() as SubmitScorePayload;
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

  const response = await supabase.rpc("submit_family_score_v2", {
    p_family_id: playerContext.family_id,
    p_player_id: playerContext.player_id,
    p_name: payload.p_name,
    p_score: payload.p_score,
    p_run_summary: payload.p_run_summary ?? {},
    p_equipped_skin_id: payload.p_equipped_skin_id ?? null,
  });

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  return jsonResponse(response.data ?? {});
});
