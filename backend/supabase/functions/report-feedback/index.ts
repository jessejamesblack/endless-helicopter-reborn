import {
  createAdminClient,
  jsonResponse,
  sanitizeForLogs,
  truncate,
} from "../_shared/common.ts";
import { postDiscordWebhook } from "../_shared/discord_webhook.ts";

type FeedbackPayload = {
  category?: string;
  message?: string;
  bug_report?: string;
  context?: Record<string, unknown>;
};

const ALLOWED_CATEGORIES = new Set([
  "bug",
  "idea",
  "controls",
  "visual",
  "leaderboard",
  "missions",
  "update/install",
  "audio",
  "background/music",
]);

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: FeedbackPayload;
  try {
    payload = await request.json() as FeedbackPayload;
  } catch (_error) {
    return jsonResponse({ error: "Invalid payload." }, 400);
  }

  const category = ALLOWED_CATEGORIES.has(String(payload.category ?? "").trim())
    ? String(payload.category)
    : "bug";
  const message = truncate(payload.message ?? "", 4000).trim();
  if (message === "") {
    return jsonResponse({ error: "Feedback message is required." }, 400);
  }

  const bugReport = truncate(payload.bug_report ?? "", 8000).trim();
  const context = sanitizeForLogs(payload.context ?? {}) as Record<string, unknown>;
  const supabase = createAdminClient();
  const insertResponse = await supabase
    .from("family_feedback_reports")
    .insert({
      category,
      message,
      bug_report: bugReport === "" ? null : bugReport,
      context,
    })
    .select("id")
    .single();

  if (insertResponse.error) {
    return jsonResponse({ error: insertResponse.error.message }, 500);
  }

  const discordWebhook = Deno.env.get("DISCORD_BUGS_WEBHOOK_URL") ?? "";
  const buildSummary = context.build ?? {};
  await postDiscordWebhook({
    webhookUrl: discordWebhook,
    title: "Family feedback received",
    description: truncate(message, 400),
    color: 0xe3ad40,
    fields: [
      { name: "Category", value: category, inline: true },
      { name: "Version", value: truncate(buildSummary["version_name"] ?? "unknown", 64), inline: true },
      { name: "Channel", value: truncate(buildSummary["release_channel"] ?? "stable", 32), inline: true },
      bugReport === "" ? null : { name: "Bug report", value: truncate(bugReport, 1000) },
    ].filter(Boolean) as Array<{ name: string; value: string; inline?: boolean }>,
  });

  return jsonResponse({ ok: true, id: insertResponse.data.id });
});
