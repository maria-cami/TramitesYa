import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/providers.dart';
import 'auth_scaffold.dart';

/// Segundo paso al iniciar sesión: código de 6 dígitos de la app de autenticación.
class MfaVerifyScreen extends ConsumerStatefulWidget {
  const MfaVerifyScreen({super.key});

  @override
  ConsumerState<MfaVerifyScreen> createState() => _MfaVerifyScreenState();
}

class _MfaVerifyScreenState extends ConsumerState<MfaVerifyScreen> {
  final _form = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    if (_cargando || !_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authRepositoryProvider).verificarMfa(_codigo.text);
      // La sesión sube a nivel aal2; al recalcular el estado la puerta deja pasar.
      ref.invalidate(estadoMfaProvider);
    } on AppException catch (e) {
      if (mounted) {
        _codigo.clear();
        mostrarMensaje(context, e.mensaje, error: true);
      }
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
      titulo: 'Verificación en dos pasos',
      subtitulo:
          'Abre tu app de autenticación y escribe el código de 6 dígitos de TrámitesYa. Cambia cada 30 segundos.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _codigo,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w700),
              validator: (v) =>
                  (v ?? '').trim().length == 6 ? null : 'Escribe los 6 dígitos del código',
              onFieldSubmitted: (_) => _verificar(),
              decoration: const InputDecoration(labelText: 'Código', counterText: ''),
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
              onPressed: () => ref.read(authRepositoryProvider).cerrarSesion(),
              child: const Text('Salir'),
            ),
          ],
        ),
      ),
    );
  }
}
