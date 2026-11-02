-- TrámitesYa — Planes mensuales. La app no retiene dinero: el servicio se paga
-- directo al ayudante y la app cobra solo los planes.

-- ---------- Planes y suscripciones ----------
create table if not exists public.planes (
  id           text primary key,
  rol          user_role not null,
  nombre       text not null,
  descripcion  text,
  precio       numeric(12,2) not null check (precio >= 0),
  pedidos_mes  int check (pedidos_mes is null or pedidos_mes > 0), -- null = ilimitado
  orden        int not null default 0,
  activo       boolean not null default true
);

insert into public.planes (id, rol, nombre, descripcion, precio, pedidos_mes, orden) values
  ('usuario_gratis', 'usuario',  'Gratis',   '2 pedidos al mes',                           0,     2,    1),
  ('usuario_plus',   'usuario',  'Plus',     'Pedidos ilimitados',                          9900,  null, 2),
  ('ayudante',       'ayudante', 'Ayudante', 'Acepta servicios sin límite durante el mes',  29900, null, 1)
on conflict (id) do nothing;

create table if not exists public.suscripciones (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  plan_id     text not null references public.planes (id),
  inicia      timestamptz not null default now(),
  vence       timestamptz not null,
  origen      text not null default 'simulado',   -- simulado | pasarela | admin
  created_at  timestamptz not null default now()
);
create index if not exists idx_suscripciones_perfil on public.suscripciones (profile_id, vence desc);

alter table public.planes enable row level security;
alter table public.suscripciones enable row level security;

drop policy if exists "ver_planes_activos" on public.planes;
create policy "ver_planes_activos" on public.planes for select
  to authenticated using (activo);
drop policy if exists "ver_propia_suscripcion" on public.suscripciones;
create policy "ver_propia_suscripcion" on public.suscripciones for select
  using (profile_id = auth.uid());
drop policy if exists "admin_ve_suscripciones" on public.suscripciones;
create policy "admin_ve_suscripciones" on public.suscripciones for select
  using (public.mi_rol() = 'admin');

-- ---------- Estado del plan de una persona ----------
create or replace function public.estado_plan(p_uid uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_rol         user_role;
  v_creado      timestamptz;
  v_plan_id     text;
  v_plan        public.planes;
  v_vence       timestamptz;
  v_prueba      boolean := false;
  v_inicio_mes  timestamptz := (date_trunc('month', now() at time zone 'America/Bogota')) at time zone 'America/Bogota';
  v_usados      int := 0;
begin
  select role, created_at into v_rol, v_creado from public.profiles where id = p_uid;
  if v_rol is null then
    return null;
  end if;

  select s.plan_id, s.vence into v_plan_id, v_vence
    from public.suscripciones s
    join public.planes p on p.id = s.plan_id
   where s.profile_id = p_uid and s.vence > now() and p.rol = v_rol
   order by s.vence desc
   limit 1;

  if v_plan_id is not null then
    select * into v_plan from public.planes where id = v_plan_id;
  elsif v_rol = 'usuario' then
    select * into v_plan from public.planes where id = 'usuario_gratis';
  elsif v_rol = 'ayudante' and v_creado + interval '30 days' > now() then
    v_prueba := true;
    v_vence := v_creado + interval '30 days';
  end if;

  if v_rol = 'usuario' then
    select count(*) into v_usados from public.pedidos
     where usuario_id = p_uid and created_at >= v_inicio_mes and estado <> 'cancelado';
  end if;

  return jsonb_build_object(
    'rol',            v_rol::text,
    'plan_id',        case when v_prueba then 'prueba' else v_plan.id end,
    'nombre',         case when v_prueba then 'Prueba gratuita' else v_plan.nombre end,
    'activo',         v_prueba or v_plan.id is not null,
    'prueba',         v_prueba,
    'vence',          v_vence,
    'pedidos_limite', v_plan.pedidos_mes,
    'pedidos_usados', v_usados
  );
end $$;

revoke execute on function public.estado_plan(uuid) from public, anon, authenticated;

create or replace function public.mi_plan()
returns jsonb
language sql stable security definer set search_path = public as $$
  select public.estado_plan(auth.uid());
$$;
revoke execute on function public.mi_plan() from public, anon;
grant execute on function public.mi_plan() to authenticated;

-- !!! SOLO DESARROLLO / SANDBOX !!!
-- Activa un plan 30 días sin cobrar. Se reemplaza por el checkout de la pasarela.
create or replace function public.activar_plan_simulado(p_plan_id text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_plan public.planes;
begin
  select * into v_plan from public.planes where id = p_plan_id and activo;
  if not found then
    raise exception 'Ese plan no está disponible';
  end if;
  if v_plan.rol is distinct from public.mi_rol() then
    raise exception 'Ese plan no es para tu tipo de cuenta';
  end if;

  update public.suscripciones set vence = now()
   where profile_id = v_uid and vence > now();

  if v_plan.precio > 0 then
    insert into public.suscripciones (profile_id, plan_id, vence, origen)
    values (v_uid, p_plan_id, now() + interval '30 days', 'simulado');
  end if;
end $$;
revoke execute on function public.activar_plan_simulado(text) from public, anon;
grant execute on function public.activar_plan_simulado(text) to authenticated;

-- ---------- Pedidos sin pago dentro de la app ----------
alter table public.pedidos add column if not exists idempotency_key uuid;
create unique index if not exists uq_pedidos_idem
  on public.pedidos (usuario_id, idempotency_key) where idempotency_key is not null;

-- Pedidos viejos que nunca se pagaron: se cancelan para que no queden colgados.
update public.pedidos
   set estado = 'cancelado', motivo_cancelacion = 'Pedido sin confirmar'
 where estado = 'pendiente_pago';

drop function if exists public.crear_pedido(uuid, text, text, text, text, text, text, uuid, text, numeric);

create or replace function public.crear_pedido(
  p_tramite_id           uuid,
  p_descripcion          text,
  p_notas                text,
  p_recogida_direccion   text,
  p_recogida_referencia  text,
  p_entrega_direccion    text,
  p_entrega_referencia   text,
  p_idempotency_key      uuid,
  p_titulo               text default null,
  p_valor                numeric default null
) returns public.pedidos
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_tramite public.catalogo_tramites;
  v_tarifa  public.tarifas;
  v_pedido  public.pedidos;
  v_titulo  text;
  v_holder  uuid;
  v_plan    jsonb;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '28000';
  end if;
  if exists (select 1 from public.profiles where id = v_uid and bloqueado) then
    raise exception 'Tu cuenta está restringida. Contacta a soporte.';
  end if;

  -- Reintento con la misma clave: devuelve el pedido ya creado.
  select * into v_pedido from public.pedidos
   where usuario_id = v_uid and idempotency_key = p_idempotency_key;
  if found then
    return v_pedido;
  end if;

  -- Límite de pedidos del plan.
  v_plan := public.estado_plan(v_uid);
  if (v_plan ->> 'pedidos_limite') is not null
     and (v_plan ->> 'pedidos_usados')::int >= (v_plan ->> 'pedidos_limite')::int then
    raise exception 'Llegaste al límite de % pedidos de tu plan este mes. Mejora tu plan para pedir más',
      v_plan ->> 'pedidos_limite';
  end if;

  select * into v_tramite from public.catalogo_tramites where id = p_tramite_id and activo;
  if not found then
    raise exception 'El trámite seleccionado no está disponible';
  end if;

  if v_tramite.personalizado then
    v_titulo := btrim(coalesce(p_titulo, ''));
    if char_length(v_titulo) not between 3 and 60 then
      raise exception 'Escribe qué servicio necesitas (entre 3 y 60 caracteres)';
    end if;
    if p_valor is null or p_valor < 5000 then
      raise exception 'El valor mínimo es $5.000';
    end if;
    if p_valor > 10000000 then
      raise exception 'El valor máximo es $10.000.000';
    end if;
    select id into v_holder from public.catalogo_tramites
     where nombre = 'Otro (valor personalizado)';
    insert into public.tarifas (tramite_id, valor)
    values (v_holder, round(p_valor, 0))
    returning * into v_tarifa;
  else
    v_titulo := null;
    select t.* into v_tarifa
      from public.tarifas t
     where t.tramite_id = p_tramite_id and t.vigente_desde <= now()
     order by t.vigente_desde desc
     limit 1;
    if not found then
      raise exception 'El trámite seleccionado no está disponible';
    end if;
  end if;

  insert into public.pedidos (
    usuario_id, tramite_id, tarifa_id, titulo_personalizado, descripcion, notas,
    recogida_direccion, recogida_referencia, entrega_direccion, entrega_referencia,
    estado, idempotency_key
  ) values (
    v_uid, p_tramite_id, v_tarifa.id, v_titulo, trim(p_descripcion), nullif(trim(p_notas), ''),
    trim(p_recogida_direccion), nullif(trim(p_recogida_referencia), ''),
    trim(p_entrega_direccion), nullif(trim(p_entrega_referencia), ''),
    'buscando_ayudante', p_idempotency_key
  ) returning * into v_pedido;

  return v_pedido;
end $$;

revoke execute on function public.crear_pedido(uuid, text, text, text, text, text, text, uuid, text, numeric) from public, anon;
grant execute on function public.crear_pedido(uuid, text, text, text, text, text, text, uuid, text, numeric) to authenticated;

-- Ya no hay pago simulado de pedidos.
drop function if exists public.simular_pago(uuid);

-- El usuario cancela mientras nadie haya recogido el pedido.
create or replace function public.cancelar_pedido(p_pedido_id uuid, p_motivo text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_estado pedido_estado;
begin
  select estado into v_estado
    from public.pedidos
   where id = p_pedido_id and usuario_id = v_uid
   for update;
  if not found then
    raise exception 'Pedido no encontrado';
  end if;
  if v_estado not in ('pendiente_pago', 'buscando_ayudante') then
    raise exception 'Este pedido ya no se puede cancelar desde aquí';
  end if;

  update public.pedidos
     set estado = 'cancelado',
         motivo_cancelacion = left(coalesce(nullif(trim(p_motivo), ''), 'Sin motivo'), 200)
   where id = p_pedido_id;
end $$;

-- El ayudante necesita un plan vigente (o la prueba de 30 días) para aceptar.
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
  if not coalesce((public.estado_plan(v_uid) ->> 'activo')::boolean, false) then
    raise exception 'Necesitas un plan activo para aceptar servicios. Revisa "Mi plan" en tu cuenta';
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
    raise