import { createAdminClient, jsonResponse } from "../_shared/common.ts";
import {
  getCurrentVersionCode,
  getReleaseChannel,
  getReleaseConfig,
  isVersionSupported,
  versionGateResponse,
} from "../_shared/version_gate.ts";

type GetPlayerProfilePayload = {
  current_version_code?: number | string;
  release_channel?: string;
  p_family_id?: string;
  p_player_id?: string;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: GetPlayerProfilePayload;
  try {
    payload = await request.json() as GetPlayerProfilePayload;
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

  const response = await supabase.rpc("get_player_profile", {
    p_family_id: payload.p_family_id,
    p_player_id: payload.p_player_id,
  });

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  const profile =
    response.data && typeof response.data === "object" && !Array.isArray(response.data)
      ? { ...(response.data as Record<string, unknown>) }
      : {};

  if (
    payload.p_family_id &&
    payload.p_player_id &&
    (typeof profile.name !== "string" || profile.name.trim().length === 0)
  ) {
    const nameResult = await supabase
      .from("family_player_profiles")
      .select("name")
      .eq("family_id", payload.p_family_id)
      .eq("player_id", payload.p_player_id)
      .maybeSingle();

    if (!nameResult.error && typeof nameResult.data?.name === "string" && nameResult.data.name.trim().length > 0) {
      profile.name = nameResult.data.name.trim();
    }
  }

  return jsonResponse(profile);
});
