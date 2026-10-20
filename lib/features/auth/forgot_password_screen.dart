import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/validators.dart';
import '../../data/providers.dart';
import 'auth_scaffold.dart';

/// HU03 — Solicitud de recuperación de contraseña.
/// Nota: el enlace del correo abre el flujo de "nueva contraseña", que requiere
/// configurar un deep link (pendiente en la guía del README).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _cargando = false;
  bool _enviado = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_cargando || !_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authRepositoryProvider).recuperarPassword(_email.text);
      if (mounted) setState(() => _enviado = true);
    } on AppException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } catch (_) {
      if (mounted) {
        mostrarMensaje(context, 'No hay conexión. Revisa tu internet', error: true);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      mostrarAtras: true,
      titulo: 'Recupera tu contraseña',
      subtitulo: 'Te enviaremos un enlace para crear una nueva.',
      child: _enviado
          ? const Text(
              'Si el correo está registrado, recibirás un enlace en unos minutos. '
              'Revisa también la carpeta de spam.',
            )
          : Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: Validators.email,
                    onFieldSubmitted: (_) => _enviar(),
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _cargando ? null : _enviar,
                    child: _cargando
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Enviar enlace'),
                  ),
                ],
              ),
            ),
    );
  }
}
