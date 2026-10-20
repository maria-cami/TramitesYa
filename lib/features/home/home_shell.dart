import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../account/account_tab.dart';
import '../orders/orders_tab.dart';
import 'home_tab.dart';

/// Marcador de posición: el chat con el ayudante llega con la fase del ayudante.
class _MensajesTab extends StatelessWidget {
  const _MensajesTab();

  @override
  Widget build(BuildContext context) {
    return const EstadoVacio(
      icono: Icons.chat_bubble_outline,
      texto: 'Aquí chatearás con tu ayudante cuando tu pedido esté en curso. Próximamente.',
    );
  }
}

/// Contenedor con la barra de navegación inferior (Inicio · Mis pedidos · Mensajes · Cuenta).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _indice,
          children: const [HomeTab(), OrdersTab(), _MensajesTab(), AccountTab()],
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
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Mis pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Mensajes',
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
