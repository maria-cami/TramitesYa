import 'package:flutter/material.dart';

void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? scheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Estado de error con botón de reintentar (HU07: "mensaje de error con opción de reintentar").
class ErrorReintentar extends StatelessWidget {
  const ErrorReintentar({
    super.key,
    required this.onReintentar,
    this.mensaje = 'No pudimos cargar la información',
  });

  final VoidCallback onReintentar;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 44, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Chip de color según el estado del pedido.
class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.etiqueta, required this.color});

  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        etiqueta,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
