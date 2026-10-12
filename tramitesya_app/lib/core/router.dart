import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/account/not_found_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/home_shell.dart';
import '../features/orders/new_order_screen.dart';
import '../features/orders/order_detail_screen.dart';

const _rutasPublicas = {'/login', '/registro', '/recuperar'};

final routerProvider = Provider<GoRouter>((ref) {
  final auth = Supabase.instance.client.auth;
  final refresh = _AuthRefresh(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/inicio',
    refreshListenable: refresh,
    // Sin sesión solo se ve login/registro/recuperar; con sesión no se vuelve a ellos.
    redirect: (context, state) {
      final conSesion = auth.currentSession != null;
      final esPublica = _rutasPublicas.contains(state.matchedLocation);
      if (!conSesion && !esPublica) return '/login';
      if (conSesion && esPublica) return '/inicio';
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/registro', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/recuperar', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/inicio', builder: (_, __) => const HomeShell()),
      GoRoute(
        path: '/nuevo-pedido',
        builder: (_, state) =>
            NewOrderScreen(tramiteId: state.uri.queryParameters['tramite']),
      ),
      GoRoute(
        path: '/pedido/:id',
        builder: (_, state) => OrderDetailScreen(pedidoId: state.pathParameters['id']!),
      ),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
