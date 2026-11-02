import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Logo cuadrado naranja del panel.
class LogoAdmin extends StatelessWidget {
  const LogoAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: kBrand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 22),
    );
  }
}

/// Marco común de cada sección: título, acción opcional, ancho máximo y recargar.
class PaginaAdmin extends StatelessWidget {
  const PaginaAdmin({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.accion,
    required this.onRefresh,
    required this.hijos,
  });

  final String titulo;
  final String? subtitulo;
  final Widget? accion;
  final Future<void> Function() onRefresh;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    final ancha = MediaQuery.sizeOf(context).width >= 900;
    final textos = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: EdgeInsets.all(ancha ? 32 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                style: textos.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (subtitulo != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitulo!,
                                  style: textos.bodyMedium?.copyWith(color: kGris),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (accion != null) accion!,
                      ],
                    ),
                    const SizedBox(height: 20),
                    ...hijos,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}