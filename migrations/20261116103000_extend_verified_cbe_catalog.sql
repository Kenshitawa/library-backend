-- Add additional KICD-listed KLB Mathematics titles with publisher/retailer
-- cover photographs for visual identification. These are title records only;
-- they do not create pretend physical copies or availability.

WITH book_rows(title, isbn13, grade_level, subject_name, publisher, cover_url, authors) AS (
  VALUES
    ('KLB Visionary Mathematics Activities Grade 1', '9789966652362', '1', 'Mathematical Activities', 'Kenya Literature Bureau (KLB)', '/images/book-covers/klb-visionary-mathematics-grade-1.png', 'F. Mwangi; S. Ogweno'),
    ('KLB Visionary Mathematical Activities Grade 2', '9789966652188', '2', 'Mathematical Activities', 'Kenya Literature Bureau (KLB)', '/images/book-covers/klb-visionary-mathematics-grade-2.jpg', 'Samuel G. Irumbi; Patrick Kimere'),
    ('KLB Visionary Mathematics Activities Grade 3', '9789914550238', '3', 'Mathematical Activities', 'Kenya Literature Bureau (KLB)', '/images/book-covers/klb-visionary-mathematics-grade-3.jpg', 'Obadiah K.; Washington Mbiruru'),
    ('KLB Visionary Mathematics Learner’s Book Grade 4', '9789914550252', '4', 'Mathematics', 'Kenya Literature Bureau (KLB)', '/images/book-covers/klb-visionary-mathematics-grade-4.png', 'Obadiah Kiburi; Samuel Irumbi; Zipporah N. Mulli; Francis Mwangi'),
    ('KLB Visionary Mathematics Learner’s Book Grade 5', '9789914551310', '5', 'Mathematics', 'Kenya Literature Bureau (KLB)', '/images/book-covers/klb-visionary-mathematics-grade-5.jpg', 'Samuel G. Irumbi; Francis Mwangi; Israel Owiti; Obadiah K. Kariuki; Zipporah N. Muli; Washington Mbiruru')
)
INSERT INTO public.titles
  (title, isbn13, publisher, grade_level, subject_id, type, language, description, cover_url, tags)
SELECT
  b.title,
  b.isbn13,
  b.publisher,
  b.grade_level,
  s.id,
  'textbook',
  'en',
  'KICD-approved CBE learner’s book. KICD Orange Book listing and publisher-authored details were checked; authors: ' || b.authors || '.',
  b.cover_url,
  ARRAY['KICD approved', 'CBE', 'Grade ' || b.grade_level, b.subject_name]
FROM book_rows b
JOIN public.subjects s ON lower(s.name) = lower(b.subject_name) AND s.deleted_at IS NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.titles existing
  WHERE existing.deleted_at IS NULL
    AND (lower(existing.title) = lower(b.title) OR existing.isbn13 = b.isbn13)
);

WITH author_names(name) AS (
  VALUES
    ('F. Mwangi'), ('S. Ogweno'), ('Samuel G. Irumbi'), ('Patrick Kimere'),
    ('Obadiah K.'), ('Washington Mbiruru'), ('Obadiah Kiburi'), ('Samuel Irumbi'),
    ('Zipporah N. Mulli'), ('Samuel G. Irumbi'), ('Obadiah K. Kariuki'), ('Zipporah N. Muli')
)
INSERT INTO public.authors (name)
SELECT DISTINCT author_names.name
FROM author_names
WHERE NOT EXISTS (
  SELECT 1 FROM public.authors existing
  WHERE lower(existing.name) = lower(author_names.name) AND existing.deleted_at IS NULL
);

WITH book_rows(title, authors) AS (
  VALUES
    ('KLB Visionary Mathematics Activities Grade 1', 'F. Mwangi; S. Ogweno'),
    ('KLB Visionary Mathematical Activities Grade 2', 'Samuel G. Irumbi; Patrick Kimere'),
    ('KLB Visionary Mathematics Activities Grade 3', 'Obadiah K.; Washington Mbiruru'),
    ('KLB Visionary Mathematics Learner’s Book Grade 4', 'Obadiah Kiburi; Samuel Irumbi; Zipporah N. Mulli; Francis Mwangi'),
    ('KLB Visionary Mathematics Learner’s Book Grade 5', 'Samuel G. Irumbi; Francis Mwangi; Israel Owiti; Obadiah K. Kariuki; Zipporah N. Muli; Washington Mbiruru')
), author_names AS (
  SELECT b.title, trim(author_name.name) AS author_name
  FROM book_rows b
  CROSS JOIN LATERAL unnest(string_to_array(b.authors, ';')) AS author_name(name)
)
INSERT INTO public.title_authors (title_id, author_id)
SELECT title.id, author.id
FROM author_names
JOIN public.titles title ON lower(title.title) = lower(author_names.title) AND title.deleted_at IS NULL
JOIN public.authors author ON lower(author.name) = lower(author_names.author_name) AND author.deleted_at IS NULL
ON CONFLICT DO NOTHING;
