import {
  jsonResponse,
  safeChannel,
  truncate,
} from "../_shared/common.ts";

type ScreenshotPayload = {
  event_id?: string;
  title?: string;
  description?: string;
  details?: Record<string, unknown>;
  build?: Record<string, unknown>;
  image_base64?: string;
};

const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: ScreenshotPayload;
  try {
    payload = await request.json() as ScreenshotPayload;
  } catch (_error) {
    return jsonResponse({ error: "Invalid payload." }, 400);
  }

  const eventId = String(payload.event_id ?? "").trim();
  const title = truncate(payload.title ?? "", 120).trim();
  const description = truncate(payload.description ?? "", 500).trim();
  const imageBase64 = String(payload.image_base64 ?? "").trim();
  if (eventId === "" || title === "" || imageBase64 === "") {
    return jsonResponse({ error: "Missing required screenshot fields." }, 400);
  }

  const webhookUrl = Deno.env.get("DISCORD_GAME_EVENTS_WEBHOOK_URL") ?? "";
  if (webhookUrl === "") {
    return jsonResponse({ ok: true, posted: false, skipped: true });
  }

  let imageBytes: Uint8Array;
  try {
    const binary = atob(imageBase64);
    imageBytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  } catch (_error) {
    return jsonResponse({ error: "Image payload could not be decoded." }, 400);
  }

  if (imageBytes.byteLength > MAX_UPLOAD_BYTES) {
    return jsonResponse({ error: "Image payload exceeds max size." }, 400);
  }

  const build = payload.build ?? {};
  const form = new FormData();
  form.append("payload_json", JSON.stringify({
    content: truncate(`📸 ${title}`, 1800),
    allowed_mentions: { parse: [] },
    embeds: [{
      title,
      description,
      color: 0x6dc8ff,
      fields: [
        { name: "Version", value: truncate(build["version_name"] ?? "unknown", 64), inline: true },
        { name: "Channel", value: safeChannel(build["release_channel"]), inline: true },
        { name: "Build", value: truncate(build["build_sha"] ?? "dev", 64), inline: true },
      ],
    }],
  }));
  form.append(
    "files[0]",
    new Blob([imageBytes], { type: "image/jpeg" }),
    `${eventId}.jpg`,
  );

  try {
    const response = await fetch(webhookUrl, {
      method: "POST",
      body: form,
    });
    return jsonResponse({ ok: true, posted: response.ok });
  } catch (_error) {
    return jsonResponse({ ok: true, posted: false });
  }
});
