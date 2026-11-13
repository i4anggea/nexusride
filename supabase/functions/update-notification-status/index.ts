const json = (message: string) =>
  new Response(JSON.stringify({ error: message }), {
    status: 410,
    headers: { 'Content-Type': 'application/json' },
  })

Deno.serve((_request: Request) =>
  json('Esta función fue retirada; el estado se actualiza desde el flujo de emergencia.')
)
