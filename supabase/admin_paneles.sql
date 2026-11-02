-- TrámitesYa — Paneles del administrador: pedidos, personas y trámites.
-- Todas validan que quien llama sea admin (mi_rol()).

create or replace function public.admin_pedidos(p_estado text default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if public.mi_rol() is distinct from 'admin' then
    raise exception 'Solo el administrador puede ver esto';
  end if;
  return coalesce((
    select jsonb_agg(x) from (
      select p.id, p.codigo, p.estado::text as estado, p.created_at, t.valor,
             c.nombre as tramite,
             pu.nombre_completo as usuario,
             ph.nombre_completo as ayudante,
             p.recogida_direccion, p.entrega_direccion, p.motivo_cancelacion
        from public.pedidos p
        join public.tarifas t on t.id = p.tarifa_id
        join public.catalogo_tramites c on c.id = p.tramite_id
        left join public.profiles pu on pu.id = p.usuario_id
        left join public.profiles ph on ph.id = p.ayudante_id
       where p_estado is null or p_estado = '' or p.estado::text = p_estado
       order by p.created_at desc
       limit 200
    ) x
  ), '[]'::jsonb);
end $$;

create or replace function public.admin_personas(p_rol text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if public.mi_rol() is distinct from 'admin' then
    raise exception 'Solo el administrador puede ver esto';
  end if;
  if p_rol not in ('usuario', 'ayudante') then
    raise exception 'Rol no válido';
  end if;
  return coalesce((
    select jsonb_agg(x) from (
      select pr.id, pr.nombre_completo as nombre, pr.telefono, u.email,
             pr.bloqueado, pr.created_at,
             (select count(*) from public.pedidos pe
               where case when pr.role = 'ayudante'
                          then pe.ayudante_id = pr.id and pe.estado = 'entregado'
                          else pe.usuario_id = pr.id end) as pedidos
        from public.profiles pr
        join auth.users u on u.id = pr.id
       where pr.role = p_rol::user_role
       order by pr.created_at desc
       limit 300
    ) x
  ), '[]'::jsonb);
end $$;

create or replace function public.admin_bloquear(p_id uuid, p_bloqueado boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.mi_rol() is distinct from 'admin' then
    raise exception 'Solo el administrador puede hacer esto';
  end if;
  if p_id = auth.uid() then
    raise exception 'No puedes bloquear tu propia cuenta';
  end if;
  update public.profiles set bloqueado = p_bloqueado
   where id = p_id and role <> 'admin';
  if not found then
    raise exception 'No se puede cambiar el estado de esa cuenta';
  end if;
end $$;

create or replace function public.admin_catalogo()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if public.mi_rol() is distinct from 'admin' then
    raise exception 'Solo el administrador puede ver esto';
  end if;
  return coalesce((
    select jsonb_agg(x) from (
      select c.id, c.nombre, c.categoria, c.activo,
             (select t.valor from public.tarifas t
               where t.tramite_id = c.id
               order by t.vigente_desde desc limit 1) as valor
        from public.catalogo_tramites c
       order by c.nombre
    ) x
  ), '[]'::jsonb);
end $$;

-- Crea (p_id null) o edita un trámite. Si cambia el valor se agrega una tarifa nueva:
-- los pedidos anteriores conservan el precio con el que se crearon.
create or replace function public.admin_guardar_tramite(
  p_id uuid, p_nombre text, p_categoria text, p_valor numeric, p_activo boolean
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid := p_id;
  v_nombre text := btrim(coalesce(p_nombre, ''));
  v_cat text := nullif(btrim(coalesce(p_categoria, '')), '');
  v_actual numeric;
begin
  if public.mi_rol() is distinct from 'admin' then
    raise exception 'Solo el administrador puede hacer esto';
  end if;
  if char_length(v_nombre) not between 1 and 60 then
    raise exception 'El nombre debe tener entre 1 y 60 caracteres';
  end if;
  if p_valor is null or p_valor <= 0 then
    raise exception 'El valor debe ser mayor que cero';
  end if;

  begin
    if v_id is null then
      insert into public.catalogo_tramites (nombre, categoria, activo)
      values (v_nombre, v_cat, coalesce(p_activo, true))
      returning id into v_id;
    else
      update public.catalogo_tramites
         set nombre = v_nombre, categoria = v_cat, activo = coalesce(p_activo, true)
       where id = v_id;
      if not found then
        raise exception 'El trámite no existe';
      end if;
    end if;
  exception when unique_violation then
    raise exception 'Ya existe un trámite con ese nombre';
  end;

  select valor into v_actual from public.tarifas
   where tramite_id = v_id order by vigente_desde desc limit 1;
  if v_actual is distinct from p_valor then
    insert into public.tarifas (tramite_id, valor) values (v_id, p_valor);
  end if;
end $$;

revoke execute on function public.admin_pedidos(text) from public, anon;
revoke execute on function public.admin_personas(text) from public, anon;
revoke execute on function public.admin_bloquear(uuid, boolean) from public, anon;
revoke execute on function public.admin_catalogo() from public, anon;
revoke execute on function public.admin_guardar_tramite(uuid, text, text, numeric, boolean) from public, anon;
grant execute on function public.admin_pedidos(text) to authenticated;
grant execute on function public.admin_personas(text) to authenticated;
grant execute on function public.admin_bloquear(uuid, boolean) to authenticated;
grant execute on function public.admin_catalogo() to authenticated;
grant execute on function public.admin_guardar_tramite(uuid, text, text, numeric, boolean) to authenticated;