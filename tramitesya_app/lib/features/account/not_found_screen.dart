import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Esta pantalla no existe'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/inicio'),
              child: const Text('Ir al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}
