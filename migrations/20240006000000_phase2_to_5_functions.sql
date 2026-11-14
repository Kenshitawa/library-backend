-- Migration: 20240006000000_phase2_to_5_functions.sql
-- Postgres functions for Class Issuing, Reservations return processing, Charges & Promotions

-- 1. Class Issue RPC: Fast bulk issue for up to 60+ learners in a single transaction
CREATE OR REPLACE FUNCTION public.issue_to_class(
  p_class_id uuid,
  p_title_id uuid,
  p_issued_by uuid,
  p_due_at timestamptz,
  p_learner_ids uuid[] DEFAULT NULL
)
RETURNS jsonb AS $$
DECLARE
  v_learner RECORD;
  v_copy RECORD;
  v_issued_count int := 0;
  v_skipped_count int := 0;
  v_skipped_learners jsonb := '[]'::jsonb;
  v_available_copies uuid[];
  v_copy_index int := 1;
  v_total_available int := 0;
BEGIN
  -- Gather all available copies for this title
  SELECT array_agg(id) INTO v_available_copies
  FROM public.copies
  WHERE title_id = p_title_id
    AND status = 'available'
    AND deleted_at IS NULL;

  v_total_available := COALESCE(array_length(v_available_copies, 1), 0);

  -- Iterate through learners in the class
  FOR v_learner IN
    SELECT b.id, b.name, b.admission_number, b.status
    FROM public.borrowers b
    WHERE b.class_id = p_class_id
      AND b.deleted_at IS NULL
      AND (p_learner_ids IS NULL OR b.id = ANY(p_learner_ids))
    ORDER BY b.name ASC
  LOOP
    -- Check if borrower is inactive
    IF v_learner.status = 'inactive' THEN
      v_skipped_count := v_skipped_count + 1;
      v_skipped_learners := v_skipped_learners || jsonb_build_object(
        'learner_id', v_learner.id,
        'name', v_learner.name,
        'reason', 'Learner is inactive'
      );
      CONTINUE;
    END IF;

    -- Check if learner already has an open issue for this title
    IF EXISTS (
      SELECT 1 FROM public.issues i
      JOIN public.copies c ON c.id = i.copy_id
      WHERE i.borrower_id = v_learner.id
        AND c.title_id = p_title_id
        AND i.status = 'open'
        AND i.deleted_at IS NULL
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      v_skipped_learners := v_skipped_learners || jsonb_build_object(
        'learner_id', v_learner.id,
        'name', v_learner.name,
        'reason', 'Already holds this title'
      );
      CONTINUE;
    END IF;

    -- Check if copies are exhausted
    IF v_copy_index > v_total_available THEN
      v_skipped_count := v_skipped_count + 1;
      v_skipped_learners := v_skipped_learners || jsonb_build_object(
        'learner_id', v_learner.id,
        'name', v_learner.name,
        'reason', 'Insufficient copies available'
      );
      CONTINUE;
    END IF;

    -- Get next available copy
    DECLARE
      v_current_copy_id uuid := v_available_copies[v_copy_index];
      v_copy_condition text;
    BEGIN
      SELECT condition INTO v_copy_condition FROM public.copies WHERE id = v_current_copy_id;

      -- Create issue
      INSERT INTO public.issues (
        copy_id,
        borrower_id,
        issued_at,
        due_at,
        issued_by,
        condition_at_issue,
        status,
        renewal_count
      ) VALUES (
        v_current_copy_id,
        v_learner.id,
        now(),
        p_due_at,
        p_issued_by,
        COALESCE(v_copy_condition, 'good'),
        'open',
        0
      );

      -- Mark copy as issued
      UPDATE public.copies
      SET status = 'issued', updated_at = now()
      WHERE id = v_current_copy_id;

      v_issued_count := v_issued_count + 1;
      v_copy_index := v_copy_index + 1;
    END;
  END LOOP;

  -- Audit log entry
  INSERT INTO public.audit_log (
    user_id, action, entity, entity_id, after
  ) VALUES (
    p_issued_by,
    'class_bulk_issue',
    'classes',
    p_class_id,
    jsonb_build_object(
      'title_id', p_title_id,
      'issued_count', v_issued_count,
      'skipped_count', v_skipped_count
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'issued_count', v_issued_count,
    'skipped_count', v_skipped_count,
    'skipped_learners', v_skipped_learners
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Return Reservations Handler
CREATE OR REPLACE FUNCTION public.handle_return_reservations(p_copy_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_title_id uuid;
  v_reservation RECORD;
  v_deadline timestamptz;
BEGIN
  -- Look up copy's title_id
  SELECT title_id INTO v_title_id FROM public.copies WHERE id = p_copy_id;
  IF v_title_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'Copy not found');
  END IF;

  -- Look for first waiting reservation for this title
  SELECT * INTO v_reservation
  FROM public.reservations
  WHERE title_id = v_title_id
    AND status = 'waiting'
    AND deleted_at IS NULL
  ORDER BY queue_position ASC, placed_at ASC
  LIMIT 1;

  IF v_reservation.id IS NOT NULL THEN
    v_deadline := now() + interval '3 days';

    -- Update reservation to ready
    UPDATE public.reservations
    SET status = 'ready',
        ready_copy_id = p_copy_id,
        pickup_deadline = v_deadline,
        updated_at = now()
    WHERE id = v_reservation.id;

    -- Update copy to reserved
    UPDATE public.copies
    SET status = 'reserved',
        updated_at = now()
    WHERE id = p_copy_id;

    -- Queue notification to borrower
    INSERT INTO public.notifications (
      borrower_id,
      type,
      channel,
      recipient,
      subject,
      body,
      status
    )
    SELECT
      v_reservation.borrower_id,
      'reservation_ready',
      'email',
      COALESCE(b.email, b.guardian_phone),
      'Book Ready for Pickup',
      'Your reserved book is ready for pickup at the library desk until ' || to_char(v_deadline, 'YYYY-MM-DD HH24:MI') || '.',
      'pending'
    FROM public.borrowers b
    WHERE b.id = v_reservation.borrower_id;

    RETURN jsonb_build_object(
      'matched', true,
      'reservation_id', v_reservation.id,
      'borrower_id', v_reservation.borrower_id,
      'pickup_deadline', v_deadline
    );
  END IF;

  RETURN jsonb_build_object('matched', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Year-End Class Promotion RPC
CREATE OR REPLACE FUNCTION public.promote_class(
  p_source_class_id uuid,
  p_dest_class_id uuid,
  p_user_id uuid
)
RETURNS jsonb AS $$
DECLARE
  v_promoted_count int := 0;
BEGIN
  UPDATE public.borrowers
  SET class_id = p_dest_class_id,
      updated_at = now()
  WHERE class_id = p_source_class_id
    AND deleted_at IS NULL;

  GET DIAGNOSTICS v_promoted_count = ROW_COUNT;

  INSERT INTO public.audit_log (
    user_id, action, entity, entity_id, before, after
  ) VALUES (
    p_user_id,
    'promote_class',
    'classes',
    p_source_class_id,
    jsonb_build_object('source_class_id', p_source_class_id),
    jsonb_build_object('dest_class_id', p_dest_class_id, 'count', v_promoted_count)
  );

  RETURN jsonb_build_object(
    'success', true,
    'promoted_count', v_promoted_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Check Renewal Allowed (blocks if title has active reservations or overdue)
CREATE OR REPLACE FUNCTION public.check_renewal_allowed(p_issue_id uuid)
RETURNS TABLE(allowed bool, reason text) AS $$
DECLARE
  v_issue public.issues%ROWTYPE;
  v_copy public.copies%ROWTYPE;
  v_has_reservations bool;
BEGIN
  SELECT * INTO v_issue FROM public.issues WHERE id = p_issue_id AND deleted_at IS NULL;
  IF v_issue.id IS NULL THEN
    RETURN QUERY SELECT false, 'Issue record not found';
    RETURN;
  END IF;

  SELECT * INTO v_copy FROM public.copies WHERE id = v_issue.copy_id AND deleted_at IS NULL;

  -- Overdue check
  IF v_issue.due_at < now() THEN
    RETURN QUERY SELECT false, 'Cannot renew an overdue book. Please return or seek librarian assistance.';
    RETURN;
  END IF;

  -- Reservation check
  SELECT EXISTS(
    SELECT 1 FROM public.reservations 
    WHERE title_id = v_copy.title_id 
      AND status IN ('waiting', 'ready')
      AND deleted_at IS NULL
  ) INTO v_has_reservations;

  IF v_has_reservations THEN
    RETURN QUERY SELECT false, 'Cannot renew: this title has pending reservations from other borrowers.';
    RETURN;
  END IF;

  -- Max renewals check (default 2)
  IF COALESCE(v_issue.renewal_count, 0) >= 2 THEN
    RETURN QUERY SELECT false, 'Maximum renewal limit (2 times) reached for this loan.';
    RETURN;
  END IF;

  RETURN QUERY SELECT true, ''::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
