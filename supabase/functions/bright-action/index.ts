const json = (message: string) =>
  new Response(JSON.stringify({ error: message }), {
    status: 410,
    headers: { 'Content-Type': 'application/json' },
  })

Deno.serve((_request: Request) =>
  json('Esta función fue retirada. Usa notify-emergency para alertas de emergencia.')
)
