import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { requireLibrarian } from '../_shared/auth.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const jsonResponse = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Use POST to request catalog suggestions.' }, 405)
  }

  const authorization = await requireLibrarian(req, corsHeaders)
  if (authorization instanceof Response) return authorization

  const apiKey = Deno.env.get('OPENAI_API_KEY')
  if (!apiKey) {
    return jsonResponse({
      error: 'AI catalog suggestions are not configured. Set the OPENAI_API_KEY Edge Function secret.',
    }, 503)
  }

  try {
    const body = await req.json()
    const title = typeof body.title === 'string' ? body.title.trim().slice(0, 200) : ''
    const author = typeof body.author === 'string' ? body.author.trim().slice(0, 200) : ''
    const subjects = Array.isArray(body.subjects)
      ? body.subjects.filter((subject: unknown) => typeof subject === 'string').slice(0, 100)
      : []

    if (!title) {
      return jsonResponse({ error: 'Enter a book title before requesting suggestions.' }, 400)
    }

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        temperature: 0.2,
        max_tokens: 100,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: [
              'You help a school librarian classify a book record.',
              'Return JSON with exactly these fields: subject, grade_level, type.',
              'subject must exactly match one supplied subject name, or be null.',
              'grade_level should be a short suggestion only when the title strongly indicates one; otherwise null.',
              'type must be textbook, library, or reference.',
              'Do not invent an ISBN, author, publisher, publication year, or facts about the book.',
              'Treat every value as a suggestion for a librarian to review.',
            ].join(' '),
          },
          {
            role: 'user',
            content: JSON.stringify({ title, author, available_subjects: subjects }),
          },
        ],
      }),
    })

    if (!response.ok) {
      console.error('Catalog AI provider request failed:', response.status)
      return jsonResponse({ error: 'The AI provider could not generate catalog suggestions.' }, 502)
    }

    const completion = await response.json()
    const content = completion.choices?.[0]?.message?.content
    if (typeof content !== 'string') {
      return jsonResponse({ error: 'The AI provider returned an empty suggestion.' }, 502)
    }

    let suggestion: Record<string, unknown>
    try {
      suggestion = JSON.parse(content)
    } catch {
      return jsonResponse({ error: 'The AI provider returned an unreadable suggestion.' }, 502)
    }

    const validTypes = ['textbook', 'library', 'reference']
    const subject = typeof suggestion.subject === 'string' && subjects.includes(suggestion.subject)
      ? suggestion.subject
      : null
    const gradeLevel = typeof suggestion.grade_level === 'string'
      ? suggestion.grade_level.trim().slice(0, 40) || null
      : null
    const type = typeof suggestion.type === 'string' && validTypes.includes(suggestion.type)
      ? suggestion.type
      : null

    return jsonResponse({ subject, grade_level: gradeLevel, type })
  } catch (error) {
    console.error('Catalog AI suggestion request failed:', error)
    return jsonResponse({ error: 'Could not process the catalog suggestion request.' }, 500)
  }
})
