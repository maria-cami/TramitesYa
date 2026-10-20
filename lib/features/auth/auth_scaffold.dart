import 'package:flutter/material.dart';

import '../../core/theme.dart';

export '../../core/widgets.dart' show mostrarMensaje;

/// Contenedor común de las pantallas de acceso (login, registro, recuperar).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.child,
    this.mostrarAtras = false,
  });

  final String titulo;
  final String? subtitulo;
  final Widget child;
  final bool mostrarAtras;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: mostrarAtras ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!mostrarAtras) ...[
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [kBrand, Color(0xFFFF8A3D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(Icons.task_alt_rounded, size: 38, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'TrámitesYa',
                      textAlign: TextAlign.center,
                      style: textos.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: kBrand,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  Text(
                    titulo,
                    style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitulo!, style: textos.bodyMedium),
                  ],
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de contraseña con botón para mostrar/ocultar.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _oculto = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _oculto,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(_oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _oculto = !_oculto),
        ),
      ),
    );
  }
}
