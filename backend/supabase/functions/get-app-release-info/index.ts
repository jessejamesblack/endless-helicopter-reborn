import { createAdminClient, jsonResponse, safeChannel } from "../_shared/common.ts";

Deno.serve(async (request: Request) => {
  if (request.method !== "GET") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const supabase = createAdminClient();
  const url = new URL(request.url);
  const channel = safeChannel(url.searchParams.get("channel"));

  const response = await supabase
    .from("app_release_channels")
    .select("*")
    .eq("channel", channel)
    .maybeSingle();

  if (response.error) {
    return jsonResponse({ error: response.error.message }, 500);
  }

  return jsonResponse(response.data ?? {});
});
