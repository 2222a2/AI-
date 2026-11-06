-- 问题②：免邮件密码找回（恢复码方案）
-- SMTP 在当前部署是假的（SMTP_PASS=fake_mail_password），标准 resetPasswordForEmail 无法送达。
-- 改用「恢复码」：注册 / 改密时生成一次性恢复码（明文仅展示一次，库内存哈希），
-- 忘记密码时凭「邮箱 + 恢复码」直接重置，无需邮件。

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS recovery_code_hash TEXT;

COMMENT ON COLUMN public.profiles.recovery_code_hash IS
  '密码找回码哈希（crypt bf）。NULL 表示未设置；注册/改密时生成并展示一次';

-- 写入恢复码哈希（由服务端在注册/改密成功后调用，明文不入表）
CREATE OR REPLACE FUNCTION public.set_recovery_code(
  p_user_id UUID,
  p_code TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_code IS NULL OR length(trim(p_code)) < 8 THEN
    RAISE EXCEPTION 'invalid recovery code';
  END IF;
  UPDATE public.profiles
  SET recovery_code_hash = crypt(trim(p_code), gen_salt('bf'))
  WHERE id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_recovery_code(UUID, TEXT) TO authenticated;

-- 校验恢复码：成功返回 user_id，失败返回 NULL（不泄露是否存在）
CREATE OR REPLACE FUNCTION public.verify_recovery_code(
  p_email TEXT,
  p_code TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_hash TEXT;
BEGIN
  SELECT id, recovery_code_hash INTO v_id, v_hash
  FROM public.profiles
  WHERE email = p_email;

  IF v_id IS NULL OR v_hash IS NULL THEN
    RETURN NULL;
  END IF;
  IF crypt(p_code, v_hash) = v_hash THEN
    RETURN v_id;
  END IF;
  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_recovery_code(TEXT, TEXT) TO authenticated, anon;
