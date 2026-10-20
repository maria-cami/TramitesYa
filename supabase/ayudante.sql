-- ============================================================================
-- TrámitesYa — Fase 2: app del Ayudante
-- Ejecutar DESPUÉS de schema.sql (Supabase > SQL Editor > Run). Se puede repetir.
-- Añade: política para ver pedidos disponibles + funciones aceptar / soltar /
-- recoger / entregar. El pago al ayudante es SIMULADO (80 % de la tarifa; el
-- 20 % restante es la comisión de ejemplo de la plataforma).
-- ============================================================================

-- Un ayudante ve los pedidos que están buscando ayudante (además de los suyos,
-- que ya cubre "ayudante_ve_pedidos_asignados").
drop policy if exists "ayudante_ve_disponibles" on public.pedidos;
create policy "ayudante_ve_disponibles" on public.pedidos for select
  using (estado = 'buscando_ayudante' and public.mi_rol() = 'ayudante');

-- ---------- Aceptar ----------
create or replace function public.aceptar_pedido(p_pedido_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_ped public.pedidos;
begin
  if public.mi_rol() is distinct from 'ayudante' then
    raise exception 'Solo los ayudantes pueden aceptar pedidos';
  end if;
  if exists (select 1 from public.profiles where id = v_uid and bloqueado) then
    raise exception 'Tu cuenta está restringida. Contacta a soporte.';
  end if;

  select * into v_ped from public.pedidos where id = p_pedido_id for update;
  if not found or v_ped.estado <> 'buscando_ayudante' or v_ped.ayudante_id is not null then
    raise exception 'Este pedido ya fue tomado o no está disponible';
  end if;
  if v_ped.usuario_id = v_uid then
    raise exception 'No puedes aceptar tu propio pedido';
  end if;
  if (select count(*) from public.pedidos
       where ayudante_id = v_uid and estado in ('asignado', 'recogido')) >= 3 then
    raise exception 'Ya tienes 3 servicios activos. Termina uno para aceptar otro';
  end if;

  update public.pedidos
     set estado = 'asignado', ayudante_id = v_uid
   where id = p_pedido_id;
end $$;

-- ---------- Soltar (devuelve el pedido a la bolsa) ----------
create or replace function public.soltar_pedido(p_pedido_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  update public.pedidos
     set estado = 'buscando_ayudante', ayudante_id = null
   where id = p_pedido_id and ayudante_id = v_uid and estado = 'asignado';
  if not found then
    raise exception 'No puedes soltar este pedido';
  end if;
end $$;

-- ---------- Recogido ----------
create or replace function public.marcar_recogido(p_pedido_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  update public.pedidos
     set estado = 'recogido'
   where id = p_pedido_id and ayudante_id = v_uid and estado = 'asignado';
  if not found then
    raise exception 'Este pedido no se puede marcar como recogido';
  end if;
end $$;

-- ---------- Entregado (+ pago simulado al ayudante) ----------
create or replace function public.marcar_entregado(p_pedido_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_ped   public.pedidos;
  v_valor numeric(12,2);
  v_pago  numeric(12,2);
begin
  select * into v_ped from public.pedidos
   where id = p_pedido_id and ayudante_id = v_uid and estado = 'recogido'
   for update;
  if not found then
    raise exception 'Este pedido no se puede marcar como entregado';
  end if;

  update public.pedidos set estado = 'entregado' where id = p_pedido_id;

  select valor into v_valor from public.tarifas where id = v_ped.tarifa_id;
  v_pago := round(v_valor * 0.80, 2);

  insert into public.transacciones
    (profile_id, pedido_id, tipo, estado, monto, idempotency_key, respuesta_proveedor)
  values
    (v_uid, p_pedido_id, 'pago_ayudante', 'completed', v_pago, gen_random_uuid(),
     jsonb_build_object('proveedor', 'simulado', 'comision', 0.20));

  insert into public.billeteras (profile_id, saldo) values (v_uid, v_pago)
  on conflict (profile_id)
  do update set saldo = public.billeteras.saldo + excluded.saldo, updated_at = now();
end $$;

revoke execute on function public.aceptar_pedido(uuid)   from public, anon;
revoke execute on function public.soltar_pedido(uuid)    from public, anon;
revoke execute on function public.marcar_recogido(uuid)  from public, anon;
revoke execute on function public.marcar_entregado(uuid) from public, anon;
grant execute on function public.aceptar_pedido(uuid)   to authenticated;
grant execute on function public.soltar_pedido(uuid)    to authenticated;
grant execute on function public.marcar_recogido(uuid)  to authenticated;
grant execute on function public.marcar_entregado(uuid) to authenticated;

-- ============================================================================
-- Convertir una cuenta en ayudante (SOLO desde el SQL Editor; la app no puede
-- cambiar roles). Cambia el correo y ejecuta esta línea por separado:
--
--   update public.profiles set role = 'ayudante'
--    where id = (select id from auth.users where email = 'CORREO_DEL_AYUDANTE');
-- ============================================================================
