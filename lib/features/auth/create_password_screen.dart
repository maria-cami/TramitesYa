import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/validators.dart';
import '../../data/providers.dart';
import 'auth_scaffold.dart';

/// Paso 3 del registro: la persona ya verificó su correo y define su contraseña.
/// El router mantiene aquí a quien tenga debe_crear_password = true.
class CreatePasswordScreen extends ConsumerStatefulWidget {
  const CreatePasswordScreen({super.key});

  @override
  ConsumerState<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends ConsumerState<CreatePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_cargando || !_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authRepositoryProvider).crearPassword(_password.text);
      if (mounted) mostrarMensaje(context, '¡Listo! Tu contraseña quedó creada');
      // userUpdated → el router redirige a /inicio.
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
      titulo: 'Crea tu contraseña',
      subtitulo: 'Tu correo ya está verificado. Define la contraseña con la que vas a entrar.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              onSubmitted: _guardar,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _cargando ? null : _guardar,
              child: _cargando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Guardar y entrar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(authRepositoryProvider).cerrarSesion(),
              child: const Text('Salir'),
            ),
          ],
        ),
      ),
    );
  }
}
