import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../maps/route_map.dart';

/// Detalle de un servicio para el ayudante, con la acción que corresponde a su estado:
/// disponible → Aceptar · asignado → Recogido / Soltar · recogido → Entregado.
class HelperOrderScreen extends ConsumerStatefulWidget {
  const HelperOrderScreen({super.key, required this.pedidoId});

  final String pedidoId;

  @override
  ConsumerState<HelperOrderScreen> createState() => _HelperOrderScreenState();
}

class _HelperOrderScreenState extends ConsumerState<HelperOrderScreen> {
  bool _ocupado = false;

  Future<void> _ejecutar(
    Future<void> Function() accion,
    String exito, {
    bool volver = false,
  }) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      ref
        ..invalidate(servicioProvider(widget.pedidoId))
        ..invalidate(disponiblesProvider)
        ..invalidate(misServiciosProvider);
      if (!mounted) return;
      mostrarMensaje(context, exito);
      if (volver) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
      // Si alguien más tomó el pedido, refresca para mostrar su estado real.
      ref
        ..invalidate(servicioProvider(widget.pedidoId))
        ..invalidate(disponiblesProvider);
    } catch (_) {
      if (mounted) {
        mostrarMensaje(context, 'No hay conexión. Revisa tu internet', error: true);
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _soltar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Soltar pedido'),
        content: const Text('El pedido volverá a la lista para que otro ayudante lo tome.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Soltar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _ejecutar(
      () => ref.read(appRepositoryProvider).soltarPedido(widget.pedidoId),
      'Pedido devuelto a la lista',
      volver: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicio = ref.watch(servicioProvider(widget.pedidoId));
    final repo = ref.read(appRepositoryProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del servicio'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(servicioProvider(widget.pedidoId)),
          ),
        ],
      ),
      body: SafeArea(
        child: servicio.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorReintentar(
            mensaje: 'No pudimos cargar este servicio. Puede que ya lo haya tomado otro ayudante.',
            onReintentar: () => ref.invalidate(servicioProvider(widget.pedidoId)),
          ),
          data: (p) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EstadoChip(
                    etiqueta: EstadoPedido.etiqueta(p.estado),
                    color: EstadoPedido.color(p.estado),
                  ),
                  Text(p.codigo, style: textos.bodySmall),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                p.tramiteNombre,
                style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                formatCop(p.valor),
                style: const TextStyle(
                  color: kNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                ),
              ),
              Text('Cobras directamente al usuario', style: textos.bodySmall),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  children: [
                    _Punto(
                      icono: Icons.north_east,
                      titulo: 'Recogida',
                      texto: _dir(p.recogidaDireccion, p.recogidaReferencia),
                    ),
                    const Divider(height: 24),
                    _Punto(
                      icono: Icons.south_west,
                      titulo: 'Entrega',
                      texto: _dir(p.entregaDireccion, p.entregaReferencia),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instrucciones',
                      style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(p.descripcion),
                    if (p.notas != null && p.notas!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Notas: ${p.notas}', style: textos.bodySmall),
                    ],
                  ],
                ),
              ),
              // Mapa con recogida y entrega (solo si el pedido tiene ubicaciones guardadas).
              const SizedBox(height: 12),
              RutaPedidoMapa(pedidoId: widget.pedidoId),
              if (p.estado == EstadoPedido.asignado ||
                  p.estado == EstadoPedido.recogido ||
                  p.estado == EstadoPedido.entregado) ...[
                const SizedBox(height: 12),
                _Progreso(p.estado),
              ],
              const SizedBox(height: 20),
              if (p.estado == EstadoPedido.buscandoAyudante)
                FilledButton(
                  onPressed: _ocupado
                      ? null
                      : () => _ejecutar(
                            () => repo.aceptarPedido(p.id),
                            'Pedido aceptado. ¡Manos a la obra!',
                          ),
                  child: _ocupado ? const _Cargando() : const Text('Aceptar servicio'),
                ),
              if (p.estado == EstadoPedido.asignado) ...[
                FilledButton(
                  onPressed: _ocupado
                      ? null
                      : () => _ejecutar(
                            () => repo.marcarRecogido(p.id),
                            'Marcado como recogido',
                          ),
                  child: _ocupado ? const _Cargando() : const Text('Ya recogí el encargo'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _ocupado ? null : _soltar,
                  child: const Text('Soltar pedido'),
                ),
              ],
              if (p.estado == EstadoPedido.recogido)
                FilledButton(
                  onPressed: _ocupado
                      ? null
                      : () => _ejecutar(
                            () => repo.marcarEntregado(p.id),
                            'Servicio finalizado',
                          ),
                  child: _ocupado ? const _Cargando() : const Text('Finalizar servicio'),
                ),
              if (p.estado == EstadoPedido.entregado)
                const _Aviso(
                  icono: Icons.check_circle,
                  color: kVerde,
                  texto: 'Servicio completado.',
                ),
              if (p.estado == EstadoPedido.cancelado)
                const _Aviso(
                  icono: Icons.cancel_outlined,
                  color: kError,
                  texto: 'Este pedido fue cancelado.',
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _dir(String direccion, String? referencia) =>
      (referencia == null || referencia.isEmpty) ? direccion : '$direccion ($referencia)';
}

/// Línea de tiempo del servicio: Aceptado → Recogida realizada → Entrega finalizada.
class _Progreso extends StatelessWidget {
  const _Progreso(this.estado);

  final String estado;

  static const _pasos = ['Aceptado', 'Recogida realizada', 'Entrega finalizada'];

  @override
  Widget build(BuildContext context) {
    final actual = switch (estado) {
      EstadoPedido.asignado => 0,
      EstadoPedido.recogido => 1,
      EstadoPedido.entregado => 2,
      _ => -1,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _pasos.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    i <= actual ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: i <= actual ? kAzul : kBorde,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _pasos[i],
                    style: TextStyle(
                      fontWeight: i == actual ? FontWeight.w700 : FontWeight.w500,
                      color: i <= actual ? kNavy : kGris,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.icono, required this.titulo, required this.texto});

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconoTile(icono, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(texto, style: textos.bodyMedium?.copyWith(color: kGris)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.color, required this.texto});

  final IconData icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}