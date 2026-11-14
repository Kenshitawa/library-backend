ALTER FUNCTION public.get_user_role() SET search_path = public, pg_temp;
ALTER FUNCTION public.get_borrower_open_issues(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_borrower_outstanding_charges(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.check_issue_blocks(uuid, uuid) RENAME TO check_issue_blocks_internal;
ALTER FUNCTION public.issue_to_class(uuid, uuid, uuid, timestamptz, uuid[]) RENAME TO issue_to_class_internal;
ALTER FUNCTION public.handle_return_reservations(uuid) RENAME TO handle_return_reservations_internal;
ALTER FUNCTION public.promote_class(uuid, uuid, uuid) RENAME TO promote_class_internal;
ALTER FUNCTION public.check_renewal_allowed(uuid) RENAME TO check_renewal_allowed_internal;
ALTER FUNCTION public.audit_trigger() SET search_path = public, pg_temp;

ALTER FUNCTION public.check_issue_blocks_internal(uuid, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.issue_to_class_internal(uuid, uuid, uuid, timestamptz, uuid[]) SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_return_reservations_internal(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.promote_class_internal(uuid, uuid, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.check_renewal_allowed_internal(uuid) SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.get_user_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_borrower_open_issues(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_borrower_outstanding_charges(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.check_issue_blocks_internal(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.issue_to_class_internal(uuid, uuid, uuid, timestamptz, uuid[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_return_reservations_internal(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.promote_class_internal(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.check_renewal_allowed_internal(uuid) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.check_issue_blocks(p_copy_id uuid, p_borrower_id uuid)
RETURNS TABLE(blocked boolean, reason text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.get_user_role() IS DISTINCT FROM 'librarian' THEN
    RAISE EXCEPTION 'Librarian role required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT * FROM public.check_issue_blocks_internal(p_copy_id, p_borrower_id);
END;
$$;

CREATE FUNCTION public.issue_to_class(
  p_class_id uuid,
  p_title_id uuid,
  p_issued_by uuid,
  p_due_at timestamptz,
  p_learner_ids uuid[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.get_user_role() IS DISTINCT FROM 'librarian' THEN
    RAISE EXCEPTION 'Librarian role required' USING ERRCODE = '42501';
  END IF;

  RETURN public.issue_to_class_internal(p_class_id, p_title_id, p_issued_by, p_due_at, p_learner_ids);
END;
$$;

CREATE FUNCTION public.handle_return_reservations(p_copy_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NOT NULL
    AND auth.role() IS DISTINCT FROM 'service_role'
    AND public.get_user_role() IS DISTINCT FROM 'librarian' THEN
    RAISE EXCEPTION 'Librarian role required' USING ERRCODE = '42501';
  END IF;

  RETURN public.handle_return_reservations_internal(p_copy_id);
END;
$$;

CREATE FUNCTION public.promote_class(
  p_source_class_id uuid,
  p_dest_class_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.get_user_role() IS DISTINCT FROM 'librarian' THEN
    RAISE EXCEPTION 'Librarian role required' USING ERRCODE = '42501';
  END IF;

  RETURN public.promote_class_internal(p_source_class_id, p_dest_class_id, p_user_id);
END;
$$;

CREATE FUNCTION public.check_renewal_allowed(p_issue_id uuid)
RETURNS TABLE(allowed boolean, reason text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF public.get_user_role() IS DISTINCT FROM 'librarian'
    AND NOT (
      public.get_user_role() = 'teacher'
      AND EXISTS (
        SELECT 1
        FROM public.issues issue
        JOIN public.users_profile profile ON profile.borrower_id = issue.borrower_id
        WHERE issue.id = p_issue_id
          AND profile.id = auth.uid()
      )
    ) THEN
    RETURN QUERY SELECT false, 'Issue record not found'::text;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT * FROM public.check_renewal_allowed_internal(p_issue_id);
END;
$$;

REVOKE ALL ON FUNCTION public.check_issue_blocks(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_issue_blocks(uuid, uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.issue_to_class(uuid, uuid, uuid, timestamptz, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.issue_to_class(uuid, uuid, uuid, timestamptz, uuid[]) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.handle_return_reservations(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handle_return_reservations(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.promote_class(uuid, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.promote_class(uuid, uuid, uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.check_renewal_allowed(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_renewal_allowed(uuid) TO authenticated, service_role;

CREATE FUNCTION public.mark_notification_read(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.notifications notification
  SET read_at = COALESCE(notification.read_at, now())
  WHERE notification.id = p_notification_id
    AND (
      public.get_user_role() = 'librarian'
      OR notification.borrower_id = (
        SELECT profile.borrower_id
        FROM public.users_profile profile
        WHERE profile.id = auth.uid()
          AND profile.role = 'teacher'
          AND profile.active = true
      )
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Notification not found or access denied' USING ERRCODE = '42501';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.mark_notification_read(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated, service_role;
