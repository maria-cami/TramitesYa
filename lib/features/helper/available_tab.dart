import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/providers.dart';
import 'service_card.dart';

/// Pedidos que están buscando ayudante. Se refresca solo cada 20 s
/// (el tiempo real con Supabase Realtime llega en la siguiente fase).
class AvailableTab extends ConsumerStatefulWidget {
  const AvailableTab({super.key});

  @override
  ConsumerState<AvailableTab> createState() => _AvailableTabState();
}

class _AvailableTabState extends ConsumerState<AvailableTab> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) ref.invalidate(disponiblesProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disponibles = ref.watch(disponiblesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Text(
            'Pedidos disponibles',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Toca uno para ver los detalles y aceptarlo.'),
        ),
        Expanded(
          child: disponibles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                ErrorReintentar(onReintentar: () => ref.invalidate(disponiblesProvider)),
            data: (lista) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(disponiblesProvider);
                await ref.read(disponiblesProvider.future);
              },
              child: lista.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 320,
                          child: EstadoVacio(
                            icono: Icons.inbox_outlined,
                            texto: 'No hay pedidos disponibles por ahora. Desliza hacia abajo para actualizar.',
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => ServiceCard(pedido: lista[i]),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
