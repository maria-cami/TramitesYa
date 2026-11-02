import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'service_card.dart';

/// Resumen del ayudante: servicios completados y su historial.
/// La app no retiene dinero, así que aquí no hay saldo ni retiros.
class EarningsTab extends ConsumerWidget {
  const EarningsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicios = ref.watch(misServiciosProvider);
    final textos = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(misServiciosProvider);
        await ref.read(misServiciosProvider.future);
      },
      child: servicios.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorReintentar(
          onReintentar: () => ref.invalidate(misServiciosProvider),
        ),
        data: (lista) {
          final hechos =
              lista.where((p) => p.estado == EstadoPedido.entregado).toList();
          final enCurso = lista
              .where((p) =>
                  p.estado == EstadoPedido.asignado ||
                  p.estado == EstadoPedido.recogido)
              .length;
          final total = hechos.fold<num>(0, (suma, p) => suma + p.valor);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Resumen',
                style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Servicios completados', style: textos.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      '${hechos.length}',
                      style: const TextStyle(
                        color: kNavy,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Divider(height: 24),
                    _Fila('En curso', '$enCurso'),
                    const SizedBox(height: 8),
                    _Fila('Valor de los servicios', formatCop(total)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Historial',
                style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (hechos.isEmpty)
                const SizedBox(
                  height: 160,
                  child: EstadoVacio(
                    icono: Icons.assignment_turned_in_outlined,
                    texto: 'Aún no has completado servicios.',
                  ),
                )
              else
                for (final p in hechos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ServiceCard(pedido: p, mostrarEstado: true),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: const TextStyle(color: kGris)),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}