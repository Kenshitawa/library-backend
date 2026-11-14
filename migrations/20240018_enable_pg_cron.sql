-- Enable Supabase Cron and register the jobs that were skipped before pg_cron
-- was installed on the hosted project.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

SELECT cron.schedule(
  'expire-reservations',
  '0 * * * *',
  $cron$
    WITH expired_res AS (
      UPDATE public.reservations
      SET status = 'expired', updated_at = now()
      WHERE status = 'ready' AND pickup_deadline < now()
      RETURNING id, title_id, ready_copy_id
    )
    SELECT public.handle_return_reservations(ready_copy_id)
    FROM expired_res
    WHERE ready_copy_id IS NOT NULL;

    UPDATE public.copies c
    SET status = 'available', updated_at = now()
    WHERE status = 'reserved'
      AND NOT EXISTS (
        SELECT 1 FROM public.reservations r
        WHERE r.ready_copy_id = c.id AND r.status = 'ready'
      );
  $cron$
);

SELECT cron.schedule(
  'queue-reminders',
  '0 7 * * *',
  $cron$
    INSERT INTO public.notifications (borrower_id, type, channel, recipient, subject, body, status)
    SELECT
      i.borrower_id,
      'return_reminder',
      'email',
      COALESCE(b.email, b.guardian_phone),
      'Book due soon: ' || t.title,
      'Your copy of "' || t.title || '" is due on ' || i.due_at::date || '. Please return or renew on time.',
      'pending'
    FROM public.issues i
    JOIN public.borrowers b ON b.id = i.borrower_id
    JOIN public.copies c ON c.id = i.copy_id
    JOIN public.titles t ON t.id = c.title_id
    WHERE i.status = 'open'
      AND i.due_at BETWEEN now() AND now() + interval '3 days'
      AND i.deleted_at IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.borrower_id = i.borrower_id
          AND n.type = 'return_reminder'
          AND DATE(n.created_at) = CURRENT_DATE
      );
  $cron$
);

