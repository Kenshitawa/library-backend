-- Enable RLS on all tables
ALTER TABLE public.library_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.borrower_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.borrowers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_profile ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.authors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.titles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.title_authors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.copies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_feeds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Role helper (SECURITY DEFINER so it bypasses RLS)
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS text AS $$
  SELECT role FROM public.users_profile 
  WHERE id = auth.uid() AND active = true
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- library_profile: everyone can read, only librarians can write
CREATE POLICY "library_profile_read" ON public.library_profile FOR SELECT USING (true);
CREATE POLICY "library_profile_write" ON public.library_profile FOR ALL USING (public.get_user_role() = 'librarian');

-- subjects: everyone read, librarian write
CREATE POLICY "subjects_read" ON public.subjects FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "subjects_write" ON public.subjects FOR ALL USING (public.get_user_role() = 'librarian');

-- locations: everyone read, librarian write
CREATE POLICY "locations_read" ON public.locations FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "locations_write" ON public.locations FOR ALL USING (public.get_user_role() = 'librarian');

-- borrower_types: authenticated read, librarian write
CREATE POLICY "borrower_types_read" ON public.borrower_types FOR SELECT USING (auth.uid() IS NOT NULL AND deleted_at IS NULL);
CREATE POLICY "borrower_types_write" ON public.borrower_types FOR ALL USING (public.get_user_role() = 'librarian');

-- classes: authenticated read, librarian write
CREATE POLICY "classes_read" ON public.classes FOR SELECT USING (auth.uid() IS NOT NULL AND deleted_at IS NULL);
CREATE POLICY "classes_write" ON public.classes FOR ALL USING (public.get_user_role() = 'librarian');

-- borrowers: librarian full; teacher reads own record only
CREATE POLICY "borrowers_librarian" ON public.borrowers FOR ALL USING (public.get_user_role() = 'librarian');
CREATE POLICY "borrowers_teacher_read" ON public.borrowers FOR SELECT 
  USING (public.get_user_role() = 'teacher' AND id = (SELECT borrower_id FROM public.users_profile WHERE id = auth.uid()));

-- users_profile: librarian full; each user reads/updates own
CREATE POLICY "users_profile_librarian" ON public.users_profile FOR ALL USING (public.get_user_role() = 'librarian');
CREATE POLICY "users_profile_own" ON public.users_profile FOR SELECT USING (id = auth.uid());
CREATE POLICY "users_profile_own_update" ON public.users_profile FOR UPDATE USING (id = auth.uid());

-- authors, titles, title_authors: anon/all read; librarian write
CREATE POLICY "authors_read" ON public.authors FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "authors_write" ON public.authors FOR ALL USING (public.get_user_role() = 'librarian');
CREATE POLICY "titles_read" ON public.titles FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "titles_write" ON public.titles FOR ALL USING (public.get_user_role() = 'librarian');
CREATE POLICY "title_authors_read" ON public.title_authors FOR SELECT USING (true);
CREATE POLICY "title_authors_write" ON public.title_authors FOR ALL USING (public.get_user_role() = 'librarian');

-- copies: anon/all read; librarian write
CREATE POLICY "copies_read" ON public.copies FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "copies_write" ON public.copies FOR ALL USING (public.get_user_role() = 'librarian');

-- issues: librarian full; teacher reads own (via their borrower_id)
CREATE POLICY "issues_librarian" ON public.issues FOR ALL USING (public.get_user_role() = 'librarian');
CREATE POLICY "issues_teacher_read" ON public.issues FOR SELECT
  USING (public.get_user_role() = 'teacher' AND borrower_id = (SELECT borrower_id FROM public.users_profile WHERE id = auth.uid()));

-- charges: librarian full; teacher reads own
CREATE POLICY "charges_librarian" ON public.charges FOR ALL USING (public.get_user_role() = 'librarian');
CREATE POLICY "charges_teacher_read" ON public.charges FOR SELECT
  USING (public.get_user_role() = 'teacher' AND borrower_id = (SELECT borrower_id FROM public.users_profile WHERE id = auth.uid()));

-- payments: librarian full; teacher reads own
CREATE POLICY "payments_librarian" ON public.payments FOR ALL USING (public.get_user_role() = 'librarian');
CREATE POLICY "payments_teacher_read" ON public.payments FOR SELECT
  USING (public.get_user_role() = 'teacher' AND borrower_id = (SELECT borrower_id FROM public.users_profile WHERE id = auth.uid()));

-- reservations: librarian full; teacher manages own
CREATE POLICY "reservations_librarian" ON public.reservations FOR ALL USING (public.get_user_role() = 'librarian');
CREATE POLICY "reservations_teacher_read" ON public.reservations FOR SELECT
  USING (public.get_user_role() = 'teacher' AND borrower_id = (SELECT borrower_id FROM public.users_profile WHERE id = auth.uid()));
CREATE POLICY "reservations_teacher_insert" ON public.reservations FOR INSERT
  WITH CHECK (public.get_user_role() = 'teacher' AND borrower_id = (SELECT borrower_id FROM public.users_profile WHERE id = auth.uid()));
CREATE POLICY "reservations_teacher_cancel" ON public.reservations FOR UPDATE
  USING (public.get_user_role() = 'teacher' AND borrower_id = (SELECT borrower_id FROM public.users_profile WHERE id = auth.uid()))
  WITH CHECK (status = 'cancelled');

-- notifications: librarian full; teacher reads own
CREATE POLICY "notifications_librarian" ON public.notifications FOR ALL USING (public.get_user_role() = 'librarian');
CREATE POLICY "notifications_teacher_read" ON public.notifications FOR SELECT
  USING (public.get_user_role() = 'teacher' AND borrower_id = (SELECT borrower_id FROM public.users_profile WHERE id = auth.uid()));

-- calendar_feeds: each user their own
CREATE POLICY "calendar_feeds_own" ON public.calendar_feeds FOR ALL USING (user_id = auth.uid());

-- audit_log: librarian can SELECT only; inserts via SECURITY DEFINER functions
CREATE POLICY "audit_log_librarian_read" ON public.audit_log FOR SELECT USING (public.get_user_role() = 'librarian');
