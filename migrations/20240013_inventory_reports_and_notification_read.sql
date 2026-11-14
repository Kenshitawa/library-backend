CREATE TABLE public.inventory_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  generated_at timestamptz NOT NULL DEFAULT now(),
  row_count integer NOT NULL DEFAULT 0,
  snapshot jsonb NOT NULL
);

ALTER TABLE public.inventory_reports ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.inventory_reports TO authenticated;
CREATE POLICY "inventory_reports_librarian_read"
  ON public.inventory_reports FOR SELECT
  USING (public.get_user_role() = 'librarian');

ALTER TABLE public.notifications
  ADD COLUMN read_at timestamptz,
  ADD COLUMN report_id uuid REFERENCES public.inventory_reports(id);

CREATE OR REPLACE FUNCTION public.create_inventory_report()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_report_id uuid;
  v_library_name text;
  v_rows jsonb;
  v_row_count integer;
BEGIN
  SELECT name
  INTO v_library_name
  FROM public.library_profile
  ORDER BY created_at
  LIMIT 1;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'barcode', inventory.barcode,
        'title', inventory.title,
        'authors', inventory.authors,
        'isbn10', inventory.isbn10,
        'isbn13', inventory.isbn13,
        'subject', inventory.subject,
        'grade_level', inventory.grade_level,
        'book_type', inventory.book_type,
        'copy_status', inventory.copy_status,
        'condition', inventory.condition,
        'location', inventory.location,
        'call_number', inventory.call_number,
        'acquired_on', inventory.acquired_on,
        'price', inventory.price
      )
      ORDER BY inventory.title, inventory.barcode
    ),
    '[]'::jsonb
  )
  INTO v_rows
  FROM (
    SELECT
      c.barcode,
      t.title,
      COALESCE(author_list.authors, '') AS authors,
      t.isbn10,
      t.isbn13,
      s.name AS subject,
      t.grade_level,
      t.type AS book_type,
      c.status AS copy_status,
      c.condition,
      l.name AS location,
      c.call_number,
      c.acquired_on,
      c.price
    FROM public.copies c
    JOIN public.titles t ON t.id = c.title_id
    LEFT JOIN public.subjects s ON s.id = t.subject_id
    LEFT JOIN public.locations l ON l.id = c.location_id
    LEFT JOIN LATERAL (
      SELECT string_agg(a.name, ', ' ORDER BY a.name) AS authors
      FROM public.title_authors ta
      JOIN public.authors a ON a.id = ta.author_id
      WHERE ta.title_id = t.id
        AND a.deleted_at IS NULL
    ) author_list ON true
    WHERE c.deleted_at IS NULL
      AND t.deleted_at IS NULL
  ) inventory;

  v_row_count := jsonb_array_length(v_rows);

  INSERT INTO public.inventory_reports (row_count, snapshot)
  VALUES (
    v_row_count,
    jsonb_build_object(
      'library_name', COALESCE(v_library_name, 'School Library'),
      'rows', v_rows
    )
  )
  RETURNING id INTO v_report_id;

  INSERT INTO public.notifications (
    type,
    channel,
    subject,
    body,
    report_id,
    status,
    sent_at
  )
  VALUES (
    'monthly_inventory_report',
    'in_app',
    'Monthly inventory report ready',
    format('The monthly inventory snapshot is ready to download. It contains %s copies.', v_row_count),
    v_report_id,
    'sent',
    now()
  );

  RETURN v_report_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_inventory_report() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_inventory_report() TO service_role;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'monthly-library-inventory',
      '0 8 * * *',
      $cron$
        SELECT public.create_inventory_report()
        WHERE NOT EXISTS (
          SELECT 1
          FROM public.inventory_reports
          WHERE generated_at >= now() - interval '30 days'
        );
      $cron$
    );
  END IF;
END $$;
