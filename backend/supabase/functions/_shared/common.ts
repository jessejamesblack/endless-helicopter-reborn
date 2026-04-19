import { createClient } from "jsr:@supabase/supabase-js@2";

const CHANNELS = new Set(["stable", "beta", "dev"]);

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

export function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function createAdminClient() {
  return createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export function toInt(value: unknown, fallback = 0): number {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function safeChannel(value: unknown): "stable" | "beta" | "dev" {
  const normalized = String(value ?? "stable").trim().toLowerCase();
  return CHANNELS.has(normalized) ? normalized as "stable" | "beta" | "dev" : "stable";
}

export function truncate(value: unknown, maxLength: number): string {
  const text = String(value ?? "");
  if (text.length <= maxLength) {
    return text;
  }
  return `${text.slice(0, Math.max(0, maxLength - 1))}…`;
}

export function sanitizeForLogs(value: unknown): unknown {
  if (value === null || value === undefined) {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeForLogs(item));
  }
  if (typeof value === "object") {
    const sanitized: Record<string, unknown> = {};
    for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
      if (isSensitiveKey(key)) {
        continue;
      }
      sanitized[key] = sanitizeForLogs(child);
    }
    return sanitized;
  }
  if (typeof value === "string") {
    return truncate(value, 2000);
  }
  return value;
}

export function isSensitiveKey(key: string): boolean {
  const normalized = key.toLowerCase();
  return normalized.includes("token") ||
    normalized.includes("secret") ||
    normalized.includes("webhook") ||
    normalized.includes("service_key") ||
    normalized.includes("api_key") ||
    normalized.includes("apikey") ||
    normalized.includes("device_id");
}

export function buildFingerprint(
  severity: string,
  category: string,
  message: string,
  context: unknown,
): string {
  return String(hashString(`${severity}|${category}|${message}|${JSON.stringify(context)}`));
}

function hashString(value: string): number {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = ((hash << 5) - hash) + value.charCodeAt(index);
    hash |= 0;
  }
  return hash;
}
