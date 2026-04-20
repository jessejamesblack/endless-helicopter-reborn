import { createAdminClient, jsonResponse } from "../_shared/common.ts";
import { requireAuthenticatedUser, touchPlayerAccountLink } from "../_shared/account_linking.ts";
import {
  getCurrentVersionCode,
  getReleaseChannel,
  getReleaseConfig,
  isVersionSupported,
  versionGateResponse,
} from "../_shared/version_gate.ts";

type GetAccountProfilePayload = {
  current_version_code?: number | string;
  release_channel?: string;
  mission_date?: string;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: GetAccountProfilePayload;
  try {
    payload = await request.json() as GetAccountProfilePayload;
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

  const auth = await requireAuthenticatedUser(request);
  if (!auth.ok) {
    return auth.response ?? jsonResponse({ error: "Authentication required." }, 401);
  }

  const linkResult = await supabase
    .from("player_account_links")
    .select("auth_user_id, family_id, player_id, email")
    .eq("auth_user_id", auth.auth_user_id)
    .maybeSingle();

  if (linkResult.error) {
    return jsonResponse({ error: linkResult.error.message }, 500);
  }

  if (!linkResult.data) {
    return jsonResponse({
      authenticated: true,
      linked: false,
      email: auth.email,
    });
  }

  const familyId = String(linkResult.data.family_id ?? "global").trim() || "global";
  const playerId = String(linkResult.data.player_id ?? "").trim();
  const email = auth.email || String(linkResult.data.email ?? "").trim();
  await touchPlayerAccountLink(supabase, auth.auth_user_id, email);

  const profileResult = await supabase.rpc("get_player_profile", {
    p_family_id: familyId,
    p_player_id: playerId,
  });
  if (profileResult.error) {
    return jsonResponse({ error: profileResult.error.message }, 500);
  }

  let dailyProgress: Record<string, unknown> = {};
  const missionDate = String(payload.mission_date ?? "").trim();
  if (missionDate !== "") {
    const dailyResult = await supabase.rpc("get_daily_mission_progress", {
      p_family_id: familyId,
      p_player_id: playerId,
      p_mission_date: missionDate,
    });
    if (dailyResult.error) {
      return jsonResponse({ error: dailyResult.error.message }, 500);
    }
    if (dailyResult.data && typeof dailyResult.data === "object" && !Array.isArray(dailyResult.data)) {
      dailyProgress = dailyResult.data as Record<string, unknown>;
    }
  }

  const profile =
    profileResult.data && typeof profileResult.data === "object" && !Array.isArray(profileResult.data)
      ? { ...(profileResult.data as Record<string, unknown>) }
      : {};

  return jsonResponse({
    authenticated: true,
    linked: true,
    email,
    family_id: familyId,
    player_id: playerId,
    profile,
    daily_progress: dailyProgress,
  });
});
