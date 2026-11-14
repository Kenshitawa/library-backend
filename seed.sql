-- TEST DATA: School Library Management System seed data
-- This file is for local development only. Remove all TEST DATA before production.

-- Library Profile
INSERT INTO public.library_profile (name, address, timezone, term_dates) VALUES (
  'Greenfield Academy Library',
  '123 School Road, Greenfield',
  'Africa/Nairobi',
  '[
    {"name": "Term 1", "start": "2024-01-17", "end": "2024-03-21"},
    {"name": "Term 2", "start": "2024-04-09", "end": "2024-06-20"},
    {"name": "Term 3", "start": "2024-07-16", "end": "2024-09-20"},
    {"name": "Term 4", "start": "2024-10-07", "end": "2024-12-04"}
  ]'::jsonb
) ON CONFLICT DO NOTHING;

-- TEST DATA: Borrower Types
INSERT INTO public.borrower_types (id, name, return_rule, return_days, max_items, max_renewals, can_reserve, overdue_fee_enabled) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Learner', 'year_end', 365, 3, 2, true, false),
  ('00000000-0000-0000-0000-000000000002', 'Teacher', 'days', 14, 5, 2, true, false)
ON CONFLICT (id) DO NOTHING;

-- TEST DATA: Subjects
INSERT INTO public.subjects (id, name) VALUES
  ('00000000-0000-0000-0001-000000000001', 'Mathematics'),
  ('00000000-0000-0000-0001-000000000002', 'English'),
  ('00000000-0000-0000-0001-000000000003', 'Science'),
  ('00000000-0000-0000-0001-000000000004', 'History'),
  ('00000000-0000-0000-0001-000000000005', 'Physical Education')
ON CONFLICT (id) DO NOTHING;

-- TEST DATA: Locations
INSERT INTO public.locations (id, name) VALUES
  ('00000000-0000-0000-0002-000000000001', 'Main Library'),
  ('00000000-0000-0000-0002-000000000002', 'Reference Shelf'),
  ('00000000-0000-0000-0002-000000000003', 'Staff Room')
ON CONFLICT (id) DO NOTHING;

-- TEST DATA: Classes
INSERT INTO public.classes (id, name, grade_level, stream, year) VALUES
  ('00000000-0000-0000-0003-000000000001', 'Grade 6 Blue', '6', 'Blue', 2024),
  ('00000000-0000-0000-0003-000000000002', 'Grade 7 Blue', '7', 'Blue', 2024)
ON CONFLICT (id) DO NOTHING;

-- TEST DATA: Borrowers (Learners)
INSERT INTO public.borrowers (id, borrower_type_id, borrower_no, name, class_id, status, joined_on) VALUES
  ('00000000-0000-0001-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'LRN-0001', 'TEST DATA: Alice Nkosi', '00000000-0000-0000-0003-000000000001', 'active', '2024-01-17'),
  ('00000000-0000-0001-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'LRN-0002', 'TEST DATA: Bongani Dlamini', '00000000-0000-0000-0003-000000000001', 'active', '2024-01-17'),
  ('00000000-0000-0001-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'LRN-0003', 'TEST DATA: Chloe van der Berg', '00000000-0000-0000-0003-000000000001', 'active', '2024-01-17'),
  ('00000000-0000-0001-0000-000000000004', '00000000-0000-0000-0000-000000000001', 'LRN-0004', 'TEST DATA: David Sithole', '00000000-0000-0000-0003-000000000001', 'active', '2024-01-17'),
  ('00000000-0000-0001-0000-000000000005', '00000000-0000-0000-0000-000000000001', 'LRN-0005', 'TEST DATA: Emma Patel', '00000000-0000-0000-0003-000000000001', 'active', '2024-01-17')
ON CONFLICT (id) DO NOTHING;

-- TEST DATA: Borrowers (Teachers)
INSERT INTO public.borrowers (id, borrower_type_id, borrower_no, name, department, email, status, joined_on) VALUES
  ('00000000-0000-0001-0000-000000000006', '00000000-0000-0000-0000-000000000002', 'TCH-0001', 'TEST DATA: Prof James Molefe', 'Mathematics', 'teacher@library.test', 'active', '2024-01-17'),
  ('00000000-0000-0001-0000-000000000007', '00000000-0000-0000-0000-000000000002', 'TCH-0002', 'TEST DATA: Ms Sarah Williams', 'English', 'teacher2@library.test', 'active', '2024-01-17')
ON CONFLICT (id) DO NOTHING;

-- TEST DATA: Titles
INSERT INTO public.titles (id, title, subject_id, grade_level, type, language, year) VALUES
  ('00000000-0000-0002-0000-000000000001', 'TEST DATA: Mathematics Grade 6', '00000000-0000-0000-0001-000000000001', '6', 'textbook', 'en', 2022),
  ('00000000-0000-0002-0000-000000000002', 'TEST DATA: English Home Language Grade 6', '00000000-0000-0000-0001-000000000002', '6', 'textbook', 'en', 2022),
  ('00000000-0000-0002-0000-000000000003', 'TEST DATA: Natural Sciences Grade 6', '00000000-0000-0000-0001-000000000003', '6', 'textbook', 'en', 2022),
  ('00000000-0000-0002-0000-000000000004', 'TEST DATA: Encyclopedia of World History', '00000000-0000-0000-0001-000000000004', null, 'reference', 'en', 2020),
  ('00000000-0000-0002-0000-000000000005', 'TEST DATA: Charlotte''s Web', null, '5', 'library', 'en', 2015),
  ('00000000-0000-0002-0000-000000000006', 'TEST DATA: The BFG', null, '5', 'library', 'en', 2016)
ON CONFLICT (id) DO NOTHING;

-- TEST DATA: Copies (barcodes TEST-0001 onward)
INSERT INTO public.copies (id, title_id, barcode, location_id, status, condition, price) VALUES
  -- Math Grade 6: 3 copies
  ('00000000-0000-0003-0000-000000000001', '00000000-0000-0002-0000-000000000001', 'TEST-0001', '00000000-0000-0000-0002-000000000001', 'issued', 'good', 28000),
  ('00000000-0000-0003-0000-000000000002', '00000000-0000-0002-0000-000000000001', 'TEST-0002', '00000000-0000-0000-0002-000000000001', 'available', 'good', 28000),
  ('00000000-0000-0003-0000-000000000003', '00000000-0000-0002-0000-000000000001', 'TEST-0003', '00000000-0000-0000-0002-000000000001', 'issued', 'good', 28000),
  -- English Grade 6: 3 copies
  ('00000000-0000-0003-0000-000000000004', '00000000-0000-0002-0000-000000000002', 'TEST-0004', '00000000-0000-0000-0002-000000000001', 'available', 'good', 25000),
  ('00000000-0000-0003-0000-000000000005', '00000000-0000-0002-0000-000000000002', 'TEST-0005', '00000000-0000-0000-0002-000000000001', 'available', 'good', 25000),
  ('00000000-0000-0003-0000-000000000006', '00000000-0000-0002-0000-000000000002', 'TEST-0006', '00000000-0000-0000-0002-000000000001', 'available', 'good', 25000),
  -- Natural Sciences: 2 copies
  ('00000000-0000-0003-0000-000000000007', '00000000-0000-0002-0000-000000000003', 'TEST-0007', '00000000-0000-0000-0002-000000000001', 'issued', 'fair', 26000),
  ('00000000-0000-0003-0000-000000000008', '00000000-0000-0002-0000-000000000003', 'TEST-0008', '00000000-0000-0000-0002-000000000001', 'available', 'good', 26000),
  -- Encyclopedia: 2 copies (reference)
  ('00000000-0000-0003-0000-000000000009', '00000000-0000-0002-0000-000000000004', 'TEST-0009', '00000000-0000-0000-0002-000000000002', 'available', 'good', 45000),
  ('00000000-0000-0003-0000-000000000010', '00000000-0000-0002-0000-000000000004', 'TEST-0010', '00000000-0000-0000-0002-000000000002', 'available', 'good', 45000),
  -- Charlotte''s Web: 3 copies
  ('00000000-0000-0003-0000-000000000011', '00000000-0000-0002-0000-000000000005', 'TEST-0011', '00000000-0000-0000-0002-000000000001', 'available', 'good', 15000),
  ('00000000-0000-0003-0000-000000000012', '00000000-0000-0002-0000-000000000005', 'TEST-0012', '00000000-0000-0000-0002-000000000001', 'available', 'good', 15000),
  ('00000000-0000-0003-0000-000000000013', '00000000-0000-0002-0000-000000000005', 'TEST-0013', '00000000-0000-0000-0002-000000000001', 'available', 'good', 15000),
  -- The BFG: 2 copies
  ('00000000-0000-0003-0000-000000000014', '00000000-0000-0002-0000-000000000006', 'TEST-0014', '00000000-0000-0000-0002-000000000001', 'available', 'good', 14000),
  ('00000000-0000-0003-0000-000000000015', '00000000-0000-0002-0000-000000000006', 'TEST-0015', '00000000-0000-0000-0002-000000000001', 'available', 'good', 14000)
ON CONFLICT (id) DO NOTHING;

-- TEST DATA: Issues
-- Note: auth users must be created first via seed_auth.sh; these issues reference borrowers only
-- Issue 1: due in 2 days (overdue risk)
INSERT INTO public.issues (id, copy_id, borrower_id, issued_at, due_at, status, condition_at_issue) VALUES
  ('00000000-0000-0004-0000-000000000001', '00000000-0000-0003-0000-000000000001', '00000000-0000-0001-0000-000000000001', 
   now() - interval '12 days', now() + interval '2 days', 'open', 'good'),
  -- Issue 2: due in 10 days
  ('00000000-0000-0004-0000-000000000002', '00000000-0000-0003-0000-000000000003', '00000000-0000-0001-0000-000000000002',
   now() - interval '4 days', now() + interval '10 days', 'open', 'good'),
  -- Issue 3: overdue by 5 days
  ('00000000-0000-0004-0000-000000000003', '00000000-0000-0003-0000-000000000007', '00000000-0000-0001-0000-000000000003',
   now() - interval '20 days', now() - interval '5 days', 'open', 'fair')
ON CONFLICT (id) DO NOTHING;
