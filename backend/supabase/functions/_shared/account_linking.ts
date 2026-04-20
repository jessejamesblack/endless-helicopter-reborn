import { createClient } from "jsr:@supabase/supabase-js@2";
import { jsonResponse, requireEnv } from "./common.ts";

type AuthResult = {
  user: { id: string; email?: string | null } | null;
  response: Response | null;
};

type PlayerContext = {
  ok: boolean;
  response: Response | null;
  authenticated: boolean;
  linked: boolean;
  auth_user_id: string;
  email: string;
  family_id: string;
  player_id: string;
  client_player_id: string;
};

function getBearerToken(request: Request): string {
  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) {
    return "";
  }
  return authorization.slice(7).trim();
}

function payloadFamilyId(payload: Record<string, unknown>): string {
  const familyId = String(payload.p_family_id ?? payload.family_id ?? "global").trim();
  return familyId === "" ? "global" : familyId;
}

function payloadPlayerId(payload: Record<string, unknown>): string {
  return String(payload.p_player_id ?? payload.player_id ?? "").trim();
}

export async function getAuthenticatedUser(request: Request): Promise<AuthResult> {
  const token = getBearerToken(request);
  if (token === "") {
    return { user: null, response: null };
  }

  const anonKey = requireEnv("SUPABASE_ANON_KEY");
  if (token === anonKey) {
    return { user: null, response: null };
  }

  const authClient = createClient(requireEnv("SUPABASE_URL"), anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      headers: {
        Authorization: `Bearer ${token}`,
        apikey: anonKey,
      },
    },
  });

  const { data, error } = await authClient.auth.getUser();
  if (error) {
    return {
      user: null,
      response: jsonResponse({
        error: "invalid_auth_session",
        message: "The saved account session is no longer valid. Please sign in again.",
      }, 401),
    };
  }

  if (!data.user) {
    return { user: null, response: null };
  }

  return {
    user: {
      id: String(data.user.id),
      email: typeof data.user.email === "string" ? data.user.email : "",
    },
    response: null,
  };
}

export async function resolvePlayerContext(
  supabase: any,
  request: Request,
  payload: Record<string, unknown>,
): Promise<PlayerContext> {
  const familyId = payloadFamilyId(payload);
  const clientPlayerId = payloadPlayerId(payload);
  const auth = await getAuthenticatedUser(request);
  if (auth.response) {
    return {
      ok: false,
      response: auth.response,
      authenticated: false,
      linked: false,
      auth_user_id: "",
      email: "",
      family_id: familyId,
      player_id: clientPlayerId,
      client_player_id: clientPlayerId,
    };
  }

  if (!auth.user) {
    return {
      ok: true,
      response: null,
      authenticated: false,
      linked: false,
      auth_user_id: "",
      email: "",
      family_id: familyId,
      player_id: clientPlayerId,
      client_player_id: clientPlayerId,
    };
  }

  const linkResult = await supabase
    .from("player_account_links")
    .select("auth_user_id, family_id, player_id, email")
    .eq("auth_user_id", auth.user.id)
    .maybeSingle();

  if (linkResult.error) {
    return {
      ok: false,
      response: jsonResponse({ error: linkResult.error.message }, 500),
      authenticated: true,
      linked: false,
      auth_user_id: auth.user.id,
      email: String(auth.user.email ?? ""),
      family_id: familyId,
      player_id: clientPlayerId,
      client_player_id: clientPlayerId,
    };
  }

  if (!linkResult.data) {
    return {
      ok: true,
      response: null,
      authenticated: true,
      linked: false,
      auth_user_id: auth.user.id,
      email: String(auth.user.email ?? ""),
      family_id: familyId,
      player_id: clientPlayerId,
      client_player_id: clientPlayerId,
    };
  }

  return {
    ok: true,
    response: null,
    authenticated: true,
    linked: true,
    auth_user_id: String(linkResult.data.auth_user_id ?? auth.user.id),
    email: String(linkResult.data.email ?? auth.user.email ?? "").trim(),
    family_id: String(linkResult.data.family_id ?? familyId).trim() || familyId,
    player_id: String(linkResult.data.player_id ?? clientPlayerId).trim(),
    client_player_id: clientPlayerId,
  };
}

export async function requireAuthenticatedUser(request: Request): Promise<{
  ok: boolean;
  response: Response | null;
  auth_user_id: string;
  email: string;
}> {
  const auth = await getAuthenticatedUser(request);
  if (auth.response) {
    return {
      ok: false,
      response: auth.response,
      auth_user_id: "",
      email: "",
    };
  }
  if (!auth.user) {
    return {
      ok: false,
      response: jsonResponse({
        error: "authentication_required",
        message: "Sign in with email to continue.",
      }, 401),
      auth_user_id: "",
      email: "",
    };
  }
  return {
    ok: true,
    response: null,
    auth_user_id: auth.user.id,
    email: String(auth.user.email ?? "").trim(),
  };
}

export async function touchPlayerAccountLink(
  supabase: any,
  authUserId: string,
  email = "",
): Promise<void> {
  const updates: Record<string, unknown> = {
    last_sign_in_at: new Date().toISOString(),
  };
  if (email.trim() !== "") {
    updates.email = email.trim();
  }
  await supabase
    .from("player_account_links")
    .update(updates)
    .eq("auth_user_id", authUserId);
}
