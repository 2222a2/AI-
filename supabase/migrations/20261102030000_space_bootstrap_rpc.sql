-- A 方案：一次取全量的「空间引导数据」
--
-- 背景：点一次空间原本要串行 4~5 轮：
--   1) space_members（拿我的角色 + 空间信息）
--   2) profiles（拿时区）
--   3) space_members + profiles（拿成员列表，给指派人下拉）
--   4) space_invitations（拿邀请码）
-- 每轮都是一次跨境 RTT（本机实测 76~150ms），叠起来就是 0.6~0.9 秒。
--
-- 本函数把这些合成一次往返返回。调用方无需再单独验登录态：
--   auth.uid() 为空 → ok=false / not_authenticated
--   不是该空间成员 → ok=false / forbidden
--
-- security definer：函数内部要跨表读 profiles / space_invitations，
-- 但入口已校验「调用者是该空间成员」，且只返回该空间的数据。

create or replace function public.get_space_bootstrap(p_space_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_role    text;
  v_space   jsonb;
  v_tz      text;
  v_members jsonb := '[]'::jsonb;
  v_invites jsonb := '[]'::jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;

  select sm.role
    into v_role
    from public.space_members sm
   where sm.space_id = p_space_id
     and sm.user_id = v_uid;

  if v_role is null then
    return jsonb_build_object('ok', false, 'error', 'forbidden');
  end if;

  select jsonb_build_object(
           'id', s.id,
           'name', s.name,
           'description', s.description,
           'kind', s.kind,
           'owner_id', s.owner_id,
           'avatar_url', s.avatar_url,
           'visibility', s.visibility
         )
    into v_space
    from public.spaces s
   where s.id = p_space_id;

  if v_space is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  select p.timezone
    into v_tz
    from public.profiles p
   where p.id = v_uid;

  select coalesce(jsonb_agg(t.x order by t.sort_name, t.x->>'user_id'), '[]'::jsonb)
    into v_members
    from (
      select jsonb_build_object(
               'user_id', m.user_id,
               'role', m.role,
               'display_name', coalesce(nullif(btrim(pr.display_name), ''), '成员'),
               'email', pr.email
             ) as x,
             coalesce(nullif(btrim(pr.display_name), ''), '成员') as sort_name
        from public.space_members m
        left join public.profiles pr on pr.id = m.user_id
       where m.space_id = p_space_id
    ) t;

  -- 邀请码只给能管理的人看（与前端 canManage 一致）
  if v_role in ('owner', 'admin') then
    select coalesce(jsonb_agg(to_jsonb(i) order by i.created_at desc), '[]'::jsonb)
      into v_invites
      from public.space_invitations i
     where i.space_id = p_space_id;
  end if;

  return jsonb_build_object(
           'ok', true,
           'user_id', v_uid,
           'role', v_role,
           'timezone', v_tz,
           'space', v_space,
           'members', v_members,
           'invites', v_invites
         );
end;
$$;

comment on function public.get_space_bootstrap(uuid) is
  '一次返回空间详情、我的角色、时区、成员列表、邀请码（供空间页首屏用，替代 4 轮串行查询）';

revoke all on function public.get_space_bootstrap(uuid) from public;
grant execute on function public.get_space_bootstrap(uuid) to authenticated;
