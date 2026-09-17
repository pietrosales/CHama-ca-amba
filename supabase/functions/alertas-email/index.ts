import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Secrets: RESEND_API_KEY and ALERT_EMAIL_TO. Keep them only in Supabase secrets.
Deno.serve(async (req) => {
  if (req.method !== 'POST') return Response.json({ error: 'Use POST' }, { status: 405 });
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const resendKey = Deno.env.get('RESEND_API_KEY');
  const recipient = Deno.env.get('ALERT_EMAIL_TO');
  if (!resendKey || !recipient) return Response.json({ configured: false, reason: 'Configure RESEND_API_KEY e ALERT_EMAIL_TO' });

  const { data: alertas, error } = await supabase.from('alertas').select('*').eq('status', 'pendente').limit(50);
  if (error) return Response.json({ error: error.message }, { status: 500 });
  let enviados = 0;
  for (const alerta of alertas ?? []) {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${resendKey}` },
      body: JSON.stringify({
        from: 'Chama Caçamba <onboarding@resend.dev>',
        to: [recipient],
        subject: `Alerta Chama Caçamba: ${alerta.tipo ?? 'notificação'}`,
        text: alerta.mensagem ?? 'Nova notificação no sistema.'
      })
    });
    if (response.ok) {
      await supabase.from('alertas').update({ status: 'enviado', enviado_em: new Date().toISOString() }).eq('id', alerta.id);
      enviados++;
    }
  }
  return Response.json({ configured: true, enviados, pendentes: (alertas ?? []).length - enviados });
});
