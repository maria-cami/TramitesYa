import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Detalle de un pedido + cancelación (HU19 / HU22 parcial).
/// Seguimiento en mapa y chat (HU20, HU23) llegan en la siguiente fase.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.pedidoId});

  final String pedidoId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _cancelando = false;

  Future<void> _cancelar() async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    if (motivo == null || !mounted) return;

    setState(() => _cancelando = true);
    try {
      await ref.read(appRepositoryProvider).cancelarPedido(widget.pedidoId, motivo);
      ref.invalidate(pedidoProvider(widget.pedidoId));
      ref.invalidate(pedidosProvider);
      if (mounted) mostrarMensaje(context, 'Pedido cancelado');
    } on AppException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } catch (_) {
      if (mounted) {
        mostrarMensaje(context, 'No hay conexión. Revisa tu internet', error: true);
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = ref.watch(pedidoProvider(widget.pedidoId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del pedido'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pedidoProvider(widget.pedidoId)),
          ),
        ],
      ),
      body: SafeArea(
        child: pedido.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorReintentar(
            onReintentar: () => ref.invalidate(pedidoProvider(widget.pedidoId)),
          ),
          data: (p) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p.codigo,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  EstadoChip(
                    etiqueta: EstadoPedido.etiqueta(p.estado),
                    color: EstadoPedido.color(p.estado),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(formatFecha(p.createdAt)),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Dato('Trámite', p.tramiteNombre),
                    _Dato('Descripción', p.descripcion),
                    if (p.notas != null) _Dato('Notas', p.notas!),
                    const Divider(),
                    _Dato('Recogida', _dir(p.recogidaDireccion, p.recogidaReferencia)),
                    _Dato('Entrega', _dir(p.entregaDireccion, p.entregaReferencia)),
                    const Divider(),
                    _Dato('Total', formatCop(p.valor)),
                    const _Dato('Seguro', 'Incluido sin costo'),
                    if (p.motivoCancelacion != null)
                      _Dato('Motivo de cancelación', p.motivoCancelacion!),
                  ],
                ),
              ),
              if (p.estado == EstadoPedido.buscandoAyudante) ...[
                const SizedBox(height: 16),
                const AppCard(
                  child: Row(
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: kBrand),
                      ),
                      SizedBox(width: 12),
                      Expanded(child: Text('Estamos buscando un ayudante cerca de ti…')),
                    ],
                  ),
                ),
              ],
              if (EstadoPedido.cancelable(p.estado)) ...[
                const SizedBox(height: 20),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _cancelando ? null : _cancelar,
                  child: _cancelando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Cancelar pedido'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _dir(String direccion, String? referencia) =>
      (referencia == null || referencia.isEmpty) ? direccion : '$direccion ($referencia)';
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

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
            width: 104,
            child: Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}

/// Motivo de cancelación (HU19): selección + texto libre si elige "Otro".
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  static const _motivos = [
    'Cambié de opinión',
    'Tardó mucho',
    'Error en el pedido',
    'Otro',
  ];

  final _otro = TextEditingController();
  String _motivo = _motivos.first;

  @override
  void dispose() {
    _otro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esOtro = _motivo == 'Otro';
    return AlertDialog(
      title: const Text('Cancelar pedido'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in _motivos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m),
                trailing: Icon(
                  _motivo == m ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: _motivo == m ? kBrand : null,
                ),
                onTap: () => setState(() => _motivo = m),
              ),
            if (esOtro)
              TextField(
                controller: _otro,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Cuéntanos el motivo (opcional)',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
          onPressed: () {
            final detalle = _otro.text.trim();
            Navigator.pop(context, esOtro && detalle.isNotEmpty ? detalle : _motivo);
          },
          child: const Text('Cancelar pedido'),
        ),
      ],
    );
  }
}
