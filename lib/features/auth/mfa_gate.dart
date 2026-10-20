import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../data/repositories.dart';
import 'mfa_setup_screen.dart';
import 'mfa_verify_screen.dart';

/// Puerta de la verificación en dos pasos. Con sesión iniciada decide:
///  - sin autenticador registrado → pantalla para configurarlo,
///  - con autenticador pero sin haber escrito el código en esta sesión → pide el código,
///  - todo en orden → muestra [child].
class MfaGate extends ConsumerWidget {
  const MfaGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoMfaProvider);
    return estado.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        body: SafeArea(
          child: ErrorReintentar(onReintentar: () => ref.invalidate(estadoMfaProvider)),
        ),
      ),
      data: (e) => switch (e) {
        EstadoMfa.ok => child,
        EstadoMfa.verificar => const MfaVerifyScreen(),
        EstadoMfa.configurar => const MfaSetupScreen(),
      },
    );
  }
}
