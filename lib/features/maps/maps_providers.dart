import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/maps_repository.dart';
import '../../data/providers.dart';

final mapsRepositoryProvider =
    Provider<MapsRepository>((ref) => MapsRepository(ref.watch(supabaseProvider)));

final coordenadasPedidoProvider =
    FutureProvider.autoDispose.family<CoordenadasPedido, String>(
  (ref, pedidoId) => ref.watch(mapsRepositoryProvider).coordenadas(pedidoId),
);
