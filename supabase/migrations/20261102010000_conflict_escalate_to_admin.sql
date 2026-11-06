-- 问题③：让「升级/打回」在单人自用或成员自用场景也可达
-- 原逻辑：escalate 仅在 creator_id <> user_id 时可用（即 owner/admin 把任务指派给他人重叠）。
-- 自己建 + 自己排期冲突（samePerson）时 escalate 永远触发不到。
-- 改为：被指派人仍可升级；若 creator 就是自己，则升级给空间 owner/admin（存在且非自己），
-- 并把接收方写入 escalated_to，使对方也能在消息中心看到并「我已处理，关闭」。

CREATE OR REPLACE FUNCTION public.escalate_conflict_resolution(
  p_resolution_id UUID,
  p_note TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r public.conflict_resolutions%ROWTYPE;
  ttitle TEXT;
  v_note TEXT := trim(COALESCE(p_note, ''));
  v_target UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF v_note = '' THEN
    RAISE EXCEPTION 'reason required';
  END IF;

  SELECT * INTO r FROM public.conflict_resolutions WHERE id = p_resolution_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'resolution not found';
  END IF;
  IF r.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'only assignee can escalate';
  END IF;
  IF r.status <> 'pending' THEN
    RAISE EXCEPTION 'resolution not pending';
  END IF;

  -- 目标：创建人≠被指派人 → 创建人；否则升级给空间 owner/admin
  IF r.creator_id <> r.user_id THEN
    v_target := r.creator_id;
  ELSE
    SELECT sm.user_id INTO v_target
    FROM public.space_members sm
    WHERE sm.space_id = r.space_id
      AND sm.role IN ('owner', 'admin')
      AND sm.user_id <> auth.uid()
    ORDER BY (sm.role = 'owner') DESC
    LIMIT 1;

    IF v_target IS NULL THEN
      RAISE EXCEPTION 'no owner or admin to escalate to';
    END IF;
  END IF;

  SELECT title INTO ttitle FROM public.todos WHERE id = r.todo_id;

  UPDATE public.conflict_resolutions
  SET status = 'escalated',
      note = v_note,
      escalated_to = v_target,
      updated_at = NOW()
  WHERE id = p_resolution_id;

  -- 清理被指派人的原始「日程冲突提醒」通知
  DELETE FROM public.notifications
  WHERE type = 'conflict'
    AND payload->>'resolution_id' = r.id::text
    AND user_id = r.user_id;

  INSERT INTO public.notifications (user_id, space_id, type, title, body, payload)
  VALUES (
    v_target,
    r.space_id,
    'conflict',
    '冲突已打回给你',
    '被指派人无法自行消化「' || COALESCE(ttitle, '任务') || '」的冲突。原因：' || v_note,
    jsonb_build_object(
      'resolution_id', r.id,
      'todo_id', r.todo_id,
      'from_user', auth.uid(),
      'note', v_note,
      'conflicting_todo_ids', to_jsonb(r.conflicting_todo_ids)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.escalate_conflict_resolution(UUID, TEXT) TO authenticated;
