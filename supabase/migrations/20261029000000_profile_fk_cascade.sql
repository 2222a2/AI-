-- 给所有引用 public.profiles 的外键补上级联删除行为。
--
-- 背景：spaces / todos / todo_comments / ai_conversations / ai_actions 等表的
-- user 列引用 profiles(id) 但没有 ON DELETE 行为（默认 NO ACTION），
-- 导致删除 auth.users 里的用户时被外键挡住（FKeyViolation）。
--
-- 规则：
--   NOT NULL 列 → ON DELETE CASCADE（用户删了，其创建的数据一并删）
--   可空列     → ON DELETE SET NULL（如 todos.completed_by，置空即可）
--
-- 幂等：重复执行安全（约束不存在时循环自然跳过）。

begin;

do $$
declare
  r record;
  is_nullable text;
begin
  for r in
    select distinct
      kcu.table_name  as table_name,
      tc.constraint_name as constraint_name,
      kcu.column_name as column_name
    from information_schema.table_constraints tc
    join information_schema.key_column_usage kcu
      on kcu.constraint_name = tc.constraint_name
     and kcu.table_schema   = tc.table_schema
    join information_schema.constraint_column_usage ccu
      on ccu.constraint_name = tc.constraint_name
     and ccu.table_schema    = tc.table_schema
    where tc.constraint_type = 'FOREIGN KEY'
      and tc.table_schema    = 'public'
      and ccu.table_schema   = 'public'
      and ccu.table_name     = 'profiles'
  loop
    select c.is_nullable into is_nullable
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name   = r.table_name
      and c.column_name  = r.column_name;

    execute format('alter table public.%I drop constraint %I', r.table_name, r.constraint_name);

    if is_nullable = 'YES' then
      execute format(
        'alter table public.%I add constraint %I foreign key (%I) references public.profiles(id) on delete set null',
        r.table_name, r.constraint_name, r.column_name);
    else
      execute format(
        'alter table public.%I add constraint %I foreign key (%I) references public.profiles(id) on delete cascade',
        r.table_name, r.constraint_name, r.column_name);
    end if;
  end loop;
end $$;

commit;
