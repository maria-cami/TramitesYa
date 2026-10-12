# TrámitesYa — App de Usuario (Flutter + Supabase)

Primera entrega: **app de Usuario** — registro, login, catálogo con búsqueda, crear pedido en 4 pasos, historial con filtros, detalle con cancelación y billetera (solo lectura).

> **Estado del código:** fue escrito sin poder compilarlo (el entorno donde se generó no tiene el SDK de Flutter). Se revisó a mano y con un chequeo de sintaxis/imports, pero **la primera vez que lo abras pueden salir errores menores de compilación**. Ejecuta `flutter analyze` y corrígelos (o pásamelos y los arreglo).

## 1. Qué incluye

| Historia | Estado | Dónde |
|---|---|---|
| HU01 Registro (validaciones, términos) | ✅ | `features/auth/register_screen.dart` |
| HU02 Login (mensaje genérico de error) | ✅ | `features/auth/login_screen.dart` |
| HU03 Recuperar contraseña | 🟡 solo envía el correo; falta el deep link para fijar la nueva clave | `forgot_password_screen.dart` |
| HU05 Cerrar sesión | ✅ | `account/account_tab.dart` |
| HU06 Onboarding | ⏳ pendiente | — |
| HU07 Catálogo de trámites | ✅ | `home/home_tab.dart` |
| HU08 Búsqueda (desde 2 caracteres) | ✅ | `home/home_tab.dart` |
| HU09–HU10 Tipo y descripción | ✅ | `orders/new_order_screen.dart` |
| HU11 Fotos de referencia | ⏳ pendiente (necesita Supabase Storage) | — |
| HU12–HU13 Direcciones | 🟡 texto libre; sin mapa ni cobertura por zona | `new_order_screen.dart` |
| HU14–HU15 Resumen, costo y seguro | ✅ | `new_order_screen.dart` |
| HU16 Confirmar y pagar | 🟡 **pago simulado** (sin cobro real), con idempotencia | `new_order_screen.dart` + `crear_pedido()` |
| HU19 Cancelar mientras se busca ayudante | ✅ | `orders/order_detail_screen.dart` |
| HU26–HU28 Historial y filtros | ✅ | `orders/orders_tab.dart` |
| HU31 Ver saldo | ✅ | `account/account_tab.dart` |
| HU04 2FA, HU20–HU25 mapa/chat/llamada, HU32–HU38 | ⏳ siguientes fases | — |

## 2. Poner a funcionar el proyecto (Windows / PowerShell)

### 2.1 Supabase
1. Crea un proyecto en <https://supabase.com> (plan Free, sin tarjeta).
2. **SQL Editor → New query**, pega todo `supabase/schema.sql` y ejecútalo (se puede repetir sin romper nada).
3. **Authentication → Providers → Email**: para desarrollo puedes desactivar *Confirm email* y entrar sin verificar el correo. Actívalo de nuevo antes de mostrar el proyecto.
4. **Project Settings → API**: copia la **Project URL** y la **anon public key**. *Nunca* uses la `service_role` en la app.

### 2.2 Carpetas nativas de Android/iOS
Este repositorio trae solo `lib/`, `test/`, `pubspec.yaml` y `supabase/`. Genera las carpetas nativas así (no toca tu código):

```powershell
cd tramitesya_app
flutter create --project-name tramitesya_app --org co.edu.funlam --platforms=android,ios tmp_native
Copy-Item -Recurse tmp_native\android .\android
Copy-Item -Recurse tmp_native\ios .\ios
Remove-Item -Recurse -Force tmp_native
```

Para compilar en **release** en Android, agrega en `android/app/src/main/AndroidManifest.xml`, antes de `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### 2.3 Dependencias, análisis y pruebas
```powershell
flutter pub get
flutter analyze
flutter test
```

### 2.4 Ejecutar
Crea `env.json` en la raíz (ya está en `.gitignore`, no lo subas):
```json
{
  "SUPABASE_URL": "https://TU-PROYECTO.supabase.co",
  "SUPABASE_ANON_KEY": "TU_ANON_KEY"
}
```
```powershell
flutter run --dart-define-from-file=env.json
```
Si no pasas las llaves, la app muestra una pantalla indicando que falta la configuración.

## 3. Prueba manual (checklist)

1. Registrarte con una contraseña débil → debe rechazarla; el botón queda bloqueado hasta aceptar términos.
2. Crear cuenta e iniciar sesión → llegas a Inicio con tu nombre.
3. Buscar "banco" → filtra; buscar "zzz" → estado vacío con botón "Pedir otro trámite".
4. Tocar un trámite → salta directo al paso de detalle. Probar descripción de 5 caracteres (debe fallar) y 10+ (pasa).
5. Poner la misma dirección en recogida y entrega → aparece el aviso de confirmación.
6. Confirmar → el pedido queda en *Buscando ayudante*; en **Cuenta** aparece un movimiento de pago "Completado".
7. Cancelar el pedido → pasa a *Cancelado* y el movimiento a *Reembolsado*.
8. Cerrar sesión → vuelve al login y no queda información del usuario anterior.
9. Con **dos cuentas distintas**: la cuenta B no debe ver los pedidos de la A (RLS).

## 4. Seguridad: lo que ya está y lo que debes saber

- **RLS activado en todas las tablas**; los pedidos y transacciones solo se escriben por funciones SQL (`crear_pedido`, `cancelar_pedido`), nunca con `insert` directo del cliente.
- El **rol nunca viene del cliente**: el trigger `handle_new_user` siempre crea `usuario`, y se revocó el `UPDATE` de la columna `role` (con la policy del modelo original un usuario podría haberse ascendido a admin).
- **Idempotencia** del pago: misma `idempotency_key` ⇒ mismo pedido, un solo cobro.
- ⚠️ **`simular_pago()` es solo para desarrollo**: permite "pagarse" gratis. Elimínala (`drop function public.simular_pago(uuid);`) cuando conectes Wompi, donde el estado cambia únicamente desde el webhook.
- La *anon key* es pública por diseño; lo que protege los datos es RLS. No pongas la `service_role` en la app ni en el repositorio.

## 5. Diferencias con `TramitesYa_Modelo_Base_Datos.md`

El archivo `TramitesYa_schema.sql` completo no estaba disponible, así que `supabase/schema.sql` es una **versión reducida** con solo las tablas de esta fase. Los nombres de las tablas y enums coinciden con el documento; las columnas que el documento no detallaba se definieron aquí. Si ya tienes tu propio `schema.sql`, alinea nombres de columnas (`pedidos.*`, `transacciones.*`) con los que usa `lib/data/`. Diferencias deliberadas:

- `current_role()` → **`mi_rol()`**: `CURRENT_ROLE` es palabra reservada de SQL.
- **Sin policy de INSERT en `pedidos`** (el modelo la tenía): permitiría fijar estado o tarifa desde el cliente.
- Las direcciones son **texto**, sin PostGIS todavía; se migra a `geography` al agregar mapas y asignación de ayudantes.
- Las tarifas del seed son de ejemplo.

## 6. Estructura

```
lib/
├── main.dart                  # arranque + Supabase
├── core/                      # config, tema, router, validadores, formato, widgets
├── data/                      # modelos, repositorios (Supabase) y providers (Riverpod)
└── features/
    ├── auth/                  # login, registro, recuperar
    ├── home/                  # shell con navegación + catálogo
    ├── orders/                # crear pedido, historial, detalle
    └── account/               # perfil, billetera, cerrar sesión
supabase/schema.sql            # tablas, RLS, funciones y datos iniciales
```

## 7. Siguientes pasos sugeridos

1. Compilar, corregir lo que salga en `flutter analyze` y probar el checklist.
2. Onboarding (HU06) + editar perfil (HU35) + direcciones guardadas (HU34).
3. Fotos con Supabase Storage (HU11).
4. App del **ayudante** y asignación (para que los pedidos pasen de *buscando* a *asignado*), luego mapa y chat con Supabase Realtime (HU20, HU23).
5. Wompi sandbox con Edge Function + webhook, y eliminar `simular_pago()`.
