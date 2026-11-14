import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export async function requireLibrarian(
  request: Request,
  corsHeaders: Record<string, string>
) {
  const jsonResponse = (message: string, status: number) =>
    new Response(JSON.stringify({ error: message }), {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  const token = request.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1]
  if (!token) return jsonResponse('Sign in with a librarian account to continue.', 401)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceKey) {
    console.error('Librarian authorization is missing Supabase server configuration.')
    return jsonResponse('The server is not configured to authorize this request.', 500)
  }

  const supabase = createClient(supabaseUrl, serviceKey)
  const { data: { user }, error: userError } = await supabase.auth.getUser(token)
  if (userError || !user) return jsonResponse('Your session is invalid or has expired.', 401)

  const { data: profile, error: profileError } = await supabase
    .from('users_profile')
    .select('role, active')
    .eq('id', user.id)
    .maybeSingle()

  if (profileError) {
    console.error('Could not verify librarian permissions:', profileError.message)
    return jsonResponse('The server could not verify your permissions.', 500)
  }

  if (profile?.role !== 'librarian' || profile.active !== true) {
    return jsonResponse('An active librarian account is required.', 403)
  }

  return { supabase, userId: user.id }
}
