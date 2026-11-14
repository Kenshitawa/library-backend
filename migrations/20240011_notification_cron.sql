-- Migration: 20240011_notification_cron.sql
-- pg_cron job for automated due-soon notification queueing

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule('queue-reminders', '0 7 * * *', $cron$
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
        -- Don't duplicate: not already notified today for this issue
        AND NOT EXISTS (
          SELECT 1 FROM public.notifications n 
          WHERE n.borrower_id = i.borrower_id 
            AND n.type = 'return_reminder'
            AND DATE(n.created_at) = CURRENT_DATE
        );
    $cron$);
  END IF;
END $$;
