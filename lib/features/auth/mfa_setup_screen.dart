import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../data/providers.dart';
import '../../data/repositories.dart';
import 'auth_scaffold.dart';

/// Registro de la app de autenticación (Google Authenticator, Authy, etc.).
/// [obligatorio] = true cuando la puerta lo exige (no hay botón de volver, solo salir).
class MfaSetupScreen extends ConsumerStatefulWidget {
  const MfaSetupScreen({super.key, this.obligatorio = true});

  final bool obligatorio;

  @override
  ConsumerState<MfaSetupScreen> createState() => _MfaSetupScreenState();
}

class _MfaSetupScreenState extends ConsumerState<MfaSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  MfaEnrolamiento? _datos;
  String? _errorCarga;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    setState(() {
      _datos = null;
      _errorCarga = null;
    });
    try {
      final d = await ref.read(authRepositoryProvider).iniciarMfa();
      if (mounted) setState(() => _datos = d);
    } on AppException catch (e) {
      if (mounted) setState(() => _errorCarga = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _errorCarga = 'No hay conexión. Revisa tu internet');
    }
  }

  Future<void> _activar() async {
    final datos = _datos;
    if (_cargando || datos == null || !_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authRepositoryProvider).confirmarMfa(datos.factorId, _codigo.text);
      ref
        ..invalidate(estadoMfaProvider)
        ..invalidate(mfaActivoProvider);
      if (!mounted) return;
      mostrarMensaje(context, '¡Listo! Verificación en dos pasos activada');
      if (!widget.obligatorio) Navigator.of(context).pop();
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
    final datos = _datos;
    return AuthScaffold(
      mostrarAtras: !widget.obligatorio,
      titulo: 'Protege tu cuenta',
      subtitulo: 'Activa la verificación en dos pasos con una app de autenticación.',
      child: _errorCarga != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_errorCarga!),
                const SizedBox(height: 12),
                FilledButton(onPressed: _iniciar, child: const Text('Reintentar')),
                if (widget.obligatorio)
                  TextButton(
                    onPressed: () => ref.read(authRepositoryProvider).cerrarSesion(),
                    child: const Text('Salir'),
                  ),
              ],
            )
          : datos == null
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '1. Instala Google Authenticator, Microsoft Authenticator o Authy en tu celular.',
                      ),
                      const SizedBox(height: 14),
                      const Text('2. Escanea este código QR con la app:'),
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: QrImageView(data: datos.uri, size: 190),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('¿No puedes escanearlo? Escribe esta clave en la app:',
                          style: Theme.of(context).textTheme.bodySmall),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              datos.secreto,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copiar clave',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: datos.secreto));
                              if (context.mounted) mostrarMensaje(context, 'Clave copiada');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text('3. Escribe el código de 6 dígitos que muestra la app:'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _codigo,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                            fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w700),
                        validator: (v) => (v ?? '').trim().length == 6
                            ? null
                            : 'Escribe los 6 dígitos del código',
                        onFieldSubmitted: (_) => _activar(),
                        decoration: const InputDecoration(labelText: 'Código', counterText: ''),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _cargando ? null : _activar,
                        child: _cargando
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Activar'),
                      ),
                      if (widget.obligatorio) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.read(authRepositoryProvider).cerrarSesion(),
                          child: const Text('Salir'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
