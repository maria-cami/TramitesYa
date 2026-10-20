import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../data/providers.dart';
import 'auth_scaffold.dart';

/// HU01 — Registro de usuario o ayudante. No pide contraseña: se envía un código
/// al correo y la persona crea su contraseña después de verificarlo.
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
  bool _esAyudante = false;
  bool _terminos = false;
  bool _cargando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (_cargando || !_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final email = _email.text.trim();
      await ref.read(authRepositoryProvider).iniciarRegistro(
            email: email,
            nombre: _nombre.text,
            telefono: _telefono.text,
            esAyudante: _esAyudante,
          );
      if (!mounted) return;
      context.go(Uri(path: '/verificar', queryParameters: {'email': email}).toString());
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
      subtitulo: _esAyudante
          ? 'Gana dinero haciendo trámites para otras personas.'
          : 'Pide ayuda para tus trámites. Solo toma un minuto.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿Cómo quieres usar TrámitesYa?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: kBrand,
                selectedForegroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.person_outline),
                  label: Text('Usuario'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.directions_run),
                  label: Text('Ayudante'),
                ),
              ],
              selected: {_esAyudante},
              onSelectionChanged: (s) => setState(() => _esAyudante = s.first),
            ),
            const SizedBox(height: 18),
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
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: Validators.telefono,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                hintText: '+57 300 123 4567',
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.mail_outline, size: 18, color: kGris),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Te enviaremos un código a tu correo. Con él verificas tu cuenta y creas tu contraseña.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
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
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Enviarme el código'),
            ),
          ],
        ),
      ),
    );
  }
}
