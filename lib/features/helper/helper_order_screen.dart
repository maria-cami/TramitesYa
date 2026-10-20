import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

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
        ..invalidate(misServiciosProvider)
        ..invalidate(saldoProvider)
        ..invalidate(movimientosProvider);
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
                  Text(
                    p.codigo,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  EstadoChip(
                    etiqueta: EstadoPedido.etiqueta(p.estado),
                    color: EstadoPedido.color(p.estado),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Fila('Trámite', p.tramiteNombre),
                    _Fila('Qué hay que hacer', p.descripcion),
                    if (p.notas != null) _Fila('Notas', p.notas!),
                    const Divider(),
                    _Fila('Recogida', _dir(p.recogidaDireccion, p.recogidaReferencia)),
                    _Fila('Entrega', _dir(p.entregaDireccion, p.entregaReferencia)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ganas por este servicio'),
                    Text(
                      formatCop(p.pagoAyudante),
                      style: const TextStyle(
                        color: Color(0xFF159A63),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (p.estado == EstadoPedido.buscandoAyudante)
                FilledButton(
                  onPressed: _ocupado
                      ? null
                      : () => _ejecutar(
                            () => repo.aceptarPedido(p.id),
                            'Pedido aceptado. ¡Manos a la obra!',
                          ),
                  child: _ocupado ? const _Cargando() : const Text('Aceptar pedido'),
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
                            'Entregado. Tu pago ya está en tu billetera',
                          ),
                  child: _ocupado ? const _Cargando() : const Text('Marcar como entregado'),
                ),
              if (p.estado == EstadoPedido.entregado)
                const _Aviso(
                  icono: Icons.check_circle,
                  color: Color(0xFF159A63),
                  texto: 'Servicio completado. El pago ya se acreditó en tu billetera.',
                ),
              if (p.estado == EstadoPedido.cancelado)
                const _Aviso(
                  icono: Icons.cancel_outlined,
                  color: Color(0xFFD64545),
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

class _Fila extends StatelessWidget {
  const _Fila(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}
