import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const isbn = url.searchParams.get('isbn')?.trim().replace(/[-\s]/g, '')

    if (!isbn) {
      return new Response(
        JSON.stringify({ error: 'Missing isbn parameter' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Query Open Library API
    const bibKey = `ISBN:${isbn}`
    const openLibUrl = `https://openlibrary.org/api/books?bibkeys=${encodeURIComponent(bibKey)}&format=json&jscmd=data`

    const response = await fetch(openLibUrl)
    if (!response.ok) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch from Open Library' }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const data = await response.json()
    const bookData = data[bibKey]

    if (!bookData) {
      return new Response(
        JSON.stringify({ error: 'Book not found for ISBN' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const title = bookData.title || ''
    const authors = Array.isArray(bookData.authors)
      ? bookData.authors.map((a: any) => a.name).join(', ')
      : ''
    const publisher = Array.isArray(bookData.publishers) && bookData.publishers.length > 0
      ? bookData.publishers[0].name
      : ''
    const publishDate = bookData.publish_date || ''
    const yearMatch = publishDate.match(/\b(19\d\d|20\d\d)\b/)
    const year = yearMatch ? parseInt(yearMatch[1], 10) : null
    const coverUrl = bookData.cover?.large || bookData.cover?.medium || bookData.cover?.small || null
    const description = typeof bookData.notes === 'string'
      ? bookData.notes
      : (bookData.subtitle || '')

    return new Response(
      JSON.stringify({
        title,
        authors,
        publisher,
        year,
        description,
        cover_url: coverUrl,
        isbn,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || 'Internal Server Error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
