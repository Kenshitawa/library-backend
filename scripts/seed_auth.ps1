# TEST DATA: Creates test auth users for local development
# Run after: supabase db reset

param(
    [string]$SupabaseUrl = "http://127.0.0.1:54342",
    [string]$ServiceKey = $env:SUPABASE_SERVICE_ROLE_KEY,
    [string]$DbUrl = "postgresql://postgres:postgres@localhost:54343/postgres"
)

if (-not $ServiceKey) {
    Write-Error "SUPABASE_SERVICE_ROLE_KEY not set"
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $ServiceKey"
    "Content-Type" = "application/json"
}

Write-Host "Creating librarian user..."
$libResponse = Invoke-RestMethod -Uri "$SupabaseUrl/auth/v1/admin/users" -Method POST -Headers $headers -Body '{"email":"librarian@library.test","password":"TestLibrarian123!","email_confirm":true}'
$librarianId = $libResponse.id

Write-Host "Creating teacher user..."
$tchResponse = Invoke-RestMethod -Uri "$SupabaseUrl/auth/v1/admin/users" -Method POST -Headers $headers -Body '{"email":"teacher@library.test","password":"TestTeacher123!","email_confirm":true}'
$teacherId = $tchResponse.id

Write-Host "Librarian ID: $librarianId"
Write-Host "Teacher ID: $teacherId"

$sql = @"
INSERT INTO public.users_profile (id, name, email, role, active, borrower_id) VALUES
  ('$librarianId', 'TEST DATA: Head Librarian', 'librarian@library.test', 'librarian', true, null),
  ('$teacherId', 'TEST DATA: Prof James Molefe', 'teacher@library.test', 'teacher', true, '00000000-0000-0001-0000-000000000006')
ON CONFLICT (id) DO NOTHING;
"@

$sql | psql $DbUrl
Write-Host "Done! Test accounts created."
