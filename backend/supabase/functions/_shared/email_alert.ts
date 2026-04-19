import { requireEnv } from "./common.ts";

type SendEmailAlertOptions = {
  subject: string;
  text: string;
  html?: string;
};

export async function sendEmailAlert(options: SendEmailAlertOptions): Promise<boolean> {
  const apiKey = Deno.env.get("RESEND_API_KEY") ?? "";
  const toEmail = Deno.env.get("ERROR_ALERT_TO_EMAIL") ?? "";
  const fromEmail = Deno.env.get("ERROR_ALERT_FROM_EMAIL") ?? "";
  if (apiKey === "" || toEmail === "" || fromEmail === "") {
    return false;
  }

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${requireEnv("RESEND_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [toEmail],
        subject: options.subject,
        text: options.text,
        html: options.html ?? `<pre>${escapeHtml(options.text)}</pre>`,
      }),
    });
    return response.ok;
  } catch (_error) {
    return false;
  }
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}
