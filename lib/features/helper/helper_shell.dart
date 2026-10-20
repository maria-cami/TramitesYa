import 'package:flutter/material.dart';

import '../account/account_tab.dart';
import 'available_tab.dart';
import 'my_jobs_tab.dart';

/// Contenedor del ayudante: Disponibles · Mis servicios · Cuenta (saldo y cierre de sesión).
class HelperShell extends StatefulWidget {
  const HelperShell({super.key});

  @override
  State<HelperShell> createState() => _HelperShellState();
}

class _HelperShellState extends State<HelperShell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _indice,
          children: const [AvailableTab(), MyJobsTab(), AccountTab()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Disponibles',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Mis servicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}
