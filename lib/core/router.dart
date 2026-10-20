import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/account/not_found_screen.dart';
import '../features/auth/create_password_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/mfa_gate.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/verify_code_screen.dart';
import '../features/helper/helper_order_screen.dart';
import '../features/home/role_gate.dart';
import '../features/orders/new_order_screen.dart';
import '../features/orders/order_detail_screen.dart';

const _rutasPublicas = {'/login', '/registro', '/verificar', '/recuperar'};
const _rutaCrearPassword = '/crear-contrasena';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = Supabase.instance.client.auth;
  final refresh = _AuthRefresh(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/inicio',
    refreshListenable: refresh,
    // Sin sesión solo se ve lo público. Con sesión pero sin contraseña creada
    // (registro nuevo), se obliga a pasar por /crear-contrasena antes de entrar.
    redirect: (context, state) {
      final conSesion = auth.currentSession != null;
      final esPublica = _rutasPublicas.contains(state.matchedLocation);
      final enCrearPassword = state.matchedLocation == _rutaCrearPassword;
      final debeCrearPassword =
          conSesion && auth.currentUser?.userMetadata?['debe_crear_password'] == true;

      if (!conSesion) return (esPublica) ? null : '/login';
      if (debeCrearPassword) return enCrearPassword ? null : _rutaCrearPassword;
      if (esPublica || enCrearPassword) return '/inicio';
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/registro', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/verificar',
        builder: (_, state) =>
            VerifyCodeScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(path: _rutaCrearPassword, builder: (_, __) => const CreatePasswordScreen()),
      GoRoute(path: '/recuperar', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/inicio',
        builder: (_, __) => const MfaGate(child: RoleGate()),
      ),
      GoRoute(
        path: '/servicio/:id',
        builder: (_, state) => HelperOrderScreen(pedidoId: state.pathParameters['id']!),
      ),
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
