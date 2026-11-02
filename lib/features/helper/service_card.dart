import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Tarjeta de un pedido en las listas del ayudante. Si recibe [onAceptar],
/// muestra el botón azul "Aceptar" como en el mockup.
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.pedido,
    this.mostrarEstado = false,
    this.onAceptar,
    this.aceptando = false,
  });

  final Pedido pedido;
  final bool mostrarEstado;
  final VoidCallback? onAceptar;
  final bool aceptando;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push('/servicio/${pedido.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoTile(Icons.assignment_outlined, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pedido.tramiteNombre,
                  style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (mostrarEstado)
                EstadoChip(
                  etiqueta: EstadoPedido.etiqueta(pedido.estado),
                  color: EstadoPedido.color(pedido.estado),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _Linea(Icons.north_east, 'Recogida', pedido.recogidaDireccion),
          const SizedBox(height: 4),
          _Linea(Icons.south_west, 'Entrega', pedido.entregaDireccion),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                'Valor ${formatCop(pedido.valor)}',
                  style: const TextStyle(
                    color: kNavy,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (onAceptar != null)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kAzul,
                    minimumSize: const Size(96, 40),
                  ),
                  onPressed: aceptando ? null : onAceptar,
                  child: aceptando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aceptar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.icono, this.etiqueta, this.texto);

  final IconData icono;
  final String etiqueta;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 16, color: kAzul),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$etiqueta: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: texto, style: const TextStyle(color: kGris)),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}