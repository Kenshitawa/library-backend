ALTER TABLE public.library_profile
  ALTER COLUMN currency SET DEFAULT 'KES',
  ALTER COLUMN timezone SET DEFAULT 'Africa/Nairobi';

UPDATE public.library_profile
SET currency = 'KES',
    timezone = 'Africa/Nairobi',
    updated_at = now();
