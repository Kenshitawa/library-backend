ALTER TABLE public.borrowers
  ADD COLUMN IF NOT EXISTS date_of_birth date,
  ADD COLUMN IF NOT EXISTS guardian_email text;
