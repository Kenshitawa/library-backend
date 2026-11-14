-- Count open issues for a borrower
CREATE OR REPLACE FUNCTION public.get_borrower_open_issues(p_borrower_id uuid)
RETURNS int AS $$
  SELECT COUNT(*)::int FROM public.issues 
  WHERE borrower_id = p_borrower_id AND status = 'open' AND deleted_at IS NULL
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Sum outstanding charges for a borrower
CREATE OR REPLACE FUNCTION public.get_borrower_outstanding_charges(p_borrower_id uuid)
RETURNS int AS $$
  SELECT COALESCE(SUM(amount - paid_amount), 0)::int FROM public.charges 
  WHERE borrower_id = p_borrower_id AND status IN ('open','partial') AND deleted_at IS NULL
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check issue blocks for FR-26
CREATE OR REPLACE FUNCTION public.check_issue_blocks(p_copy_id uuid, p_borrower_id uuid)
RETURNS TABLE(blocked bool, reason text) AS $$
DECLARE
  v_borrower public.borrowers%ROWTYPE;
  v_borrower_type public.borrower_types%ROWTYPE;
  v_copy public.copies%ROWTYPE;
  v_open_count int;
  v_outstanding int;
  v_has_overdue bool;
BEGIN
  SELECT * INTO v_borrower FROM public.borrowers WHERE id = p_borrower_id AND deleted_at IS NULL;
  SELECT * INTO v_copy FROM public.copies WHERE id = p_copy_id AND deleted_at IS NULL;
  SELECT * INTO v_borrower_type FROM public.borrower_types WHERE id = v_borrower.borrower_type_id;
  
  -- Check inactive
  IF v_borrower.status = 'inactive' THEN
    RETURN QUERY SELECT true, 'Borrower is inactive and cannot be issued books.';
    RETURN;
  END IF;
  
  -- Check copy availability
  IF v_copy.status NOT IN ('available', 'reserved') THEN
    RETURN QUERY SELECT true, 'Copy is not available (status: ' || v_copy.status || ').';
    RETURN;
  END IF;
  
  -- Check if copy is reserved for someone else
  IF v_copy.status = 'reserved' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.reservations 
      WHERE ready_copy_id = p_copy_id AND borrower_id = p_borrower_id AND status = 'ready'
    ) THEN
      RETURN QUERY SELECT true, 'Copy is reserved for another borrower.';
      RETURN;
    END IF;
  END IF;
  
  -- Check reference book for home use
  IF EXISTS (SELECT 1 FROM public.titles WHERE id = v_copy.title_id AND type = 'reference') THEN
    RETURN QUERY SELECT true, 'Reference books cannot be issued for home use.';
    RETURN;
  END IF;
  
  -- Check max items
  v_open_count := public.get_borrower_open_issues(p_borrower_id);
  IF v_open_count >= v_borrower_type.max_items THEN
    RETURN QUERY SELECT true, 'Item limit reached (' || v_open_count || ' of ' || v_borrower_type.max_items || ').';
    RETURN;
  END IF;
  
  -- Check overdue
  SELECT EXISTS(
    SELECT 1 FROM public.issues 
    WHERE borrower_id = p_borrower_id AND status = 'open' 
    AND due_at < now() AND deleted_at IS NULL
  ) INTO v_has_overdue;
  IF v_has_overdue THEN
    RETURN QUERY SELECT true, 'Borrower has overdue items.';
    RETURN;
  END IF;
  
  -- Check outstanding charges
  v_outstanding := public.get_borrower_outstanding_charges(p_borrower_id);
  IF v_outstanding > v_borrower_type.charge_threshold THEN
    RETURN QUERY SELECT true, 'Borrower has an outstanding balance of ' || (v_outstanding::float/100)::text || '.';
    RETURN;
  END IF;
  
  -- No blocks
  RETURN QUERY SELECT false, ''::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
