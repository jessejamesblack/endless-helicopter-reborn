import {
  buildFingerprint,
  createAdminClient,
  jsonResponse,
  sanitizeForLogs,
  truncate,
} from "../_shared/common.ts";
import { sendEmailAlert } from "../_shared/email_alert.ts";

type ClientErrorPayload = {
  timestamp?: string;
  severity?: string;
  category?: string;
  message?: string;
  fingerprint?: string;
  context?: Record<string, unknown>;
  build?: Record<string, unknown>;
  runtime?: Record<string, unknown>;
};

const ALERTABLE_SEVERITIES = new Set(["error", "fatal"]);
const ALLOWED_SEVERITIES = new Set(["debug", "info", "warning", "error", "fatal"]);
const EMAIL_RATE_LIMIT_MINUTES = 20;

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: ClientErrorPayload;
  try {
    payload = await request.json() as ClientErrorPayload;
  } catch (_error) {
    return jsonResponse({ error: "Invalid payload." }, 400);
  }

  const severity = ALLOWED_SEVERITIES.has(String(payload.severity ?? "").trim())
    ? String(payload.severity)
    : "error";
  const category = truncate(payload.category ?? "", 80).trim();
  const message = truncate(payload.message ?? "", 1000).trim();
  if (category === "" || message === "") {
    return jsonResponse({ error: "Category and message are required." }, 400);
  }

  const context = sanitizeForLogs(payload.context ?? {}) as Record<string, unknown>;
  const build = sanitizeForLogs(payload.build ?? {}) as Record<string, unknown>;
  const runtime = sanitizeForLogs(payload.runtime ?? {}) as Record<string, unknown>;
  const fingerprint = truncate(
    payload.fingerprint ?? buildFingerprint(severity, category, message, context),
    120,
  );

  const supabase = createAdminClient();
  const insertResponse = await supabase
    .from("client_error_events")
    .insert({
      fingerprint,
      severity,
      category,
      message,
      context,
      build,
      runtime,
      reported_at: payload.timestamp ?? new Date().toISOString(),
    })
    .select("id, reported_at")
    .single();

  if (insertResponse.error) {
    return jsonResponse({ error: insertResponse.error.message }, 500);
  }

  const insertedRow = insertResponse.data;
  let emailed = false;
  if (ALERTABLE_SEVERITIES.has(severity)) {
    const cutoff = new Date(Date.now() - EMAIL_RATE_LIMIT_MINUTES * 60_000).toISOString();
    const recentEmailResponse = await supabase
      .from("client_error_events")
      .select("id, emailed_at")
      .eq("fingerprint", fingerprint)
      .not("emailed_at", "is", null)
      .gte("emailed_at", cutoff)
      .limit(1);

    const recentlyAlerted = !recentEmailResponse.error && (recentEmailResponse.data ?? []).length > 0;
    if (!recentlyAlerted) {
      emailed = await sendEmailAlert({
        subject: `[Endless Helicopter] ${severity.toUpperCase()} ${category}`,
        text: [
          `Severity: ${severity}`,
          `Category: ${category}`,
          `Message: ${message}`,
          "",
          `Fingerprint: ${fingerprint}`,
          "",
          "Build:",
          JSON.stringify(build, null, 2),
          "",
          "Runtime:",
          JSON.stringify(runtime, null, 2),
          "",
          "Context:",
          JSON.stringify(context, null, 2),
        ].join("\n"),
      });
      if (emailed) {
        await supabase
          .from("client_error_events")
          .update({ emailed_at: new Date().toISOString() })
          .eq("id", insertedRow.id);
      }
    }
  }

  return jsonResponse({
    ok: true,
    fingerprint,
    emailed,
  });
});
