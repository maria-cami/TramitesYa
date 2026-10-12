import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/validators.dart';
import '../../data/providers.dart';
import 'auth_scaffold.dart';

/// HU01 — Registro de usuario.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  bool _terminos = false;
  bool _cargando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _telefono.dispose();
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (_cargando || !_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final conSesion = await ref.read(authRepositoryProvider).registrar(
            email: _email.text,
            password: _password.text,
            nombre: _nombre.text,
            telefono: _telefono.text,
          );
      if (!mounted) return;
      if (!conSesion) {
        // Supabase tiene activada la confirmación por correo.
        mostrarMensaje(context, 'Cuenta creada. Revisa tu correo para confirmarla');
        context.go('/login');
      }
      // Con sesión, el router redirige a /inicio.
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
      titulo: 'Crea tu cuenta',
      subtitulo: 'Solo toma un minuto.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: Validators.nombre,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: Validators.telefono,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                hintText: '+57 300 123 4567',
              ),
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _password,
              label: 'Contraseña',
              validator: Validators.password,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Mínimo 8 caracteres, una mayúscula y un número.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirmar,
              label: 'Confirmar contraseña',
              validator: (v) => Validators.confirmar(v, _password.text),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _terminos,
              onChanged: (v) => setState(() => _terminos = v ?? false),
              title: const Text('Acepto los términos y condiciones'),
            ),
            const SizedBox(height: 8),
            // HU01: el botón permanece deshabilitado hasta aceptar los términos.
            FilledButton(
              onPressed: (_cargando || !_terminos) ? null : _registrar,
              child: _cargando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
