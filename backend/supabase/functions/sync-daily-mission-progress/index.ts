import { createAdminClient, jsonResponse, toInt } from "../_shared/common.ts";
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

type DailyMission = Record<string, unknown>;

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

  const existingResponse = await supabase.rpc("get_daily_mission_progress", {
    p_family_id: payload.p_family_id,
    p_player_id: payload.p_player_id,
    p_mission_date: payload.p_mission_date,
  });

  if (existingResponse.error) {
    return jsonResponse({ error: existingResponse.error.message }, 500);
  }

  const existingProgress = isRecord(existingResponse.data) ? existingResponse.data : {};
  const mergedMissions = mergeDailyMissions(existingProgress.missions, payload.p_missions);
  const completedCount = Math.max(
    toNonNegativeInt(existingProgress.completed_count, 0),
    toNonNegativeInt(payload.p_completed_count, 0),
    countCompletedMissions(mergedMissions),
  );
  const totalCount = Math.max(
    toNonNegativeInt(existingProgress.total_count, 0),
    toNonNegativeInt(payload.p_total_count, 5),
    mergedMissions.length,
    1,
  );

  const response = await supabase.rpc("sync_daily_mission_progress", {
    p_family_id: payload.p_family_id,
    p_player_id: payload.p_player_id,
    p_mission_date: payload.p_mission_date,
    p_missions: mergedMissions,
    p_completed_count: completedCount,
    p_total_count: totalCount,
  });

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  return jsonResponse(response.data ?? {});
});

function mergeDailyMissions(existingValue: unknown, incomingValue: unknown): DailyMission[] {
  const existingMissions = toMissionArray(existingValue);
  const incomingMissions = toMissionArray(incomingValue);
  if (existingMissions.length === 0) {
    return incomingMissions.map((mission) => normalizeMissionCompletion(mission));
  }
  if (incomingMissions.length === 0) {
    return existingMissions.map((mission) => normalizeMissionCompletion(mission));
  }

  const existingByKey = new Map<string, DailyMission>();
  for (const mission of existingMissions) {
    const key = missionKey(mission);
    if (key) {
      existingByKey.set(key, mission);
    }
  }

  const merged: DailyMission[] = [];
  const seen = new Set<string>();
  for (const incomingMission of incomingMissions) {
    const key = missionKey(incomingMission);
    if (!key) {
      merged.push(normalizeMissionCompletion(incomingMission));
      continue;
    }
    seen.add(key);
    merged.push(mergeMission(existingByKey.get(key), incomingMission));
  }

  for (const existingMission of existingMissions) {
    const key = missionKey(existingMission);
    if (!key || seen.has(key)) {
      continue;
    }
    merged.push(normalizeMissionCompletion(existingMission));
  }

  return merged;
}

function mergeMission(existingMission: DailyMission | undefined, incomingMission: DailyMission): DailyMission {
  if (!existingMission) {
    return normalizeMissionCompletion(incomingMission);
  }

  const merged: DailyMission = { ...existingMission, ...incomingMission };
  const progress = Math.max(
    toFiniteNumber(existingMission.progress, 0),
    toFiniteNumber(incomingMission.progress, 0),
  );
  const target = toFiniteNumber(merged.target, 1);
  const completed = Boolean(existingMission.completed) ||
    Boolean(incomingMission.completed) ||
    progress >= target;
  merged.progress = progress;
  merged.completed = completed;
  return merged;
}

function normalizeMissionCompletion(mission: DailyMission): DailyMission {
  const normalized: DailyMission = { ...mission };
  const progress = toFiniteNumber(normalized.progress, 0);
  const target = toFiniteNumber(normalized.target, 1);
  normalized.progress = progress;
  normalized.completed = Boolean(normalized.completed) || progress >= target;
  return normalized;
}

function toMissionArray(value: unknown): DailyMission[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(isRecord).map((mission) => ({ ...mission }));
}

function missionKey(mission: DailyMission): string {
  const id = String(mission.id ?? "").trim();
  if (id) {
    return id;
  }
  const slot = String(mission.slot ?? "").trim();
  const type = String(mission.type ?? "").trim();
  return slot || type ? `${slot}:${type}` : "";
}

function countCompletedMissions(missions: DailyMission[]): number {
  return missions.reduce((count, mission) => count + (Boolean(mission.completed) ? 1 : 0), 0);
}

function toNonNegativeInt(value: unknown, fallback: number): number {
  return Math.max(toInt(value, fallback), 0);
}

function toFiniteNumber(value: unknown, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
