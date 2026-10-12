import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

enum _Filtro { todos, enCurso, completados, cancelados }

/// HU26–HU28 — Historial de pedidos con filtro por estado.
class OrdersTab extends ConsumerStatefulWidget {
  const OrdersTab({super.key});

  @override
  ConsumerState<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<OrdersTab> {
  _Filtro _filtro = _Filtro.todos;

  static const _etiquetas = {
    _Filtro.todos: 'Todos',
    _Filtro.enCurso: 'En curso',
    _Filtro.completados: 'Completados',
    _Filtro.cancelados: 'Cancelados',
  };

  bool _coincide(Pedido p) => switch (_filtro) {
        _Filtro.todos => true,
        _Filtro.enCurso => EstadoPedido.enCurso.contains(p.estado),
        _Filtro.completados => p.estado == EstadoPedido.entregado,
        _Filtro.cancelados => p.estado == EstadoPedido.cancelado,
      };

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(pedidosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'Mis pedidos',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final f in _Filtro.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                      label: Text(
                      _etiquetas[f]!,
                      style: TextStyle(color: _filtro == f ? Colors.white : null),
                    ),
                    showCheckmark: false,
                    selected: _filtro == f,
                    onSelected: (_) => setState(() => _filtro = f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: pedidos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                ErrorReintentar(onReintentar: () => ref.invalidate(pedidosProvider)),
            data: (todos) {
              final lista = todos.where(_coincide).toList();
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(pedidosProvider);
                  await ref.read(pedidosProvider.future);
                },
                child: lista.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 320,
                            child: EstadoVacio(
                              icono: Icons.inbox_outlined,
                              texto: _filtro == _Filtro.todos
                                  ? 'Aún no tienes pedidos. ¡Pide tu primer trámite desde Inicio!'
                                  : 'No tienes pedidos en este estado.',
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        itemCount: lista.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _PedidoCard(pedido: lista[i]),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PedidoCard extends StatelessWidget {
  const _PedidoCard({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push('/pedido/${pedido.id}'),
      child: Row(
        children: [
          const IconoTile(Icons.receipt_long_outlined, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pedido.tramiteNombre,
                    style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${pedido.codigo} · ${formatFecha(pedido.createdAt)}',
                    style: textos.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCop(pedido.valor),
                  style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              EstadoChip(
                etiqueta: EstadoPedido.etiqueta(pedido.estado),
                color: EstadoPedido.color(pedido.estado),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
