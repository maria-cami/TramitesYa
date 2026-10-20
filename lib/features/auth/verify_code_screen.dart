import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/providers.dart';
import 'auth_scaffold.dart';

/// Paso 2 del registro: la persona escribe el código que llegó a su correo.
/// Si es correcto, Supabase abre sesión y el router la lleva a "crear contraseña".
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _form = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  bool _cargando = false;
  int _espera = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarConteo();
  }

  void _iniciarConteo() {
    _timer?.cancel();
    setState(() => _espera = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_espera <= 1) {
        t.cancel();
        setState(() => _espera = 0);
      } else {
        setState(() => _espera--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    if (_cargando || !_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authRepositoryProvider).verificarCodigo(widget.email, _codigo.text);
      // Con sesión abierta, el router redirige a /crear-contrasena.
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

  Future<void> _reenviar() async {
    try {
      await ref.read(authRepositoryProvider).reenviarCodigo(widget.email);
      if (!mounted) return;
      mostrarMensaje(context, 'Te enviamos un código nuevo');
      _iniciarConteo();
    } on AppException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } catch (_) {
      if (mounted) {
        mostrarMensaje(context, 'No hay conexión. Revisa tu internet', error: true);
      }
    }
  }

  String? _validar(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Escribe el código que te enviamos';
    if (t.length < 6 || t.length > 8) return 'El código tiene entre 6 y 8 dígitos';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      mostrarAtras: true,
      titulo: 'Revisa tu correo',
      subtitulo: 'Enviamos un código a ${widget.email}. Escríbelo para verificar tu cuenta.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _codigo,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w700),
              validator: _validar,
              onFieldSubmitted: (_) => _verificar(),
              decoration: const InputDecoration(
                labelText: 'Código de verificación',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _cargando ? null : _verificar,
              child: _cargando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Verificar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _espera == 0 ? _reenviar : null,
              child: Text(_espera == 0 ? 'Reenviar código' : 'Reenviar código en $_espera s'),
            ),
            TextButton(
              onPressed: () => context.go('/registro'),
              child: const Text('Cambiar mi correo'),
            ),
          ],
        ),
      ),
    );
  }
}
