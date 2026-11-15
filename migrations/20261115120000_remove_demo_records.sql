-- Remove demonstration-only activity while keeping the verified KICD book
-- titles, cover images, real grade labels, subjects, and library settings.

BEGIN;

DELETE FROM public.payments payment
USING public.borrowers borrower
WHERE payment.borrower_id = borrower.id
  AND (borrower.borrower_no LIKE 'DEMO-LRN-%' OR borrower.borrower_no = 'DEMO-TCH-001');

DELETE FROM public.payments payment
USING public.charges charge
WHERE payment.charge_id = charge.id
  AND (charge.reason LIKE 'DEMO DATA:%' OR charge.reason LIKE 'DEMO CATALOG:%');

DELETE FROM public.reservations reservation
USING public.borrowers borrower
WHERE reservation.borrower_id = borrower.id
  AND (borrower.borrower_no LIKE 'DEMO-LRN-%' OR borrower.borrower_no = 'DEMO-TCH-001');

DELETE FROM public.reservations reservation
USING public.copies copy
WHERE reservation.ready_copy_id = copy.id
  AND copy.barcode LIKE 'DEMO-CBE-%';

DELETE FROM public.charges charge
USING public.borrowers borrower
WHERE charge.borrower_id = borrower.id
  AND (borrower.borrower_no LIKE 'DEMO-LRN-%' OR borrower.borrower_no = 'DEMO-TCH-001');

DELETE FROM public.charges charge
USING public.issues issue
JOIN public.copies copy ON copy.id = issue.copy_id
WHERE charge.issue_id = issue.id AND copy.barcode LIKE 'DEMO-CBE-%';

DELETE FROM public.charges
WHERE reason LIKE 'DEMO DATA:%' OR reason LIKE 'DEMO CATALOG:%';

DELETE FROM public.notifications notification
USING public.borrowers borrower
WHERE notification.borrower_id = borrower.id
  AND (borrower.borrower_no LIKE 'DEMO-LRN-%' OR borrower.borrower_no = 'DEMO-TCH-001');

DELETE FROM public.notifications
WHERE recipient = 'DEMO DATA'
   OR subject = 'Sample library notice'
   OR body LIKE '%for the demonstration%';

DELETE FROM public.issues issue
USING public.borrowers borrower
WHERE issue.borrower_id = borrower.id
  AND (borrower.borrower_no LIKE 'DEMO-LRN-%' OR borrower.borrower_no = 'DEMO-TCH-001');

DELETE FROM public.issues issue
USING public.copies copy
WHERE issue.copy_id = copy.id
  AND copy.barcode LIKE 'DEMO-CBE-%';

UPDATE public.users_profile profile
SET borrower_id = NULL
WHERE profile.borrower_id IN (
  SELECT id FROM public.borrowers
  WHERE borrower_no LIKE 'DEMO-LRN-%' OR borrower_no = 'DEMO-TCH-001'
);

DELETE FROM public.copies
WHERE barcode LIKE 'DEMO-CBE-%';

DELETE FROM public.borrowers
WHERE borrower_no LIKE 'DEMO-LRN-%'
   OR borrower_no = 'DEMO-TCH-001';

UPDATE public.titles
SET description = replace(
      replace(description, 'DEMO CATALOG RECORD. ', ''),
      '. Thumbnail is illustrative demo artwork, not the publisher’s original cover.',
      '.'
    ),
    tags = array_remove(tags, 'demo'),
    updated_at = now()
WHERE description LIKE 'DEMO CATALOG RECORD%'
   OR 'demo' = ANY(tags);

UPDATE public.classes
SET stream = NULL, updated_at = now()
WHERE name ~ '^Grade [1-9]$' AND stream = 'Demo' AND deleted_at IS NULL;

COMMIT;
