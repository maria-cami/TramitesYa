import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'repositories.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));

final appRepositoryProvider =
    Provider<AppRepository>((ref) => AppRepository(ref.watch(supabaseProvider)));

// autoDispose en todo lo que es de un usuario: al cerrar sesión no queda
// información en caché del usuario anterior.
final perfilProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(appRepositoryProvider).perfil(),
);

// ---- Verificación en dos pasos ----
final estadoMfaProvider = FutureProvider.autoDispose<EstadoMfa>(
  (ref) => ref.watch(authRepositoryProvider).estadoMfa(),
);

final mfaActivoProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(authRepositoryProvider).tieneMfa(),
);

final tramitesProvider = FutureProvider.autoDispose<List<Tramite>>(
  (ref) => ref.watch(appRepositoryProvider).tramites(),
);

final pedidosProvider = FutureProvider.autoDispose<List<Pedido>>(
  (ref) => ref.watch(appRepositoryProvider).pedidos(),
);

final pedidoProvider = FutureProvider.autoDispose.family<Pedido, String>(
  (ref, id) => ref.watch(appRepositoryProvider).pedido(id),
);

// ---- Ayudante ----
final disponiblesProvider = FutureProvider.autoDispose<List<Pedido>>(
  (ref) => ref.watch(appRepositoryProvider).pedidosDisponibles(),
);

final misServiciosProvider = FutureProvider.autoDispose<List<Pedido>>(
  (ref) => ref.watch(appRepositoryProvider).misServicios(),
);

final servicioProvider = FutureProvider.autoDispose.family<Pedido, String>(
  (ref, id) => ref.watch(appRepositoryProvider).pedidoDeAyudante(id),
);

final saldoProvider = FutureProvider.autoDispose<num>(
  (ref) => ref.watch(appRepositoryProvider).saldo(),
);

final movimientosProvider = FutureProvider.autoDispose<List<Movimiento>>(
  (ref) => ref.watch(appRepositoryProvider).movimientos(),
);

// ---- Seguimiento y chat ----
final estadoPedidoEnVivoProvider = StreamProvider.autoDispose.family<String, String>(
  (ref, pedidoId) => ref.watch(appRepositoryProvider).estadoPedido(pedidoId),
);

final nombreAyudanteProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, pedidoId) => ref.watch(appRepositoryProvider).nombreAyudante(pedidoId),
);