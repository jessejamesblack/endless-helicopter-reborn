import { createAdminClient, jsonResponse, toInt, truncate } from "../_shared/common.ts";
import { resolvePlayerContext } from "../_shared/account_linking.ts";
import {
  getCurrentVersionCode,
  getReleaseChannel,
  getReleaseConfig,
  isVersionSupported,
  versionGateResponse,
} from "../_shared/version_gate.ts";

type GetNotificationsPayload = {
  current_version_code?: number | string;
  release_channel?: string;
  family_id?: string;
  player_id?: string;
  limit?: number | string;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: GetNotificationsPayload;
  try {
    payload = await request.json() as GetNotificationsPayload;
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

  const response = await supabase
    .from("family_notifications")
    .select("id, challenger_name, challenger_score, beaten_score, created_at")
    .eq("family_id", playerContext.family_id)
    .eq("target_player_id", playerContext.player_id)
    .is("read_at", null)
    .order("created_at", { ascending: false })
    .limit(Math.max(1, Math.min(25, toInt(payload.limit, 5))));

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  return jsonResponse((response.data ?? []).map((row) => ({
    id: Number(row.id ?? 0),
    challenger_name: truncate(row.challenger_name ?? "Player", 64),
    challenger_score: Number(row.challenger_score ?? 0),
    beaten_score: Number(row.beaten_score ?? 0),
    created_at: String(row.created_at ?? ""),
  })));
});
