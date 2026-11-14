#!/bin/bash
# TEST DATA: Creates test auth users for local development
# Run after: supabase db reset
# Librarian: librarian@library.test / TestLibrarian123!
# Teacher: teacher@library.test / TestTeacher123!

SUPABASE_URL="${VITE_SUPABASE_URL:-http://127.0.0.1:54342}"
SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

if [ -z "$SERVICE_KEY" ]; then
  echo "Error: SUPABASE_SERVICE_ROLE_KEY not set. Load from .env.local"
  exit 1
fi

echo "Creating librarian user..."
LIBRARIAN_ID=$(curl -s -X POST "$SUPABASE_URL/auth/v1/admin/users" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"librarian@library.test","password":"TestLibrarian123!","email_confirm":true}' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

echo "Librarian ID: $LIBRARIAN_ID"

echo "Creating teacher user..."
TEACHER_ID=$(curl -s -X POST "$SUPABASE_URL/auth/v1/admin/users" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"teacher@library.test","password":"TestTeacher123!","email_confirm":true}' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

echo "Teacher ID: $TEACHER_ID"

# Insert users_profile rows
psql "${DATABASE_URL:-postgresql://postgres:postgres@localhost:54343/postgres}" <<SQL
INSERT INTO public.users_profile (id, name, email, role, active, borrower_id) VALUES
  ('$LIBRARIAN_ID', 'TEST DATA: Head Librarian', 'librarian@library.test', 'librarian', true, null),
  ('$TEACHER_ID', 'TEST DATA: Prof James Molefe', 'teacher@library.test', 'teacher', true, '00000000-0000-0001-0000-000000000006')
ON CONFLICT (id) DO NOTHING;
SQL

echo "Done! Test accounts created."
echo "  Librarian: librarian@library.test / TestLibrarian123!"
echo "  Teacher: teacher@library.test / TestTeacher123!"
