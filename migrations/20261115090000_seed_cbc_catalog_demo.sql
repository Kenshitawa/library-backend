-- Sample catalog records for demonstration. Source: KICD December 2024
-- Addendum to the Orange Book (Pre-primary through Grade 9).
-- Demo titles and copies are deliberately labeled so they can be removed
-- after the demonstration without confusing them with purchased stock.

INSERT INTO public.borrower_types (name, return_rule, return_days, max_items, max_renewals, can_reserve, overdue_fee_enabled)
SELECT source.name, source.return_rule, source.return_days, source.max_items, source.max_renewals, true, false
FROM (VALUES
  ('Learner', 'year_end', 365, 3, 2),
  ('Teacher', 'days', 14, 5, 2)
) AS source(name, return_rule, return_days, max_items, max_renewals)
WHERE NOT EXISTS (
  SELECT 1 FROM public.borrower_types existing
  WHERE lower(existing.name) = lower(source.name) AND existing.deleted_at IS NULL
);

INSERT INTO public.subjects (name)
SELECT source.name
FROM (VALUES ('English'), ('Mathematics'), ('Science'), ('Agriculture'), ('Christian Religious Education')) AS source(name)
WHERE NOT EXISTS (
  SELECT 1 FROM public.subjects existing
  WHERE lower(existing.name) = lower(source.name) AND existing.deleted_at IS NULL
);

WITH demo_titles(title, publisher, grade_level, subject_name, cover_url, authors) AS (
  VALUES
    ('Longhorn English Language Activities Learners Book Grade 1', 'Longhorn', '1', 'English', '/images/demo-kicd-grade-1.svg', 'Tom Olang; Beatrice Mwebi; Immaculate Oundo; Joseph Ouma; Naomi Kanyiri'),
    ('KLB Visionary English Language Activities Learner’s Book Grade 2', 'KLB', '2', 'English', '/images/demo-kicd-grade-2.svg', 'Solomon Ngila Musee; Hannah Wanjiku Ngaruiya; Argwings Otieno; Gatitu Kiguru; Jacqueline Mwangi'),
    ('Longhorn English Language Activities Learners Book Grade 3', 'Longhorn', '3', 'English', '/images/demo-kicd-grade-3.svg', 'Naomi Kanyiri; Pauline Kagwe; Ezekiel Wangusi; Tom Olang; Beatrice Mwebi'),
    ('Skills in English, English language Learner’s Book Grade 4', 'Moran', '4', 'English', '/images/demo-kicd-grade-4.svg', 'Diane Omondi; Joseph Ndirangu; Grace Nanjendo; Hukka Wario; Moth Pritchard; Rosemary Karani'),
    ('Mentor Agriculture Learner’s Book Grade 5', 'Mentor', '5', 'Agriculture', '/images/demo-kicd-grade-5.svg', 'A. Wesonga; J. Opondo; E. Wairimu; G. Waweru; H. Kimaru; J. Thungu'),
    ('MTP Agriculture Learner’s Book Grade 6', 'MTP', '6', 'Agriculture', '/images/demo-kicd-grade-6.svg', 'Mountain Top Publishers'),
    ('StoryMoja Spark Agriculture Learner’s Book Grade 7', 'StoryMoja', '7', 'Agriculture', '/images/demo-kicd-grade-7.svg', 'Jane Muinde; Winnie Biwott; Juma Kwoma; Jeremiah Luvembe; Damaris Wambua; Rose Mbiyu; Brian Ongwena'),
    ('Love your Neighbour Christian Religious Education Learner’s Book Grade 8', 'Moran', '8', 'Christian Religious Education', '/images/demo-kicd-grade-8.svg', 'Linah Kiget; Patrick Tumusiime'),
    ('Oxford Head Start English Learner’s Book Grade 9', 'Oxford University Press', '9', 'English', '/images/demo-kicd-grade-9.svg', 'Angelina Kioko; Benedict Mutei; Esther Katumbi; Judith Munyiri; Shikuku Shitubi')
), subject_ids AS (
  SELECT DISTINCT ON (lower(name)) id, name
  FROM public.subjects
  WHERE deleted_at IS NULL
  ORDER BY lower(name), created_at
)
INSERT INTO public.titles (title, publisher, grade_level, subject_id, type, language, description, cover_url, tags)
SELECT
  d.title,
  d.publisher,
  d.grade_level,
  s.id,
  'textbook',
  CASE WHEN d.title LIKE '%Gredi%' THEN 'sw' ELSE 'en' END,
  'DEMO CATALOG RECORD. KICD-approved title listed in the December 2024 Addendum to the Orange Book. Authors: ' || d.authors || '. Thumbnail is illustrative demo artwork, not the publisher’s original cover.',
  d.cover_url,
  ARRAY['demo', 'KICD approved', 'CBE', 'grade ' || d.grade_level]
FROM demo_titles d
LEFT JOIN subject_ids s ON lower(s.name) = lower(d.subject_name)
WHERE NOT EXISTS (
  SELECT 1 FROM public.titles existing
  WHERE lower(existing.title) = lower(d.title) AND existing.deleted_at IS NULL
);

WITH demo_authors(title, authors) AS (
  VALUES
    ('Longhorn English Language Activities Learners Book Grade 1', 'Tom Olang; Beatrice Mwebi; Immaculate Oundo; Joseph Ouma; Naomi Kanyiri'),
    ('KLB Visionary English Language Activities Learner’s Book Grade 2', 'Solomon Ngila Musee; Hannah Wanjiku Ngaruiya; Argwings Otieno; Gatitu Kiguru; Jacqueline Mwangi'),
    ('Longhorn English Language Activities Learners Book Grade 3', 'Naomi Kanyiri; Pauline Kagwe; Ezekiel Wangusi; Tom Olang; Beatrice Mwebi'),
    ('Skills in English, English language Learner’s Book Grade 4', 'Diane Omondi; Joseph Ndirangu; Grace Nanjendo; Hukka Wario; Moth Pritchard; Rosemary Karani'),
    ('Mentor Agriculture Learner’s Book Grade 5', 'A. Wesonga; J. Opondo; E. Wairimu; G. Waweru; H. Kimaru; J. Thungu'),
    ('MTP Agriculture Learner’s Book Grade 6', 'Mountain Top Publishers'),
    ('StoryMoja Spark Agriculture Learner’s Book Grade 7', 'Jane Muinde; Winnie Biwott; Juma Kwoma; Jeremiah Luvembe; Damaris Wambua; Rose Mbiyu; Brian Ongwena'),
    ('Love your Neighbour Christian Religious Education Learner’s Book Grade 8', 'Linah Kiget; Patrick Tumusiime'),
    ('Oxford Head Start English Learner’s Book Grade 9', 'Angelina Kioko; Benedict Mutei; Esther Katumbi; Judith Munyiri; Shikuku Shitubi')
), expanded AS (
  SELECT title, trim(author_name.name) AS author_name
  FROM demo_authors
  CROSS JOIN LATERAL unnest(string_to_array(authors, ';')) AS author_name(name)
)
INSERT INTO public.authors (name)
SELECT DISTINCT expanded.author_name
FROM expanded
WHERE NOT EXISTS (
  SELECT 1 FROM public.authors existing WHERE lower(existing.name) = lower(expanded.author_name) AND existing.deleted_at IS NULL
);

WITH demo_authors(title, authors) AS (
  VALUES
    ('Longhorn English Language Activities Learners Book Grade 1', 'Tom Olang; Beatrice Mwebi; Immaculate Oundo; Joseph Ouma; Naomi Kanyiri'),
    ('KLB Visionary English Language Activities Learner’s Book Grade 2', 'Solomon Ngila Musee; Hannah Wanjiku Ngaruiya; Argwings Otieno; Gatitu Kiguru; Jacqueline Mwangi'),
    ('Longhorn English Language Activities Learners Book Grade 3', 'Naomi Kanyiri; Pauline Kagwe; Ezekiel Wangusi; Tom Olang; Beatrice Mwebi'),
    ('Skills in English, English language Learner’s Book Grade 4', 'Diane Omondi; Joseph Ndirangu; Grace Nanjendo; Hukka Wario; Moth Pritchard; Rosemary Karani'),
    ('Mentor Agriculture Learner’s Book Grade 5', 'A. Wesonga; J. Opondo; E. Wairimu; G. Waweru; H. Kimaru; J. Thungu'),
    ('MTP Agriculture Learner’s Book Grade 6', 'Mountain Top Publishers'),
    ('StoryMoja Spark Agriculture Learner’s Book Grade 7', 'Jane Muinde; Winnie Biwott; Juma Kwoma; Jeremiah Luvembe; Damaris Wambua; Rose Mbiyu; Brian Ongwena'),
    ('Love your Neighbour Christian Religious Education Learner’s Book Grade 8', 'Linah Kiget; Patrick Tumusiime'),
    ('Oxford Head Start English Learner’s Book Grade 9', 'Angelina Kioko; Benedict Mutei; Esther Katumbi; Judith Munyiri; Shikuku Shitubi')
), expanded AS (
  SELECT title, trim(author_name.name) AS author_name
  FROM demo_authors
  CROSS JOIN LATERAL unnest(string_to_array(authors, ';')) AS author_name(name)
)
INSERT INTO public.title_authors (title_id, author_id)
SELECT t.id, a.id
FROM expanded
JOIN public.titles t ON t.title = expanded.title AND t.deleted_at IS NULL
JOIN public.authors a ON lower(a.name) = lower(expanded.author_name) AND a.deleted_at IS NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.title_authors existing WHERE existing.title_id = t.id AND existing.author_id = a.id
);

INSERT INTO public.locations (name)
SELECT 'Main Library'
WHERE NOT EXISTS (
  SELECT 1 FROM public.locations WHERE lower(name) = 'main library' AND deleted_at IS NULL
);

INSERT INTO public.copies (title_id, barcode, location_id, status, condition)
SELECT t.id, demo.barcode, location.id, 'available', 'good'
FROM (VALUES
  ('Longhorn English Language Activities Learners Book Grade 1', 'DEMO-CBE-G1-01'),
  ('Longhorn English Language Activities Learners Book Grade 1', 'DEMO-CBE-G1-02'),
  ('KLB Visionary English Language Activities Learner’s Book Grade 2', 'DEMO-CBE-G2-01'),
  ('KLB Visionary English Language Activities Learner’s Book Grade 2', 'DEMO-CBE-G2-02'),
  ('Longhorn English Language Activities Learners Book Grade 3', 'DEMO-CBE-G3-01'),
  ('Longhorn English Language Activities Learners Book Grade 3', 'DEMO-CBE-G3-02'),
  ('Skills in English, English language Learner’s Book Grade 4', 'DEMO-CBE-G4-01'),
  ('Skills in English, English language Learner’s Book Grade 4', 'DEMO-CBE-G4-02'),
  ('Mentor Agriculture Learner’s Book Grade 5', 'DEMO-CBE-G5-01'),
  ('Mentor Agriculture Learner’s Book Grade 5', 'DEMO-CBE-G5-02'),
  ('MTP Agriculture Learner’s Book Grade 6', 'DEMO-CBE-G6-01'),
  ('MTP Agriculture Learner’s Book Grade 6', 'DEMO-CBE-G6-02'),
  ('StoryMoja Spark Agriculture Learner’s Book Grade 7', 'DEMO-CBE-G7-01'),
  ('StoryMoja Spark Agriculture Learner’s Book Grade 7', 'DEMO-CBE-G7-02'),
  ('Love your Neighbour Christian Religious Education Learner’s Book Grade 8', 'DEMO-CBE-G8-01'),
  ('Love your Neighbour Christian Religious Education Learner’s Book Grade 8', 'DEMO-CBE-G8-02'),
  ('Oxford Head Start English Learner’s Book Grade 9', 'DEMO-CBE-G9-01'),
  ('Oxford Head Start English Learner’s Book Grade 9', 'DEMO-CBE-G9-02')
) AS demo(title, barcode)
JOIN public.titles t ON t.title = demo.title AND t.deleted_at IS NULL
CROSS JOIN LATERAL (
  SELECT id FROM public.locations WHERE lower(name) = 'main library' AND deleted_at IS NULL ORDER BY created_at LIMIT 1
) location
WHERE NOT EXISTS (SELECT 1 FROM public.copies c WHERE c.barcode = demo.barcode);

INSERT INTO public.classes (name, grade_level, stream, year)
SELECT 'DEMO DATA: Grade ' || grade, grade::text, 'Demo', EXTRACT(YEAR FROM now())::int
FROM generate_series(1, 9) AS grade
WHERE NOT EXISTS (
  SELECT 1 FROM public.classes c
  WHERE c.name = 'DEMO DATA: Grade ' || grade AND c.deleted_at IS NULL
);

INSERT INTO public.borrowers (borrower_type_id, borrower_no, name, class_id, phone, status, joined_on, notes)
SELECT learner_type.id,
  'DEMO-LRN-G' || grade,
  'DEMO DATA: Learner Grade ' || grade,
  class.id,
  '0712345' || lpad(grade::text, 3, '0'),
  'active', current_date,
  'DEMO DATA record for demonstration. Safe to remove after the demo.'
FROM generate_series(1, 9) AS grade
JOIN public.borrower_types learner_type ON lower(learner_type.name) = 'learner' AND learner_type.deleted_at IS NULL
JOIN public.classes class ON class.name = 'DEMO DATA: Grade ' || grade AND class.deleted_at IS NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.borrowers b WHERE b.borrower_no = 'DEMO-LRN-G' || grade
);

INSERT INTO public.borrowers (borrower_type_id, borrower_no, name, department, status, joined_on, notes)
SELECT teacher_type.id, 'DEMO-TCH-001', 'DEMO DATA: Teacher', 'Mathematics', 'active', current_date,
  'DEMO DATA record for demonstration. Safe to remove after the demo.'
FROM public.borrower_types teacher_type
WHERE lower(teacher_type.name) = 'teacher' AND teacher_type.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM public.borrowers b WHERE b.borrower_no = 'DEMO-TCH-001');

INSERT INTO public.issues (copy_id, borrower_id, due_at, status)
SELECT c.id, b.id, now() + interval '14 days', 'open'
FROM public.copies c
JOIN public.titles t ON t.id = c.title_id
JOIN public.borrowers b ON b.borrower_no = 'DEMO-LRN-G6'
WHERE c.barcode = 'DEMO-CBE-G6-01'
  AND NOT EXISTS (SELECT 1 FROM public.issues i WHERE i.copy_id = c.id AND i.status = 'open' AND i.deleted_at IS NULL);

INSERT INTO public.issues (copy_id, borrower_id, due_at, returned_at, condition_at_return, status)
SELECT c.id, b.id, now() - interval '7 days', now() - interval '2 days', 'good', 'returned'
FROM public.copies c
JOIN public.borrowers b ON b.borrower_no = 'DEMO-LRN-G7'
WHERE c.barcode = 'DEMO-CBE-G7-01'
  AND NOT EXISTS (SELECT 1 FROM public.issues i WHERE i.copy_id = c.id AND i.deleted_at IS NULL);

UPDATE public.copies c SET status = 'issued'
FROM public.issues i
WHERE i.copy_id = c.id AND i.status = 'open' AND c.barcode = 'DEMO-CBE-G6-01';

INSERT INTO public.reservations (title_id, borrower_id, status, queue_position)
SELECT t.id, b.id, 'waiting', 1
FROM public.titles t
JOIN public.borrowers b ON b.borrower_no = 'DEMO-LRN-G9'
WHERE t.title = 'Oxford Head Start English Learner’s Book Grade 9'
  AND NOT EXISTS (
    SELECT 1 FROM public.reservations r
    WHERE r.title_id = t.id AND r.borrower_id = b.id AND r.status IN ('waiting', 'ready') AND r.deleted_at IS NULL
  );

INSERT INTO public.charges (borrower_id, type, amount, status, reason)
SELECT b.id, 'manual', 250, 'open', 'DEMO DATA: Sample replacement fee'
FROM public.borrowers b
WHERE b.borrower_no = 'DEMO-LRN-G6'
  AND NOT EXISTS (SELECT 1 FROM public.charges c WHERE c.reason = 'DEMO DATA: Sample replacement fee' AND c.borrower_id = b.id);

INSERT INTO public.notifications (borrower_id, type, channel, recipient, subject, body, status)
SELECT b.id, 'demo', 'app', 'DEMO DATA', 'Sample library notice', 'This is sample content for the demonstration.', 'not_sent'
FROM public.borrowers b
WHERE b.borrower_no = 'DEMO-LRN-G1'
  AND NOT EXISTS (SELECT 1 FROM public.notifications n WHERE n.subject = 'Sample library notice' AND n.borrower_id = b.id);
