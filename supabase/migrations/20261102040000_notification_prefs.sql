-- 通知偏好：用户可在「设置 → 通知」按类型关闭
-- 存储形如 {"daily_summary": true, "assigned": true, "conflict": true, "invite": true, "toast": true}
-- 约定：缺失的键一律按「开启」处理，这样老用户无需回填数据

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS notification_prefs JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.profiles.notification_prefs IS
  '通知偏好：按通知类型开关 + 是否弹窗；缺失的键按开启处理';
