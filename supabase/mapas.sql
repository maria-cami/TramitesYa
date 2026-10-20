-- ============================================================================
-- TrámitesYa — Mapas: coordenadas de recogida y entrega del pedido
-- Ejecutar en Supabase > SQL Editor > Run. Se puede repetir.
-- Las direcciones de texto siguen siendo las de siempre; esto solo agrega las
-- coordenadas (opcionales) para dibujar el mapa y la ruta.
-- ============================================================================

alter table public.pedidos
  add column if not exists recogida_lat double precision,
  add column if not exists recogida_lng double precision,
  add column if not exists entrega_lat  double precision,
  add column if not exists entrega_lng  double precision;

-- El usuario guarda las coordenadas de SU pedido (la tabla no es editable desde la app).
create or replace function public.guardar_coordenadas_pedido(
  p_pedido_id     uuid,
  p_recogida_lat  double precision,
  p_recogida_lng  double precision,
  p_entrega_lat   double precision,
  p_entrega_lng   double precision
)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_recogida_lat is null or p_recogida_lng is null
     or p_entrega_lat is null or p_entrega_lng is null
     or p_recogida_lat not between -90 and 90 or p_entrega_lat not between -90 and 90
     or p_recogida_lng not between -180 and 180 or p_entrega_lng not between -180 and 180 then
    raise exception 'Coordenadas inválidas';
  end if;

  update public.pedidos
     set recogida_lat = p_recogida_lat, recogida_lng = p_recogida_lng,
         entrega_lat  = p_entrega_lat,  entrega_lng  = p_entrega_lng
   where id = p_pedido_id and usuario_id = auth.uid();

  if not found then
    raise exception 'Pedido no encontrado';
  end if;
end $$;

revoke execute on function public.guardar_coordenadas_pedido(uuid, double precision, double precision, double precision, double precision) from public, anon;
grant  execute on function public.guardar_coordenadas_pedido(uuid, double precision, double precision, double precision, double precision) to authenticated;
