import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Configure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY as Edge Function secrets.
Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );
  const tables = ['locacoes', 'cadastroClientes', 'historicos', 'perfis', 'manutencoes', 'financeiro'];
  const backup: Record<string, unknown> = { versao: 6, geradoEm: new Date().toISOString() };
  for (const table of tables) {
    const { data, error } = await supabase.from(table).select('*');
    if (error) return Response.json({ error: `Falha em ${table}: ${error.message}` }, { status: 500 });
    backup[table] = data ?? [];
  }
  const path = `${new Date().toISOString().slice(0, 10)}/backup-${Date.now()}.json`;
  const blob = new Blob([JSON.stringify(backup)], { type: 'application/json' });
  const { error } = await supabase.storage.from('backups').upload(path, blob, { upsert: true });
  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ ok: true, path });
});
