-- 问题①：冲突被「自己解决 / 忽略关闭」后，原始「日程冲突提醒」通知不再残留
-- 之前 notify_todo_assignment 写入 type='conflict' 的通知，但 resolve/dismiss 只改
-- conflict_resolutions 状态，从不清理该通知，导致它一直留在消息列表。
-- 这里在对应 RPC 里按 payload.resolution_id 删除原始冲突通知。

-- 先补上冲突升级目标列（被指派人自己触发冲突时，可升级给空间 owner/admin）
ALTER TABLE public.conflict_resolutions
  ADD COLUMN IF NOT EXISTS escalated_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 被指派人「自己解决」冲突：解决后删除被指派人的原始冲突通知
CREATE OR REPLACE FUNCTION public.resolve_conflict_self(p_resolution_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r public.conflict_resolutions%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT * INTO r FROM public.conflict_resolutions WHERE id = p_resolution_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'resolution not found';
  END IF;
  IF r.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'only assignee can self-resolve';
  END IF;
  IF r.status <> 'pending' AND r.status <> 'escalated' THEN
    RAISE EXCEPTION 'resolution already closed';
  END IF;

  UPDATE public.conflict_resolutions
  SET status = 'self_resolved',
      resolved_at = NOW(),
      updated_at = NOW()
  WHERE id = p_resolution_id;

  -- 清理：被指派人的原始「日程冲突提醒」通知
  DELETE FROM public.notifications
  WHERE type = 'conflict'
    AND payload->>'resolution_id' = r.id::text
    AND user_id = r.user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_conflict_self(UUID) TO authenticated;

-- 创建人处理完升级冲突后关闭：关闭时清理被指派人与创建人两方的冲突通知
CREATE OR REPLACE FUNCTION public.dismiss_conflict_resolution(p_resolution_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r public.conflict_resolutions%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT * INTO r FROM public.conflict_resolutions WHERE id = p_resolution_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'resolution not found';
  END IF;
  IF r.creator_id <> auth.uid() AND r.user_id <> auth.uid() AND r.escalated_to IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  UPDATE public.conflict_resolutions
  SET status = 'dismissed',
      resolved_at = NOW(),
      updated_at = NOW()
  WHERE id = p_resolution_id;

  -- 清理：被指派人原始冲突通知 + 创建人/管理员的 escalated 通知
  DELETE FROM public.notifications
  WHERE type = 'conflict'
    AND payload->>'resolution_id' = r.id::text
    AND (user_id = r.user_id OR user_id = r.creator_id OR user_id = r.escalated_to);
END;
$$;

GRANT EXECUTE ON FUNCTION public.dismiss_conflict_resolution(UUID) TO authenticated;
