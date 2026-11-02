import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import 'admin_catalog_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_orders_tab.dart';
import 'admin_people_tab.dart';
import 'admin_widgets.dart';

/// Panel del administrador. El rol lo fija el servidor (profiles.role = 'admin').
/// Pantalla ancha: menú lateral de 240 px. Celular: barra superior + navegación inferior.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _indice = 0;

  static const _secciones = <(IconData, IconData, String)>[
    (Icons.dashboard_outlined, Icons.dashboard, 'Resumen'),
    (Icons.assignment_outlined, Icons.assignment, 'Pedidos'),
    (Icons.people_outline, Icons.people, 'Usuarios'),
    (Icons.directions_run_outlined, Icons.directions_run, 'Ayudantes'),
    (Icons.tune_outlined, Icons.tune, 'Trámites'),
  ];

  Future<void> _salir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar tu sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authRepositoryProvider).cerrarSesion();
  }

  Widget _contenido() => switch (_indice) {
        0 => const AdminDashboardTab(),
        1 => const AdminOrdersTab(),
        2 => const AdminPeopleTab(key: ValueKey('usuario'), rol: 'usuario'),
        3 => const AdminPeopleTab(key: ValueKey('ayudante'), rol: 'ayudante'),
        _ => const AdminCatalogTab(),
      };

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(supabaseProvider).auth.currentUser?.email ?? '';
    final ancha = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: kFondo,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ancha)
            _Lateral(
              email: email,
              indice: _indice,
              onElegir: (i) => setState(() => _indice = i),
              onSalir: _salir,
            ),
          Expanded(
            child: Column(
              children: [
                if (!ancha) _BarraSuperior(onSalir: _salir),
                Expanded(child: _contenido()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ancha
          ? null
          : NavigationBar(
              selectedIndex: _indice,
              onDestinationSelected: (i) => setState(() => _indice = i),
              destinations: [
                for (final s in _secciones)
                  NavigationDestination(
                    icon: Icon(s.$1),
                    selectedIcon: Icon(s.$2),
                    label: s.$3,
                  ),
              ],
            ),
    );
  }
}

/// Menú lateral (pantallas anchas).
class _Lateral extends StatelessWidget {
  const _Lateral({
    required this.email,
    required this.indice,
    required this.onElegir,
    required this.onSalir,
  });

  final String email;
  final int indice;
  final ValueChanged<int> onElegir;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: kNavy,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  LogoAdmin(),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'TrámitesYa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              for (var i = 0; i < _AdminShellState._secciones.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _ItemMenu(
                    icono: i == indice
                        ? _AdminShellState._secciones[i].$2
                        : _AdminShellState._secciones[i].$1,
                    texto: _AdminShellState._secciones[i].$3,
                    activo: i == indice,
                    onTap: () => onElegir(i),
                  ),
                ),
              const Spacer(),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                ),
                onPressed: onSalir,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.icono,
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icono, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                texto,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra superior (celular).
class _BarraSuperior extends StatelessWidget {
  const _BarraSuperior({required this.onSalir});

  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorde)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              const LogoAdmin(),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Administración',
                  style: TextStyle(color: kNavy, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: onSalir,
                icon: const Icon(Icons.logout, color: kNavy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}