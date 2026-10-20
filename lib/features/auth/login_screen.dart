import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/validators.dart';
import '../../data/providers.dart';
import 'auth_scaffold.dart';

/// HU02 — Inicio de sesión.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_cargando || !_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authRepositoryProvider).iniciarSesion(_email.text, _password.text);
      // El router redirige solo a /inicio al detectar la sesión.
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
      titulo: 'Inicia sesión',
      subtitulo: 'Pide ayuda para cualquier trámite y despreocúpate.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _password,
              label: 'Contraseña',
              validator: Validators.passwordLogin,
              textInputAction: TextInputAction.done,
              onSubmitted: _entrar,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/recuperar'),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _cargando ? null : _entrar,
              child: _cargando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Iniciar sesión'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/registro'),
              child: const Text('Crear una cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
