import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import { isAutoDefaultSpace } from "@/lib/spaces";
import type { SpaceNavItem } from "@/lib/todos";

/** 同一次 RSC 请求内复用 auth，避免 layout/page 重复 getUser */
export const getAppAuth = cache(async () => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return { supabase, user };
});

type MembershipRow = {
  role: string;
  ui_prefs?: unknown;
  spaces: {
    id: string;
    name: string;
    kind: string;
    visibility?: string;
    avatar_url?: string | null;
    description?: string | null;
  } | null;
};

export function mapMembershipRows(
  memberships: {
    role: string;
    ui_prefs?: unknown;
    spaces: unknown;
  }[],
): { spaces: SpaceNavItem[]; spacePrefsById: Record<string, unknown> } {
  const spaces: SpaceNavItem[] = [];
  const spacePrefsById: Record<string, unknown> = {};
  for (const m of memberships) {
    const space = m.spaces as MembershipRow["spaces"];
    if (!space) continue;
    spaces.push({
      id: space.id,
      name: space.name,
      kind: space.kind,
      role: m.role,
      visibility: space.visibility ?? "private",
      avatar_url: space.avatar_url ?? null,
      description: space.description ?? null,
    });
    if (m.ui_prefs) spacePrefsById[space.id] = m.ui_prefs;
  }
  return { spaces, spacePrefsById };
}

/** 侧栏 / 总览等：隐藏 bootstrap 自动默认空间 */
export function visibleSpaceNav(spaces: SpaceNavItem[]): SpaceNavItem[] {
  return spaces.filter((s) => !isAutoDefaultSpace(s));
}

const SPACE_SELECT =
  "role, ui_prefs, spaces(id, name, kind, visibility, avatar_url, description)";

/** 同一次请求内复用空间列表（含自动默认空间；展示前请 visibleSpaceNav） */
// 跨请求内存缓存：降低首屏 TTFB。
// 注意：不能用 unstable_cache 包裹含 cookies() 的 createClient()（next start 会报
// "used cookies() inside a function cached with unstable_cache()"）。这里用进程内
// Map + TTL 规避该限制，同样能跳过重复的 DB 往返。key 含 userId，避免跨用户泄露。
const SPACE_NAV_TTL_MS = 60_000;
const spaceNavCache = new Map<
  string,
  { value: MembershipRow[]; expires: number }
>();

async function fetchMemberships(userId: string): Promise<MembershipRow[]> {
  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from("space_members")
    .select(SPACE_SELECT)
    .eq("user_id", userId)
    .order("joined_at", { ascending: true });
  return (memberships ?? []) as unknown as MembershipRow[];
}

export const getMySpaceNav = cache(async (): Promise<{
  spaces: SpaceNavItem[];
  spacePrefsById: Record<string, unknown>;
  memberships: MembershipRow[];
}> => {
  const { user } = await getAppAuth();
  if (!user) {
    return { spaces: [], spacePrefsById: {}, memberships: [] };
  }

  const now = Date.now();
  const hit = spaceNavCache.get(user.id);
  let rows: MembershipRow[];
  if (hit && hit.expires > now) {
    rows = hit.value;
  } else {
    rows = await fetchMemberships(user.id);
    spaceNavCache.set(user.id, { value: rows, expires: now + SPACE_NAV_TTL_MS });
  }
  const { spaces, spacePrefsById } = mapMembershipRows(rows);

  return { spaces, spacePrefsById, memberships: rows };
});
