import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../auth/mfa_setup_screen.dart';

/// Perfil, saldo de la billetera (HU31), movimientos y cierre de sesión (HU05).
/// Recargar saldo (HU32) queda para cuando se conecte la pasarela de pagos.
class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  Future<void> _cerrarSesion(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    // Invalida el token en Supabase; el router redirige a /login.
    await ref.read(authRepositoryProvider).cerrarSesion();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilProvider);
    final saldo = ref.watch(saldoProvider);
    final movimientos = ref.watch(movimientosProvider);
    final email = ref.watch(supabaseProvider).auth.currentUser?.email ?? '';
    final textos = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(perfilProvider)
          ..invalidate(saldoProvider)
          ..invalidate(movimientosProvider);
        await ref.read(saldoProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kNavy, kNavy2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(Icons.person, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        perfil.valueOrNull?['nombre_completo'] as String? ?? 'Usuario',
                        style: textos.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if ((perfil.valueOrNull?['telefono'] as String?)?.isNotEmpty ?? false)
                        Text(perfil.valueOrNull!['telefono'] as String,
                            style: const TextStyle(color: Colors.white70)),
                      Text(email, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mi billetera',
                    style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo disponible', style: textos.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        saldo.when(
                          data: formatCop,
                          loading: () => '…',
                          error: (_, __) => 'No disponible',
                        ),
                        style: const TextStyle(
                          color: kBrand,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Seguridad',
                    style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const _DosPasosTile(),
                const SizedBox(height: 20),
          Text('Movimientos recientes',
              style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          movimientos.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => SizedBox(
              height: 180,
              child: ErrorReintentar(
                onReintentar: () => ref.invalidate(movimientosProvider),
              ),
            ),
            data: (lista) => lista.isEmpty
                ? const SizedBox(
                    height: 160,
                    child: EstadoVacio(
                      icono: Icons.account_balance_wallet_outlined,
                      texto: 'Aún no tienes movimientos.',
                    ),
                  )
                : Column(
                    children: [
                      for (final m in lista)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MovimientoTile(m),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _cerrarSesion(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DosPasosTile extends ConsumerWidget {
  const _DosPasosTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activo = ref.watch(mfaActivoProvider).valueOrNull;
    final textos = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          Icon(
            activo == true ? Icons.verified_user : Icons.shield_outlined,
            color: activo == true ? kVerde : kGris,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verificación en dos pasos',
                    style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(activo == true ? 'Activada' : 'Desactivada', style: textos.bodySmall),
              ],
            ),
          ),
          if (activo == false)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MfaSetupScreen(obligatorio: false),
                ),
              ),
              child: const Text('Activar'),
            ),
        ],
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile(this.m);

  final Movimiento m;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final estado = switch (m.estado) {
      'completed' => ('Completado', const Color(0xFF159A63)),
      'refunded' => ('Reembolsado', const Color(0xFFB7791F)),
      'failed' => ('Fallido', const Color(0xFFD64545)),
      _ => ('Pendiente', const Color(0xFF6B6B80)),
    };
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.etiqueta,
                    style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(formatFecha(m.createdAt), style: textos.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCop(m.monto),
                  style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              EstadoChip(etiqueta: estado.$1, color: estado.$2),
            ],
          ),
        ],
      ),
    );
  }
}
