-- Ejecutar una vez en Supabase > SQL Editor si ya tienes la base creada.
-- El registro permite elegir 'usuario' o 'ayudante'. 'admin' nunca se acepta desde el cliente.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_rol user_role := 'usuario';
begin
  if (new.raw_user_meta_data ->> 'rol') = 'ayudante' then
    v_rol := 'ayudante';
  end if;
  insert into public.profiles (id, role, nombre_completo, telefono)
  values (
    new.id,
    v_rol,
    nullif(trim(new.raw_user_meta_data ->> 'nombre_completo'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'telefono'), '')
  );
  insert into public.billeteras (profile_id) values (new.id);
  return new;
end $$;
