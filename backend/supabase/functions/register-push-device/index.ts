import { createAdminClient, jsonResponse, safeChannel, toInt, truncate } from "../_shared/common.ts";

type RegisterPushDevicePayload = {
  family_id?: string;
  player_id?: string;
  device_id?: string;
  fcm_token?: string;
  platform?: string;
  device_label?: string;
  notifications_enabled?: boolean;
  daily_missions_enabled?: boolean;
  last_seen_at?: string;
  app_version_code?: number | string;
  app_version_name?: string;
  build_sha?: string;
  release_channel?: string;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST" && request.method !== "PATCH") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: RegisterPushDevicePayload;
  try {
    payload = await request.json() as RegisterPushDevicePayload;
  } catch (_error) {
    return jsonResponse({ error: "Invalid payload." }, 400);
  }

  const familyId = String(payload.family_id ?? "").trim();
  const playerId = String(payload.player_id ?? "").trim();
  const deviceId = String(payload.device_id ?? "").trim();
  const fcmToken = String(payload.fcm_token ?? "").trim();
  if (familyId === "" || playerId === "" || deviceId === "" || fcmToken === "") {
    return jsonResponse({ error: "family_id, player_id, device_id, and fcm_token are required." }, 400);
  }

  const supabase = createAdminClient();
  const row = {
    family_id: familyId,
    player_id: playerId,
    device_id: deviceId,
    fcm_token: fcmToken,
    platform: String(payload.platform ?? "android").trim() || "android",
    device_label: truncate(payload.device_label ?? "", 128).trim() || null,
    notifications_enabled: Boolean(payload.notifications_enabled ?? true),
    daily_missions_enabled: Boolean(payload.daily_missions_enabled ?? true),
    last_seen_at: String(payload.last_seen_at ?? new Date().toISOString()),
    app_version_code: toInt(payload.app_version_code, 0) || null,
    app_version_name: truncate(payload.app_version_name ?? "", 64).trim() || null,
    build_sha: truncate(payload.build_sha ?? "", 128).trim() || null,
    release_channel: safeChannel(payload.release_channel),
  };

  const existingByToken = await supabase
    .from("family_push_devices")
    .select("id, family_id, player_id, device_id")
    .eq("fcm_token", fcmToken)
    .maybeSingle();

  if (!existingByToken.error && existingByToken.data) {
    const existing = existingByToken.data;
    if (
      String(existing.family_id ?? "") !== familyId ||
      String(existing.player_id ?? "") !== playerId ||
      String(existing.device_id ?? "") !== deviceId
    ) {
      const deleteResponse = await supabase
        .from("family_push_devices")
        .delete()
        .eq("id", existing.id);
      if (deleteResponse.error) {
        return jsonResponse({ error: deleteResponse.error.message }, 500);
      }
    }
  }

  const existingByDevice = await supabase
    .from("family_push_devices")
    .select("id, family_id, player_id, fcm_token")
    .eq("family_id", familyId)
    .eq("device_id", deviceId);

  if (!existingByDevice.error && Array.isArray(existingByDevice.data) && existingByDevice.data.length > 0) {
    const obsoleteDeviceIds = existingByDevice.data
      .filter((row) =>
        String(row.player_id ?? "") !== playerId ||
        String(row.fcm_token ?? "") !== fcmToken
      )
      .map((row) => Number(row.id))
      .filter((value) => Number.isFinite(value) && value > 0);
    if (obsoleteDeviceIds.length > 0) {
      const deleteResponse = await supabase
        .from("family_push_devices")
        .delete()
        .in("id", obsoleteDeviceIds);
      if (deleteResponse.error) {
        return jsonResponse({ error: deleteResponse.error.message }, 500);
      }
    }
  }

  const response = await supabase
    .from("family_push_devices")
    .upsert(row, { onConflict: "family_id,player_id,device_id" })
    .select("id")
    .single();

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  return jsonResponse({ ok: true, id: response.data.id });
});
