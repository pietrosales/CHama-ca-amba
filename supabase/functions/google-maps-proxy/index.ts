// Keeps the Google Cloud API key server-side. Enable Geocoding/Routes APIs and
// set GOOGLE_MAPS_API_KEY as an Edge Function secret.
Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const { address, origin, destination, waypoints = [] } = await req.json();
  const key = Deno.env.get('GOOGLE_MAPS_API_KEY');
  if (!key) return Response.json({ error: 'GOOGLE_MAPS_API_KEY não configurada' }, { status: 500 });
  const target = origin && destination ? 'https://routes.googleapis.com/directions/v2:computeRoutes' : 'https://maps.googleapis.com/maps/api/geocode/json';
  const response = origin && destination
    ? await fetch(target, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': key, 'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.legs' }, body: JSON.stringify({ origin: { address: origin }, destination: { address: destination }, intermediates: waypoints.map((x: string) => ({ address: x })), travelMode: 'DRIVE' }) })
    : await fetch(`${target}?address=${encodeURIComponent(address || '')}&key=${encodeURIComponent(key)}`);
  return new Response(await response.text(), { status: response.status, headers: { 'Content-Type': 'application/json' } });
});
