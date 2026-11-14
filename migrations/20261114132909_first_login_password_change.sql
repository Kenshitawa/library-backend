-- Track the first sign-in password change and keep privileged access disabled
-- until the initial password is replaced.
ALTER TABLE public.users_profile
  ADD COLUMN IF NOT EXISTS must_change_password boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT role
  FROM public.users_profile
  WHERE id = auth.uid()
    AND active = true
    AND must_change_password = false
$$;

CREATE OR REPLACE FUNCTION public.clear_first_login_password_flag()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.users_profile
  SET must_change_password = false
  WHERE id = NEW.id
    AND must_change_password = true;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.clear_first_login_password_flag() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS clear_first_login_password_flag ON auth.users;
CREATE TRIGGER clear_first_login_password_flag
  AFTER UPDATE OF encrypted_password ON auth.users
  FOR EACH ROW
  WHEN (OLD.encrypted_password IS DISTINCT FROM NEW.encrypted_password)
  EXECUTE FUNCTION public.clear_first_login_password_flag();

-- The first-login flag and role are administrator-controlled fields. Keep the
-- app's existing user controls limited to activation and theme preferences.
REVOKE UPDATE ON public.users_profile FROM anon, authenticated;
GRANT UPDATE (active, theme) ON public.users_profile TO authenticated;

