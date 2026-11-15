-- Use the official KICD learning-area names in the title form, give the demo
-- classes simple Grade 1–9 labels, and replace illustrative cover artwork with
-- actual covers for the corresponding listed books.

INSERT INTO public.subjects (name)
SELECT source.name
FROM (VALUES
  ('English'),
  ('English Language Activities'),
  ('Kiswahili'),
  ('Kiswahili Language Activities'),
  ('Kiswahili / Kenya Sign Language'),
  ('Indigenous Languages'),
  ('Kenya Sign Language'),
  ('Mathematics'),
  ('Mathematical Activities'),
  ('Religious Education'),
  ('Religious Education Activities'),
  ('Christian Religious Education'),
  ('Islamic Religious Education'),
  ('Hindu Religious Education'),
  ('Environmental Activities'),
  ('Creative Activities'),
  ('Science and Technology'),
  ('Agriculture'),
  ('Social Studies'),
  ('Creative Arts'),
  ('Integrated Science'),
  ('Pre-Technical Studies'),
  ('Creative Arts and Sports'),
  ('Agriculture and Nutrition'),
  ('Arabic'),
  ('French'),
  ('German'),
  ('Mandarin')
) AS source(name)
WHERE NOT EXISTS (
  SELECT 1 FROM public.subjects existing
  WHERE lower(existing.name) = lower(source.name) AND existing.deleted_at IS NULL
);

UPDATE public.classes AS class
SET name = regexp_replace(class.name, '^DEMO DATA: Grade ', 'Grade '),
    updated_at = now()
WHERE class.name ~ '^DEMO DATA: Grade [1-9]$'
  AND class.deleted_at IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.classes existing
    WHERE existing.name = regexp_replace(class.name, '^DEMO DATA: Grade ', 'Grade ')
      AND existing.deleted_at IS NULL
      AND existing.id <> class.id
  );

UPDATE public.titles SET cover_url = '/images/book-covers/grade-1-longhorn-english.jpg'
WHERE title = 'Longhorn English Language Activities Learners Book Grade 1' AND deleted_at IS NULL;
UPDATE public.titles SET cover_url = '/images/book-covers/grade-2-klb-english.jpg'
WHERE title = 'KLB Visionary English Language Activities Learner’s Book Grade 2' AND deleted_at IS NULL;
UPDATE public.titles SET cover_url = '/images/book-covers/grade-3-longhorn-english.jpg'
WHERE title = 'Longhorn English Language Activities Learners Book Grade 3' AND deleted_at IS NULL;
UPDATE public.titles SET cover_url = '/images/book-covers/grade-4-moran-skills-english.jpg'
WHERE title = 'Skills in English, English language Learner’s Book Grade 4' AND deleted_at IS NULL;
UPDATE public.titles SET cover_url = '/images/book-covers/grade-5-mentor-agriculture.jpg'
WHERE title = 'Mentor Agriculture Learner’s Book Grade 5' AND deleted_at IS NULL;
UPDATE public.titles
SET title = 'Access and Learn Agriculture Learner’s Book Grade 6',
    publisher = 'Access Publishers',
    description = 'DEMO CATALOG RECORD. KICD-approved title. Actual publisher cover image is included for identification.',
    cover_url = '/images/book-covers/grade-6-access-agriculture.png',
    updated_at = now()
WHERE title = 'MTP Agriculture Learner’s Book Grade 6' AND deleted_at IS NULL;
UPDATE public.titles SET cover_url = '/images/book-covers/grade-7-storymoja-spark-agriculture.jpg'
WHERE title = 'StoryMoja Spark Agriculture Learner’s Book Grade 7' AND deleted_at IS NULL;
UPDATE public.titles SET cover_url = '/images/book-covers/grade-8-moran-cre.jpg'
WHERE title = 'Love your Neighbour Christian Religious Education Learner’s Book Grade 8' AND deleted_at IS NULL;
UPDATE public.titles SET cover_url = '/images/book-covers/grade-9-oxford-head-start-english.jpg'
WHERE title = 'Oxford Head Start English Learner’s Book Grade 9' AND deleted_at IS NULL;

INSERT INTO public.authors (name)
SELECT author_names.name
FROM (VALUES ('Isla Ambiyo'), ('Fred Machoka'), ('Zippline Ogake')) AS author_names(name)
WHERE NOT EXISTS (
  SELECT 1 FROM public.authors existing
  WHERE lower(existing.name) = lower(author_names.name) AND existing.deleted_at IS NULL
);

WITH grade_six AS (
  SELECT id FROM public.titles
  WHERE title = 'Access and Learn Agriculture Learner’s Book Grade 6' AND deleted_at IS NULL
), subject AS (
  SELECT id FROM public.subjects
  WHERE lower(name) = lower('Agriculture') AND deleted_at IS NULL
  ORDER BY created_at LIMIT 1
)
UPDATE public.titles title
SET subject_id = subject.id
FROM grade_six, subject
WHERE title.id = grade_six.id;

WITH grade_six AS (
  SELECT id FROM public.titles
  WHERE title = 'Access and Learn Agriculture Learner’s Book Grade 6' AND deleted_at IS NULL
)
DELETE FROM public.title_authors link
USING grade_six
WHERE link.title_id = grade_six.id;

WITH grade_six AS (
  SELECT id FROM public.titles
  WHERE title = 'Access and Learn Agriculture Learner’s Book Grade 6' AND deleted_at IS NULL
), authors AS (
  SELECT id FROM public.authors
  WHERE lower(name) IN (lower('Isla Ambiyo'), lower('Fred Machoka'), lower('Zippline Ogake'))
    AND deleted_at IS NULL
)
INSERT INTO public.title_authors (title_id, author_id)
SELECT grade_six.id, authors.id FROM grade_six CROSS JOIN authors
ON CONFLICT DO NOTHING;
