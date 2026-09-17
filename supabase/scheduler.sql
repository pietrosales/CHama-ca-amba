-- Agendamentos já aplicados no projeto chama-caçamba.
-- Backup diário às 03:00 UTC e fila de e-mail a cada 5 minutos.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

do $$ begin
  perform cron.unschedule(jobid) from cron.job
  where jobname in ('chama-backup-diario','chama-alertas-email');
exception when undefined_table then null;
end $$;

-- Substitua PUBLISHABLE_KEY_AQUI se for reaplicar em outro projeto.
select cron.schedule('chama-backup-diario','0 3 * * *', $$select net.http_post(url := 'https://kbxothjmdovebvolvckg.supabase.co/functions/v1/backup-diario', headers := jsonb_build_object('Content-Type','application/json','apikey','PUBLISHABLE_KEY_AQUI'), body := '{}'::jsonb);$$);
select cron.schedule('chama-alertas-email','*/5 * * * *', $$select net.http_post(url := 'https://kbxothjmdovebvolvckg.supabase.co/functions/v1/alertas-email', headers := jsonb_build_object('Content-Type','application/json','apikey','PUBLISHABLE_KEY_AQUI'), body := '{}'::jsonb);$$);
