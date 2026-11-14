-- Library profile (single row)
CREATE TABLE public.library_profile (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL DEFAULT 'School Library',
  address text,
  phone text,
  email text,
  logo_url text,
  term_dates jsonb DEFAULT '[]'::jsonb,
  primary_color text DEFAULT '#0f766e',
  currency text DEFAULT 'KES',
  timezone text DEFAULT 'Africa/Nairobi',
  damage_window_days int DEFAULT 7,
  lost_threshold_weeks int DEFAULT 4,
  lost_reversal_window_weeks int DEFAULT 4,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.subjects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE public.locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  parent_id uuid REFERENCES public.locations(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE public.borrower_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  return_rule text NOT NULL DEFAULT 'days' CHECK (return_rule IN ('fixed_term','year_end','days')),
  return_days int DEFAULT 14,
  max_items int DEFAULT 3,
  max_renewals int DEFAULT 2,
  can_reserve bool DEFAULT true,
  overdue_fee_enabled bool DEFAULT false,
  overdue_fee_per_day int DEFAULT 0,
  charge_threshold int DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE public.classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  grade_level text,
  stream text,
  year int DEFAULT EXTRACT(YEAR FROM now())::int,
  teacher_in_charge_id uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE public.borrowers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  borrower_type_id uuid REFERENCES public.borrower_types(id),
  borrower_no text UNIQUE NOT NULL,
  name text NOT NULL,
  class_id uuid REFERENCES public.classes(id),
  phone text,
  email text,
  guardian_name text,
  guardian_phone text,
  department text,
  status text DEFAULT 'active' CHECK (status IN ('active','inactive')),
  joined_on date,
  left_on date,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE public.users_profile (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  email text NOT NULL,
  role text NOT NULL CHECK (role IN ('librarian','teacher')),
  active bool DEFAULT true,
  borrower_id uuid REFERENCES public.borrowers(id),
  theme text DEFAULT 'system',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.authors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE public.titles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text,
  isbn10 text,
  isbn13 text,
  publisher text,
  year int,
  edition text,
  language text DEFAULT 'en',
  subject_id uuid REFERENCES public.subjects(id),
  grade_level text,
  type text DEFAULT 'library' CHECK (type IN ('textbook','library','reference')),
  description text,
  cover_url text,
  tags text[],
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE public.title_authors (
  title_id uuid REFERENCES public.titles(id) ON DELETE CASCADE,
  author_id uuid REFERENCES public.authors(id) ON DELETE CASCADE,
  PRIMARY KEY (title_id, author_id)
);

CREATE TABLE public.copies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title_id uuid NOT NULL REFERENCES public.titles(id),
  barcode text UNIQUE NOT NULL,
  location_id uuid REFERENCES public.locations(id),
  call_number text,
  status text DEFAULT 'available' CHECK (status IN ('available','issued','reserved','in_processing','lost','damaged','withdrawn')),
  condition text DEFAULT 'good' CHECK (condition IN ('good','fair','poor','damaged')),
  acquired_on date,
  price int,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE public.issues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  copy_id uuid NOT NULL REFERENCES public.copies(id),
  borrower_id uuid NOT NULL REFERENCES public.borrowers(id),
  issued_at timestamptz DEFAULT now(),
  due_at timestamptz NOT NULL,
  returned_at timestamptz,
  renewal_count int DEFAULT 0,
  condition_at_issue text DEFAULT 'good' CHECK (condition_at_issue IN ('good','fair','poor','damaged')),
  condition_at_return text CHECK (condition_at_return IN ('good','fair','poor','damaged')),
  issued_by uuid REFERENCES auth.users(id),
  returned_to uuid REFERENCES auth.users(id),
  status text DEFAULT 'open' CHECK (status IN ('open','returned','lost')),
  return_note text,
  return_photo_url text,
  override_reason text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

-- Prevent multiple open issues for same copy
CREATE UNIQUE INDEX copies_one_open_issue ON public.issues (copy_id) 
WHERE status = 'open' AND deleted_at IS NULL;

CREATE TABLE public.reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title_id uuid NOT NULL REFERENCES public.titles(id),
  borrower_id uuid NOT NULL REFERENCES public.borrowers(id),
  placed_at timestamptz DEFAULT now(),
  status text DEFAULT 'waiting' CHECK (status IN ('waiting','ready','fulfilled','cancelled','expired')),
  ready_copy_id uuid REFERENCES public.copies(id),
  pickup_deadline timestamptz,
  queue_position int,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE public.charges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  borrower_id uuid NOT NULL REFERENCES public.borrowers(id),
  issue_id uuid REFERENCES public.issues(id),
  type text NOT NULL CHECK (type IN ('lost','damaged','overdue','manual')),
  amount int NOT NULL,
  paid_amount int DEFAULT 0,
  status text DEFAULT 'open' CHECK (status IN ('open','partial','paid','waived')),
  reason text,
  waived_by uuid REFERENCES auth.users(id),
  waive_reason text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  charge_id uuid NOT NULL REFERENCES public.charges(id),
  borrower_id uuid NOT NULL REFERENCES public.borrowers(id),
  amount int NOT NULL,
  received_by uuid REFERENCES auth.users(id),
  received_at timestamptz DEFAULT now(),
  receipt_no text,
  receipt_url text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  borrower_id uuid REFERENCES public.borrowers(id),
  type text NOT NULL,
  channel text DEFAULT 'email',
  recipient text,
  subject text,
  body text,
  sent_at timestamptz,
  status text DEFAULT 'pending' CHECK (status IN ('pending','sent','failed','not_sent')),
  error text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.calendar_feeds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  token_hash text NOT NULL,
  created_at timestamptz DEFAULT now(),
  revoked_at timestamptz
);

CREATE TABLE public.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  action text NOT NULL,
  entity text NOT NULL,
  entity_id uuid,
  before jsonb,
  after jsonb,
  ip_addr text,
  created_at timestamptz DEFAULT now()
);

-- updated_at trigger function
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all relevant tables
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.subjects FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.locations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.borrower_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.classes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.borrowers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.users_profile FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.authors FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.titles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.copies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.issues FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.reservations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.charges FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.notifications FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.library_profile FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
