import { createAdminClient, jsonResponse } from "../_shared/common.ts";
import { resolvePlayerContext } from "../_shared/account_linking.ts";
import {
  getCurrentVersionCode,
  getReleaseChannel,
  getReleaseConfig,
  isVersionSupported,
  versionGateResponse,
} from "../_shared/version_gate.ts";

type SyncPlayerProfilePayload = {
  current_version_code?: number | string;
  release_channel?: string;
  p_family_id?: string;
  p_player_id?: string;
  p_name?: string | null;
  p_equipped_skin_id?: string;
  p_unlocked_skins?: unknown;
  p_total_daily_missions_completed?: number | string;
  p_daily_streak?: number | string;
  p_last_completed_daily_date?: string | null;
  p_daily_reminders_enabled?: boolean;
  p_profile_summary?: Record<string, unknown>;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: SyncPlayerProfilePayload;
  try {
    payload = await request.json() as SyncPlayerProfilePayload;
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

  const response = await supabase.rpc("sync_player_profile", {
    p_family_id: playerContext.family_id,
    p_player_id: playerContext.player_id,
    p_name: payload.p_name ?? null,
    p_equipped_skin_id: payload.p_equipped_skin_id,
    p_unlocked_skins: payload.p_unlocked_skins,
    p_total_daily_missions_completed: payload.p_total_daily_missions_completed,
    p_daily_streak: payload.p_daily_streak,
    p_last_completed_daily_date: payload.p_last_completed_daily_date ?? null,
    p_daily_reminders_enabled: payload.p_daily_reminders_enabled,
    p_profile_summary: payload.p_profile_summary ?? {},
  });

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  return jsonResponse(response.data ?? {});
});
