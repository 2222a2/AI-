import { createClient, type SupabaseClient, type User } from "@supabase/supabase-js";
import ws from "ws";
import { config } from "../config";

/** Node（Railway node:20）无原生 WebSocket，需提供 ws 供 supabase-js Realtime 使用。
 * 精简自托管关闭 Realtime 服务时，设 SUPABASE_REALTIME_ENABLED=false 以禁用。 */
const realtimeEnabled = process.env.SUPABASE_REALTIME_ENABLED !== "false";
const realtimeOpts = {
  transport: ws as unknown as typeof WebSocket,
};

export function createUserClient(accessToken: string): SupabaseClient {
  return createClient(config.supabaseUrl, config.supabaseAnonKey, {
    global: {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
    realtime: realtimeEnabled ? realtimeOpts : undefined,
  });
}

export function createAdminClient(): SupabaseClient {
  return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
    realtime: realtimeEnabled ? realtimeOpts : undefined,
  });
}

export async function getUserFromToken(accessToken: string): Promise<User> {
  const client = createUserClient(accessToken);
  const { data, error } = await client.auth.getUser(accessToken);
  if (error || !data.user) {
    throw new Error(error?.message || "Invalid or expired token");
  }
  return data.user;
}
