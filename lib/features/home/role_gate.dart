import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../helper/helper_shell.dart';
import 'home_shell.dart';

/// Decide qué app ver según el rol del perfil: ayudante → HelperShell; el resto → HomeShell.
/// El rol lo fija el servidor (profiles.role); la app solo lo lee.
class RoleGate extends ConsumerWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilProvider);
    final datos = perfil.valueOrNull;

    if (datos != null) {
      return datos['role'] == 'ayudante' ? const HelperShell() : const HomeShell();
    }
    if (perfil.hasError) {
      return Scaffold(
        body: SafeArea(
          child: ErrorReintentar(onReintentar: () => ref.invalidate(perfilProvider)),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
