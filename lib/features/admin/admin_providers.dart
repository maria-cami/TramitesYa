import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_repository.dart';
import '../../data/providers.dart';

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepository(ref.watch(supabaseProvider)));

final resumenAdminProvider = FutureProvider.autoDispose<ResumenAdmin>(
  (ref) => ref.watch(adminRepositoryProvider).resumen(),
);

/// Pedidos filtrados por estado ('' = todos).
final pedidosAdminProvider =
    FutureProvider.autoDispose.family<List<PedidoAdmin>, String>(
  (ref, estado) => ref.watch(adminRepositoryProvider).pedidos(estado),
);

/// Personas por rol ('usuario' o 'ayudante').
final personasAdminProvider =
    FutureProvider.autoDispose.family<List<PersonaAdmin>, String>(
  (ref, rol) => ref.watch(adminRepositoryProvider).personas(rol),
);

final catalogoAdminProvider = FutureProvider.autoDispose<List<TramiteAdmin>>(
  (ref) => ref.watch(adminRepositoryProvider).catalogo(),
);