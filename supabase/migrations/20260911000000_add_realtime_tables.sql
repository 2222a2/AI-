-- 让多人协作的待办变更能实时推送到前端。
-- 根因：之前只有 space_members 被加入 supabase_realtime 发布，
-- todos / todo_assignees / todo_comments / notifications 都不在发布中，
-- 导致前端对这几张表的 postgres_changes 订阅永远收不到任何事件。
-- 用 DO 块做幂等处理，重复执行（如 reset 后再跑）不会报错。

begin;

do $$
declare
  t text;
begin
  foreach t in array array['todos', 'todo_assignees', 'todo_comments', 'notifications']
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

commit;
