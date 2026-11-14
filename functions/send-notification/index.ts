import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { requireLibrarian } from '../_shared/auth.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (request.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Use POST to send a notification.' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const authorization = await requireLibrarian(request, corsHeaders)
  if (authorization instanceof Response) return authorization

  return new Response(
    JSON.stringify({
      error: 'Email delivery is not configured. In-app notifications are available in the library system.',
    }),
    {
      status: 503,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  )
})
