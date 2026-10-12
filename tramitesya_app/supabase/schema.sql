-- ============================================================================
-- TrámitesYa — Esquema Supabase (primera entrega: app de Usuario)
-- Pegar completo en Supabase > SQL Editor > Run.
-- Cubre: perfiles, billetera, catálogo + tarifas, pedidos, transacciones.
-- Tablas del modelo completo que aún NO están aquí (se agregan con cada fase):
-- ayudantes, direcciones_guardadas, mensajes_chat, calificaciones, incidencias,
-- tickets_soporte, referidos, auditoria_admin, metodos_pago, retiros_ayudante.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------- Tipos ----------
do $$ begin
  create type user_role as enum ('usuario', 'ayudante', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type pedido_estado as enum
    ('pendiente_pago', 'buscando_ayudante', 'asignado', 'recogido', 'entregado', 'cancelado');
exception when duplicate_object then null; end $$;

do $$ begin
  create type transaccion_tipo as enum
    ('pago_pedido', 'recarga_billetera', 'reembolso', 'pago_ayudante', 'retiro');
exception when duplicate_object then null; end $$;

do $$ begin
  create type transaccion_estado as enum ('pending', 'completed', 'failed', 'refunded');
exception when duplicate_object then null; end $$;

-- ---------- Utilidades ----------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- OJO: el modelo original llama a esta función current_role(), pero
-- CURRENT_ROLE es palabra reservada de SQL. Se nombra mi_rol() para evitar conflictos.
create or replace function public.mi_rol()
returns user_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid();
$$;

-- ---------- Perfiles (1:1 con auth.users) ----------
create table if not exists public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  role             user_role not null default 'usuario',
  nombre_completo  text,
  telefono         text,
  foto_url         text,
  codigo_referido  text unique default substr(md5(random()::text), 1, 8),
  bloqueado        boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------- Billeteras ----------
create table if not exists public.billeteras (
  profile_id  uuid primary key references public.profiles (id) on delete cascade,
  saldo       numeric(12,2) not null default 0 check (saldo >= 0),
  updated_at  timestamptz not null default now()
);

-- Al crearse un usuario en auth.users se crean su perfil y su billetera.
-- El rol SIEMPRE nace como 'usuario': raw_user_meta_data lo controla el cliente
-- y nunca debe decidir privilegios.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, role, nombre_completo, telefono)
  values (
    new.id,
    'usuario',
    nullif(trim(new.raw_user_meta_data ->> 'nombre_completo'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'telefono'), '')
  );
  insert into public.billeteras (profile_id) values (new.id);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Catálogo y tarifas ----------
create table if not exists public.catalogo_tramites (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null unique check (char_length(nombre) <= 60),
  categoria  text,
  icono      text,
  activo     boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.tarifas (
  id             uuid primary key default gen_random_uuid(),
  tramite_id     uuid not null references public.catalogo_tramites (id),
  valor          numeric(12,2) not null check (valor > 0),
  vigente_desde  timestamptz not null default now()
);
create index if not exists idx_tarifas_tramite on public.tarifas (tramite_id, vigente_desde desc);

-- ---------- Pedidos ----------
create sequence if not exists public.pedido_codigo_seq;

create table if not exists public.pedidos (
  id                    uuid primary key default gen_random_uuid(),
  codigo                text unique,
  usuario_id            uuid not null references public.profiles (id),
  ayudante_id           uuid references public.profiles (id),
  tramite_id            uuid not null references public.catalogo_tramites (id),
  tarifa_id             uuid not null references public.tarifas (id),  -- precio congelado (HU74)
  descripcion           text not null check (char_length(descripcion) between 10 and 500),
  notas                 text check (notas is null or char_length(notas) <= 300),
  recogida_direccion    text not null,
  recogida_referencia   text check (recogida_referencia is null or char_length(recogida_referencia) <= 150),
  entrega_direccion     text not null,
  entrega_referencia    text check (entrega_referencia is null or char_length(entrega_referencia) <= 150),
  estado                pedido_estado not null default 'pendiente_pago',
  motivo_cancelacion    text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index if not exists idx_pedidos_usuario on public.pedidos (usuario_id, created_at desc);
create index if not exists idx_pedidos_ayudante on public.pedidos (ayudante_id);

create or replace function public.fn_generar_codigo_pedido()
returns trigger language plpgsql as $$
begin
  if new.codigo is null then
    new.codigo := 'TY-' || to_char(now(), 'YYMMDD') || '-' ||
                  lpad(nextval('public.pedido_codigo_seq')::text, 5, '0');
  end if;
  return new;
end $$;

drop trigger if exists trg_pedidos_codigo on public.pedidos;
create trigger trg_pedidos_codigo before insert on public.pedidos
  for each row execute function public.fn_generar_codigo_pedido();

drop trigger if exists trg_pedidos_updated_at on public.pedidos;
create trigger trg_pedidos_updated_at before update on public.pedidos
  for each row execute function public.set_updated_at();

-- ---------- Transacciones ----------
create table if not exists public.transacciones (
  id                    uuid primary key default gen_random_uuid(),
  profile_id            uuid not null references public.profiles (id),
  pedido_id             uuid references public.pedidos (id),
  tipo                  transaccion_tipo not null,
  estado                transaccion_estado not null default 'pending',
  monto                 numeric(12,2) not null check (monto > 0),
  idempotency_key       uuid not null unique,
  checkout_session_id   text,
  payment_intent_id     text unique,
  respuesta_proveedor   jsonb,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index if not exists idx_transacciones_profile on public.transacciones (profile_id, created_at desc);

drop trigger if exists trg_transacciones_updated_at on public.transacciones;
create trigger trg_transacciones_updated_at before update on public.transacciones
  for each row execute function public.set_updated_at();

-- ============================================================================
-- RLS: todo cerrado por defecto. Solo se abren lecturas propias.
-- Las escrituras de pedidos/transacciones pasan por funciones SECURITY DEFINER.
-- ============================================================================
alter table public.profiles          enable row level security;
alter table public.billeteras        enable row level security;
alter table public.catalogo_tramites enable row level security;
alter table public.tarifas           enable row level security;
alter table public.pedidos           enable row level security;
alter table public.transacciones     enable row level security;

drop policy if exists "ver_propio_perfil" on public.profiles;
create policy "ver_propio_perfil" on public.profiles for select
  using (id = auth.uid());
drop policy if exists "admin_ve_todos_los_perfiles" on public.profiles;
create policy "admin_ve_todos_los_perfiles" on public.profiles for select
  using (public.mi_rol() = 'admin');
drop policy if exists "editar_propio_perfil" on public.profiles;
create policy "editar_propio_perfil" on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- Seguridad extra: la policy anterior permitiría que un usuario se cambie el
-- 'role' a admin con un UPDATE. Se restringen las columnas editables.
revoke update on public.profiles from authenticated, anon;
grant update (nombre_completo, telefono, foto_url) on public.profiles to authenticated;

drop policy if exists "ver_propia_billetera" on public.billeteras;
create policy "ver_propia_billetera" on public.billeteras for select
  using (profile_id = auth.uid());

drop policy if exists "ver_catalogo_activo" on public.catalogo_tramites;
create policy "ver_catalogo_activo" on public.catalogo_tramites for select
  to authenticated using (
    activo
    or exists (
      select 1 from public.pedidos p
       where p.tramite_id = catalogo_tramites.id and p.usuario_id = auth.uid()
    )
  );  -- un trámite desactivado sigue visible en los pedidos históricos del usuario

drop policy if exists "ver_tarifas" on public.tarifas;
create policy "ver_tarifas" on public.tarifas for select
  to authenticated using (true);

drop policy if exists "usuario_ve_sus_pedidos" on public.pedidos;
create policy "usuario_ve_sus_pedidos" on public.pedidos for select
  using (usuario_id = auth.uid());
drop policy if exists "ayudante_ve_pedidos_asignados" on public.pedidos;
create policy "ayudante_ve_pedidos_asignados" on public.pedidos for select
  using (ayudante_id = auth.uid());
drop policy if exists "admin_ve_todos_los_pedidos" on public.pedidos;
create policy "admin_ve_todos_los_pedidos" on public.pedidos for select
  using (public.mi_rol() = 'admin');
-- Sin policy de INSERT/UPDATE en pedidos: un insert directo podría fijar
-- estado o tarifa a gusto del cliente. Se crea solo vía crear_pedido().

drop policy if exists "dueno_ve_sus_transacciones" on public.transacciones;
create policy "dueno_ve_sus_transacciones" on public.transacciones for select
  using (profile_id = auth.uid());
drop policy if exists "admin_ve_todas_las_transacciones" on public.transacciones;
create policy "admin_ve_todas_las_transacciones" on public.transacciones for select
  using (public.mi_rol() = 'admin');

-- ============================================================================
-- Funciones que usa la app (HU16, HU19)
-- ============================================================================

-- Crea el pedido con la tarifa vigente congelada + la transacción pendiente.
-- Idempotente: si llega la misma idempotency_key devuelve el pedido ya creado.
create or replace function public.crear_pedido(
  p_tramite_id           uuid,
  p_descripcion          text,
  p_notas                text,
  p_recogida_direccion   text,
  p_recogida_referencia  text,
  p_entrega_direccion    text,
  p_entrega_referencia   text,
  p_idempotency_key      uuid
) returns public.pedidos
language plpgsql security definer set search_path = public as $$
declare
  v_uid       uuid := auth.uid();
  v_existente uuid;
  v_tarifa    public.tarifas;
  v_pedido    public.pedidos;
begin
  if v_uid is null then
    raise exception 'No autenticado' using errcode = '28000';
  end if;
  if exists (select 1 from public.profiles where id = v_uid and bloqueado) then
    raise exception 'Tu cuenta está restringida. Contacta a soporte.';
  end if;

  select pedido_id into v_existente
    from public.transacciones
   where idempotency_key = p_idempotency_key and profile_id = v_uid;
  if v_existente is not null then
    select * into v_pedido from public.pedidos where id = v_existente;
    return v_pedido;
  end if;

  select t.* into v_tarifa
    from public.tarifas t
    join public.catalogo_tramites c on c.id = t.tramite_id
   where t.tramite_id = p_tramite_id and c.activo and t.vigente_desde <= now()
   order by t.vigente_desde desc
   limit 1;
  if not found then
    raise exception 'El trámite seleccionado no está disponible';
  end if;

  insert into public.pedidos (
    usuario_id, tramite_id, tarifa_id, descripcion, notas,
    recogida_direccion, recogida_referencia, entrega_direccion, entrega_referencia
  ) values (
    v_uid, p_tramite_id, v_tarifa.id, trim(p_descripcion), nullif(trim(p_notas), ''),
    trim(p_recogida_direccion), nullif(trim(p_recogida_referencia), ''),
    trim(p_entrega_direccion), nullif(trim(p_entrega_referencia), '')
  ) returning * into v_pedido;

  insert into public.transacciones (profile_id, pedido_id, tipo, monto, idempotency_key)
  values (v_uid, v_pedido.id, 'pago_pedido', v_tarifa.valor, p_idempotency_key);

  return v_pedido;
end $$;

-- !!! SOLO DESARROLLO / SANDBOX !!!
-- Marca el pago como completado sin pasar por una pasarela. Cualquier usuario
-- autenticado podría "pagarse" gratis, así que ELIMÍNALA (drop function) cuando
-- conectes Wompi: allí el estado solo cambia desde el webhook (Edge Function).
create or replace function public.simular_pago(p_pedido_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if not exists (select 1 from public.pedidos where id = p_pedido_id and usuario_id = v_uid) then
    raise exception 'Pedido no encontrado';
  end if;

  update public.transacciones
     set estado = 'completed',
         respuesta_proveedor = jsonb_build_object('proveedor', 'simulado')
   where pedido_id = p_pedido_id and tipo = 'pago_pedido' and estado = 'pending';

  update public.pedidos
     set estado = 'buscando_ayudante'
   where id = p_pedido_id and estado = 'pendiente_pago';
end $$;

-- Cancelación por el usuario mientras no haya recogida (HU19).
-- Simplificación: si el pedido ya estaba pagado, la transacción pasa a 'refunded'.
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

  update public.transacciones
     set estado = 'refunded'
   where pedido_id = p_pedido_id and tipo = 'pago_pedido' and estado = 'completed';
end $$;

revoke execute on function public.crear_pedido(uuid, text, text, text, text, text, text, uuid) from public, anon;
revoke execute on function public.simular_pago(uuid) from public, anon;
revoke execute on function public.cancelar_pedido(uuid, text) from public, anon;
grant execute on function public.crear_pedido(uuid, text, text, text, text, text, text, uuid) to authenticated;
grant execute on function public.simular_pago(uuid) to authenticated;
grant execute on function public.cancelar_pedido(uuid, text) to authenticated;

-- ============================================================================
-- Datos iniciales (los valores de tarifa son de ejemplo; se editan luego desde el panel admin)
-- ============================================================================
insert into public.catalogo_tramites (nombre, categoria, icono) values
  ('Recoger medicamentos', 'Salud',      'medicamentos'),
  ('Ir a fila en el banco', 'Finanzas',  'banco'),
  ('Pagar recibos',        'Finanzas',   'recibos'),
  ('Enviar documentos',    'Documentos', 'documentos'),
  ('Trámites en entidades','Entidades',  'entidades'),
  ('Otro trámite',         'Otros',      'otro')
on conflict (nombre) do nothing;

insert into public.tarifas (tramite_id, valor)
select c.id, v.valor
  from public.catalogo_tramites c
  join (values
    ('Recoger medicamentos', 18500),
    ('Ir a fila en el banco', 15000),
    ('Pagar recibos', 12000),
    ('Enviar documentos', 10000),
    ('Trámites en entidades', 20000),
    ('Otro trámite', 15000)
  ) as v(nombre, valor) on v.nombre = c.nombre
 where not exists (select 1 from public.tarifas t where t.tramite_id = c.id);
