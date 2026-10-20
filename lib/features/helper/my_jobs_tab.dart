import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/providers.dart';
import 'service_card.dart';

/// Servicios que el ayudante aceptó: en curso y terminados.
class MyJobsTab extends ConsumerWidget {
  const MyJobsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicios = ref.watch(misServiciosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Mis servicios',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: servicios.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                ErrorReintentar(onReintentar: () => ref.invalidate(misServiciosProvider)),
            data: (lista) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(misServiciosProvider);
                await ref.read(misServiciosProvider.future);
              },
              child: lista.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 320,
                          child: EstadoVacio(
                            icono: Icons.assignment_outlined,
                            texto: 'Aún no has aceptado servicios. Mira los pedidos disponibles.',
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          ServiceCard(pedido: lista[i], mostrarEstado: true),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
