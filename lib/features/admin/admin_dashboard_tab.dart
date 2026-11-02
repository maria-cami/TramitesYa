import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Resumen: números del negocio.
class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenAdminProvider);
    return PaginaAdmin(
      titulo: 'Resumen',
      subtitulo: 'Así va TrámitesYa hoy.',
      onRefresh: () async {
        ref.invalidate(resumenAdminProvider);
        await ref.read(resumenAdminProvider.future);
      },
      hijos: [
        resumen.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 260,
            child: ErrorReintentar(
              onReintentar: () => ref.invalidate(resumenAdminProvider),
            ),
          ),
          data: (r) => _Contenido(r),
        ),
      ],
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido(this.r);

  final ResumenAdmin r;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final estados = r.porEstado.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maximo = estados.isEmpty ? 1 : estados.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final columnas = c.maxWidth >= 700 ? 4 : 2;
            const espacio = 12.0;
            final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
            Widget dato(String t, String v, IconData i, Color color) =>
                SizedBox(width: ancho, child: _Dato(t, v, i, color));
            return Wrap(
              spacing: espacio,
              runSpacing: espacio,
              children: [
                dato('Pedidos hoy', '${r.pedidosHoy}', Icons.today, kBrand),
                dato('En curso', '${r.enCurso}', Icons.local_shipping_outlined, kAzul),
                dato('Usuarios', '${r.usuarios}', Icons.people_outline, kVerde),
                dato('Ayudantes', '${r.ayudantes}', Icons.directions_run, kAmbar),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
                Text('Planes (ingresos de TrámitesYa)',
            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilaDinero('Planes activos', r.planesActivos),
              const Divider(height: 24),
              _FilaDinero('Planes vendidos este mes', r.ingresosPlanesMes),
              const SizedBox(height: 12),
              Text(
                'En modo de pruebas los planes no se cobran de verdad.',
                style: textos.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Valor de los servicios',
            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilaDinero('Entregados hoy', r.ingresosHoy),
              const Divider(height: 24),
              _FilaDinero('Entregados en total', r.ingresos),
              const SizedBox(height: 12),
              Text(
                'Es dinero entre usuarios y ayudantes. TrámitesYa no lo retiene.',
                style: textos.bodySmall,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        Text('Pedidos por estado  (${r.pedidosTotal} en total)',
            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        AppCard(
          child: estados.isEmpty
              ? const Text('Aún no hay pedidos.')
              : Column(
                  children: [
                    for (final e in estados)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _BarraEstado(
                          etiqueta: EstadoPedido.etiqueta(e.key),
                          color: EstadoPedido.color(e.key),
                          cantidad: e.value,
                          proporcion: e.value / maximo,
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        Text('Últimos pedidos',
            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (r.ultimos.isEmpty)
          const AppCard(child: Text('Aún no hay pedidos.'))
        else
          for (final p in r.ultimos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FilaPedido(p),
            ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.titulo, this.valor, this.icono, this.color);

  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                  ),
                ),
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kGris, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaDinero extends StatelessWidget {
  const _FilaDinero(this.titulo, this.monto);

  final String titulo;
  final num monto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(titulo)),
        Text(
          formatCop(monto),
          style: const TextStyle(fontWeight: FontWeight.w800, color: kNavy),
        ),
      ],
    );
  }
}

class _BarraEstado extends StatelessWidget {
  const _BarraEstado({
    required this.etiqueta,
    required this.color,
    required this.cantidad,
    required this.proporcion,
  });

  final String etiqueta;
  final Color color;
  final int cantidad;
  final double proporcion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(etiqueta)),
            Text('$cantidad', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: proporcion.clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _FilaPedido extends StatelessWidget {
  const _FilaPedido(this.p);

  final PedidoReciente p;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.codigo.isEmpty ? 'Pedido' : p.codigo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  formatFecha(p.creado),
                  style: const TextStyle(color: kGris, fontSize: 12),
                ),
              ],
            ),
          ),
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