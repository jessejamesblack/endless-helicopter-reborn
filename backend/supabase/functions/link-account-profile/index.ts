import { createAdminClient, jsonResponse } from "../_shared/common.ts";
import { requireAuthenticatedUser, touchPlayerAccountLink } from "../_shared/account_linking.ts";
import {
  getCurrentVersionCode,
  getReleaseChannel,
  getReleaseConfig,
  isVersionSupported,
  versionGateResponse,
} from "../_shared/version_gate.ts";

type LinkAccountPayload = {
  current_version_code?: number | string;
  release_channel?: string;
  family_id?: string;
  player_id?: string;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: LinkAccountPayload;
  try {
    payload = await request.json() as LinkAccountPayload;
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

  const familyId = String(payload.family_id ?? "global").trim() || "global";
  const playerId = String(payload.player_id ?? "").trim();
  if (playerId === "") {
    return jsonResponse({ error: "player_id is required." }, 400);
  }

  const existingLink = await supabase
    .from("player_account_links")
    .select("auth_user_id, family_id, player_id, email")
    .eq("auth_user_id", auth.auth_user_id)
    .maybeSingle();

  if (existingLink.error) {
    return jsonResponse({ error: existingLink.error.message }, 500);
  }

  if (existingLink.data) {
    await touchPlayerAccountLink(
      supabase,
      auth.auth_user_id,
      auth.email || String(existingLink.data.email ?? "").trim(),
    );
    return jsonResponse({
      ok: true,
      linked: true,
      already_linked: true,
      family_id: String(existingLink.data.family_id ?? familyId),
      player_id: String(existingLink.data.player_id ?? playerId),
      email: auth.email || String(existingLink.data.email ?? "").trim(),
    });
  }

  const playerClaim = await supabase
    .from("player_account_links")
    .select("auth_user_id")
    .eq("family_id", familyId)
    .eq("player_id", playerId)
    .maybeSingle();

  if (playerClaim.error) {
    return jsonResponse({ error: playerClaim.error.message }, 500);
  }

  if (playerClaim.data && String(playerClaim.data.auth_user_id ?? "") !== auth.auth_user_id) {
    return jsonResponse({
      error: "profile_already_linked",
      message: "That profile is already linked to another account.",
    }, 409);
  }

  const now = new Date().toISOString();
  const upsertResponse = await supabase
    .from("player_account_links")
    .upsert({
      auth_user_id: auth.auth_user_id,
      family_id: familyId,
      player_id: playerId,
      email: auth.email || null,
      linked_at: now,
      last_sign_in_at: now,
    }, { onConflict: "auth_user_id" })
    .select("family_id, player_id, email")
    .single();

  if (upsertResponse.error) {
    return jsonResponse({ error: upsertResponse.error.message }, 500);
  }

  return jsonResponse({
    ok: true,
    linked: true,
    family_id: String(upsertResponse.data.family_id ?? familyId),
    player_id: String(upsertResponse.data.player_id ?? playerId),
    email: auth.email || String(upsertResponse.data.email ?? "").trim(),
  });
});
