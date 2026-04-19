import { truncate } from "./common.ts";

export type DiscordEmbedField = {
  name: string;
  value: string;
  inline?: boolean;
};

export type DiscordPostOptions = {
  webhookUrl: string;
  content?: string;
  title?: string;
  description?: string;
  color?: number;
  fields?: DiscordEmbedField[];
  footer?: string;
};

export async function postDiscordWebhook(options: DiscordPostOptions): Promise<boolean> {
  if (!options.webhookUrl || options.webhookUrl.trim() === "") {
    return false;
  }

  const embeds = [];
  const title = truncate(options.title ?? "", 256).trim();
  const description = truncate(options.description ?? "", 4096).trim();
  const fields = (options.fields ?? [])
    .filter((field) => field.name.trim() !== "" && field.value.trim() !== "")
    .slice(0, 20)
    .map((field) => ({
      name: truncate(field.name, 256),
      value: truncate(field.value, 1024),
      inline: field.inline ?? false,
    }));

  if (title !== "" || description !== "" || fields.length > 0 || (options.footer ?? "").trim() !== "") {
    embeds.push({
      title: title === "" ? undefined : title,
      description: description === "" ? undefined : description,
      color: options.color,
      fields,
      footer: (options.footer ?? "").trim() === ""
        ? undefined
        : { text: truncate(options.footer, 2048) },
    });
  }

  try {
    const response = await fetch(options.webhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        content: truncate(options.content ?? "", 1800),
        embeds,
        allowed_mentions: {
          parse: [],
        },
      }),
    });
    return response.ok;
  } catch (_error) {
    return false;
  }
}
