import 'package:flutter/material.dart';

import '../account/account_tab.dart';
import 'available_tab.dart';
import 'earnings_tab.dart';
import 'my_jobs_tab.dart';

/// Contenedor del ayudante: Inicio · Servicios · Ganancias · Perfil.
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
          children: const [AvailableTab(), MyJobsTab(), EarningsTab(), AccountTab()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Servicios',
          ),
           NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}