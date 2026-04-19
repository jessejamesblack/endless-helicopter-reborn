import { createAdminClient, jsonResponse, truncate } from "../_shared/common.ts";
import { postDiscordWebhook } from "../_shared/discord_webhook.ts";

type WeeklyRecapPayload = {
  family_id?: string;
  week_key?: string;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const webhookSecret = Deno.env.get("RELEASE_WEBHOOK_SECRET") ?? "";
  if (webhookSecret !== "" && request.headers.get("x-release-webhook-secret") !== webhookSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  let payload: WeeklyRecapPayload = {};
  try {
    payload = await request.json() as WeeklyRecapPayload;
  } catch (_error) {
    payload = {};
  }

  const familyId = String(payload.family_id ?? "global");
  const weekKey = String(payload.week_key ?? currentWeekKey());
  const supabase = createAdminClient();

  const existing = await supabase
    .from("family_weekly_recap_log")
    .select("id")
    .eq("family_id", familyId)
    .eq("week_key", weekKey)
    .maybeSingle();
  if (!existing.error && existing.data) {
    return jsonResponse({ ok: true, skipped: true, reason: "Recap already sent." });
  }

  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const runHistoryResponse = await supabase
    .from("family_run_history")
    .select("name, score, run_summary, created_at")
    .eq("family_id", familyId)
    .gte("created_at", since)
    .order("score", { ascending: false })
    .limit(200);

  if (runHistoryResponse.error) {
    return jsonResponse({ error: runHistoryResponse.error.message }, 500);
  }

  const runs = runHistoryResponse.data ?? [];
  let description = "No activity this week, but the helicopter hangar is ready for the next run.";
  if (runs.length > 0) {
    const topScore = runs[0];
    const nearMissLeader = aggregateMax(runs, "near_misses");
    const missionLeader = aggregateMax(runs, "missions_completed_this_run");
    const unlocks = collectUnlocks(runs);
    const lines = [
      `Top score: ${topScore.name ?? "Pilot"} — ${topScore.score}`,
      nearMissLeader ? `Most near misses: ${nearMissLeader.name} — ${nearMissLeader.value}` : "",
      missionLeader ? `Most daily missions: ${missionLeader.name} — ${missionLeader.value}` : "",
      unlocks.length > 0 ? `New unlocks: ${truncate(unlocks.join(", "), 180)}` : "",
    ].filter((line) => line !== "");
    description = lines.join("\n");
  }

  const posted = await postDiscordWebhook({
    webhookUrl: Deno.env.get("DISCORD_GAME_EVENTS_WEBHOOK_URL") ?? "",
    title: "Weekly Helicopter Recap",
    description,
    color: 0x53c26d,
  });

  await supabase.from("family_weekly_recap_log").upsert({
    family_id: familyId,
    week_key: weekKey,
    status: posted ? "sent" : "skipped",
  }, { onConflict: "family_id,week_key" });

  return jsonResponse({ ok: true, posted, week_key: weekKey });
});

function currentWeekKey(): string {
  const now = new Date();
  const sunday = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  sunday.setUTCDate(sunday.getUTCDate() - sunday.getUTCDay());
  return sunday.toISOString().slice(0, 10);
}

function aggregateMax(rows: Array<Record<string, unknown>>, key: string): { name: string; value: number } | null {
  let bestName = "";
  let bestValue = 0;
  for (const row of rows) {
    const summary = row.run_summary as Record<string, unknown> | null;
    const rawValue = summary?.[key];
    const value = Array.isArray(rawValue) ? rawValue.length : Number(rawValue ?? 0);
    if (Number.isFinite(value) && value > bestValue) {
      bestValue = value;
      bestName = String(row.name ?? "Pilot");
    }
  }
  return bestValue > 0 ? { name: bestName, value: bestValue } : null;
}

function collectUnlocks(rows: Array<Record<string, unknown>>): string[] {
  const unlocks = new Set<string>();
  for (const row of rows) {
    const summary = row.run_summary as Record<string, unknown> | null;
    const postRunUnlocks = summary?.post_run_unlocks;
    if (!Array.isArray(postRunUnlocks)) {
      continue;
    }
    for (const item of postRunUnlocks) {
      if (item && typeof item === "object") {
        const title = String((item as Record<string, unknown>).title ?? "").trim();
        if (title !== "") {
          unlocks.add(title);
        }
      }
    }
  }
  return [...unlocks].slice(0, 6);
}
