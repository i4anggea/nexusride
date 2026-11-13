import { createClient } from 'npm:@supabase/supabase-js@2'

type Incident = {
  id: string
  user_id: string
  latitude: number
  longitude: number
  g_force: number | null
  status: string
}

type EmergencyContact = {
  id: string
  name: string
  phone: string
  notify_sms: boolean
}

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return json({ error: 'Método no permitido' }, 405)

  try {
    const authorization = request.headers.get('Authorization')
    const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1]
    if (!token) return json({ error: 'Se requiere iniciar sesión' }, 401)

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ??
      Deno.env.get('SUPABASE_PUBLISHABLE_KEY')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      console.error('Faltan variables de entorno de Supabase')
      return json({ error: 'Servicio de emergencia no configurado' }, 500)
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    })
    const { data: userData, error: authError } = await userClient.auth.getUser(token)
    if (authError || !userData.user) return json({ error: 'Sesión no válida' }, 401)

    const body = await request.json().catch(() => null)
    const incidentId = body?.incident_id
    if (typeof incidentId !== 'string' || !/^[0-9a-f-]{36}$/i.test(incidentId)) {
      return json({ error: 'incident_id no válido' }, 400)
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: incidentData, error: incidentError } = await admin
      .from('incidents')
      .select('id, user_id, latitude, longitude, g_force, status')
      .eq('id', incidentId)
      .maybeSingle()
    const incident = incidentData as Incident | null

    if (incidentError || !incident || incident.user_id !== userData.user.id) {
      return json({ error: 'Incidente no encontrado' }, 404)
    }
    if (incident.status === 'cancelled') {
      return json({ error: 'El incidente fue cancelado' }, 409)
    }
    if (incident.status === 'confirmed') {
      return json({ ok: true, already_processed: true })
    }

    const { data: contactsData, error: contactsError } = await admin
      .from('emergency_contacts')
      .select('id, name, phone, notify_sms')
      .eq('user_id', incident.user_id)
      .eq('notify_sms', true)
    if (contactsError) throw contactsError
    const contacts = (contactsData ?? []) as EmergencyContact[]
    if (contacts.length === 0) {
      return json({ error: 'No hay contactos con SMS habilitado' }, 422)
    }

    const accountSid = Deno.env.get('TWILIO_ACCOUNT_SID')
    const authToken = Deno.env.get('TWILIO_AUTH_TOKEN')
    const fromNumber = Deno.env.get('TWILIO_FROM_NUMBER')
    if (!accountSid || !authToken || !fromNumber) {
      console.error('Faltan credenciales de Twilio')
      return json({ error: 'Servicio SMS no configurado' }, 500)
    }

    const { data: profile } = await admin
      .from('profiles')
      .select('full_name')
      .eq('id', incident.user_id)
      .maybeSingle()
    const mapUrl = `https://maps.google.com/?q=${incident.latitude},${incident.longitude}`
    const message = [
      `EMERGENCIA: ${profile?.full_name ?? 'Tu contacto'} pudo haber tenido un accidente.`,
      `Fuerza detectada: ${incident.g_force?.toFixed(1) ?? '?'} G`,
      `Ubicación: ${mapUrl}`,
    ].join('\n')

    const results = await Promise.all(contacts.map(async (contact) => {
      let sent = false
      try {
        const form = new URLSearchParams({
          To: contact.phone,
          From: fromNumber,
          Body: message,
        })
        const response = await fetch(
          `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
            },
            body: form.toString(),
          },
        )
        sent = response.ok
      } catch (error) {
        console.error('Falló el envío SMS', error)
      }

      const { error: notificationError } = await admin
        .from('incident_notifications')
        .insert({
          incident_id: incident.id,
          contact_id: contact.id,
          method: 'sms',
          status: sent ? 'sent' : 'failed',
        })
      if (notificationError) throw notificationError
      return sent
    }))

    const { error: updateError } = await admin
      .from('incidents')
      .update({ status: 'confirmed', notified_at: new Date().toISOString() })
      .eq('id', incident.id)
    if (updateError) throw updateError

    const sent = results.filter(Boolean).length
    return json({ ok: true, sent, failed: results.length - sent })
  } catch (error) {
    console.error('Error procesando emergencia', error)
    return json({ error: 'No se pudo procesar la emergencia' }, 500)
  }
})
