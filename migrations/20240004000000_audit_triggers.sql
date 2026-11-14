-- Audit trigger function
CREATE OR REPLACE FUNCTION public.audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_action text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_old := NULL;
    v_new := to_jsonb(NEW);
    v_action := 'INSERT';
  ELSIF TG_OP = 'UPDATE' THEN
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    v_action := 'UPDATE';
  ELSIF TG_OP = 'DELETE' THEN
    v_old := to_jsonb(OLD);
    v_new := NULL;
    v_action := 'DELETE';
  END IF;
  
  INSERT INTO public.audit_log (user_id, action, entity, entity_id, before, after)
  VALUES (auth.uid(), v_action, TG_TABLE_NAME, 
    CASE WHEN TG_OP = 'DELETE' THEN (v_old->>'id')::uuid ELSE (v_new->>'id')::uuid END,
    v_old, v_new);
  
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach audit triggers to core tables
CREATE TRIGGER audit_borrowers AFTER INSERT OR UPDATE OR DELETE ON public.borrowers FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_users_profile AFTER INSERT OR UPDATE OR DELETE ON public.users_profile FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_titles AFTER INSERT OR UPDATE OR DELETE ON public.titles FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_copies AFTER INSERT OR UPDATE OR DELETE ON public.copies FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_issues AFTER INSERT OR UPDATE OR DELETE ON public.issues FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_charges AFTER INSERT OR UPDATE OR DELETE ON public.charges FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_payments AFTER INSERT OR UPDATE OR DELETE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_reservations AFTER INSERT OR UPDATE OR DELETE ON public.reservations FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
