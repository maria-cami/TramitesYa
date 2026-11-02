import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

const _estados = [
  'pendiente_pago',
  'buscando_ayudante',
  'asignado',
  'recogido',
  'entregado',
  'cancelado',
];

/// Pedidos: todos los pedidos de la app, con filtro por estado y búsqueda.
class AdminOrdersTab extends ConsumerStatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  ConsumerState<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends ConsumerState<AdminOrdersTab> {
  String _estado = ''; // '' = todos
  String _buscar = '';

  bool _coincide(PedidoAdmin p) {
    final q = _buscar.trim().toLowerCase();
    if (q.isEmpty) return true;
    return p.codigo.toLowerCase().contains(q) ||
        p.tramite.toLowerCase().contains(q) ||
        p.usuario.toLowerCase().contains(q) ||
        (p.ayudante ?? '').toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = ref.watch(pedidosAdminProvider(_estado));

    return PaginaAdmin(
      titulo: 'Pedidos',
      subtitulo: 'Todos los pedidos de la app (los 200 más recientes).',
      onRefresh: () async {
        ref.invalidate(pedidosAdminProvider(_estado));
        await ref.read(pedidosAdminProvider(_estado).future);
      },
      hijos: [
        TextField(
          onChanged: (v) => setState(() => _buscar = v),
          decoration: const InputDecoration(
            hintText: 'Buscar por código, trámite, usuario o ayudante',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Filtro('Todos', _estado == '', () => setState(() => _estado = '')),
              for (final e in _estados)
                _Filtro(
                  EstadoPedido.etiqueta(e),
                  _estado == e,
                  () => setState(() => _estado = e),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        pedidos.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => SizedBox(
            height: 220,
            child: ErrorReintentar(
              onReintentar: () => ref.invalidate(pedidosAdminProvider(_estado)),
            ),
          ),
          data: (lista) {
            final visibles = lista.where(_coincide).toList();
            if (visibles.isEmpty) {
              return const SizedBox(
                height: 200,
                child: EstadoVacio(
                  icono: Icons.inbox_outlined,
                  texto: 'No hay pedidos con ese filtro.',
                ),
              );
            }
            return Column(
              children: [
                for (final p in visibles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FilaPedido(p, onTap: () => _verDetalle(context, p)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _verDetalle(BuildContext context, PedidoAdmin p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.codigo,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  EstadoChip(
                    etiqueta: EstadoPedido.etiqueta(p.estado),
                    color: EstadoPedido.color(p.estado),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Dato('Trámite', p.tramite),
              _Dato('Valor', formatCop(p.valor)),
              _Dato('Usuario', p.usuario),
              _Dato('Ayudante', p.ayudante ?? 'Sin asignar'),
              _Dato('Recogida', p.recogida),
              _Dato('Entrega', p.entrega),
              _Dato('Creado', formatFecha(p.creado)),
              if (p.motivo != null && p.motivo!.isNotEmpty) _Dato('Motivo de cancelación', p.motivo!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filtro extends StatelessWidget {
  const _Filtro(this.texto, this.activo, this.onTap);

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: activo,
        selectedColor: kAzulSoft,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(color: kGris, fontSize: 12)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FilaPedido extends StatelessWidget {
  const _FilaPedido(this.p, {required this.onTap});

  final PedidoAdmin p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.tramite, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${p.codigo} · ${p.usuario}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kGris, fontSize: 12),
                ),
                Text(
                  formatFecha(p.creado),
                  style: const TextStyle(color: kGris, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCop(p.valor), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              EstadoChip(
                etiqueta: EstadoPedido.etiqueta(p.estado),
                color: EstadoPedido.color(p.estado),
              ),
            ],
          ),
        ],
      ),
    );
  }
}