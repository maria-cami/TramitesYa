import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';
import 'models.dart';

/// Autenticación (HU01–HU05) sobre Supabase Auth.
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  /// Devuelve true si quedó con sesión iniciada; false si Supabase exige
  /// confirmar el correo primero.
  Future<bool> registrar({
    required String email,
    required String password,
    required String nombre,
    required String telefono,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'nombre_completo': nombre.trim(),
          'telefono': telefono.replaceAll(RegExp(r'[\s-]'), ''),
        },
      );
      return res.session != null;
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  Future<void> iniciarSesion(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  Future<void> cerrarSesion() => _client.auth.signOut();

  Future<void> recuperarPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

    String _mensaje(AuthException e) {
    // TEMPORAL: ver el error real en la terminal mientras probamos
    // ignore: avoid_print
    print('AUTH ERROR -> status: ${e.statusCode} | message: ${e.message}');
    final m = e.message.toLowerCase();
    // HU02: mensaje genérico, sin revelar si el correo existe.
    if (m.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos';
    }
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'Ya existe una cuenta asociada a ese correo';
    }
    if (m.contains('email not confirmed')) {
      return 'Debes confirmar tu correo antes de iniciar sesión';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo';
    }
    if (m.contains('password')) {
      return 'La contraseña no cumple los requisitos de seguridad';
    }
    return 'No se pudo completar la acción. Inténtalo de nuevo';
  }
}

/// Catálogo, pedidos y billetera del usuario.
class AppRepository {
  AppRepository(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw AppException('Tu sesión expiró. Inicia sesión de nuevo');
    return id;
  }

  Future<Map<String, dynamic>> perfil() async {
    final res = await _client
        .from('profiles')
        .select('nombre_completo, telefono')
        .eq('id', _uid)
        .single();
    return res;
  }

  Future<List<Tramite>> tramites() async {
    final res = await _client
        .from('catalogo_tramites')
        .select('id, nombre, categoria, icono, tarifas(valor, vigente_desde)')
        .eq('activo', true)
        .order('nombre');
    return res.map<Tramite>(Tramite.fromJson).toList();
  }

  Future<List<Pedido>> pedidos() async {
    final res = await _client
        .from('pedidos')
        .select(Pedido.select)
        .eq('usuario_id', _uid)
        .order('created_at', ascending: false);
    return res.map<Pedido>(Pedido.fromJson).toList();
  }

  Future<Pedido> pedido(String id) async {
    final res = await _client
        .from('pedidos')
        .select(Pedido.select)
        .eq('id', id)
        .eq('usuario_id', _uid)
        .single();
    return Pedido.fromJson(res);
  }

  /// HU16: crea el pedido y la transacción pendiente. Reintentar con la misma
  /// [idempotencyKey] devuelve el mismo pedido (no cobra dos veces).
  Future<String> crearPedido({
    required String tramiteId,
    required String descripcion,
    String? notas,
    required String recogidaDireccion,
    String? recogidaReferencia,
    required String entregaDireccion,
    String? entregaReferencia,
    required String idempotencyKey,
  }) async {
    try {
      final res = await _client.rpc('crear_pedido', params: {
        'p_tramite_id': tramiteId,
        'p_descripcion': descripcion,
        'p_notas': notas,
        'p_recogida_direccion': recogidaDireccion,
        'p_recogida_referencia': recogidaReferencia,
        'p_entrega_direccion': entregaDireccion,
        'p_entrega_referencia': entregaReferencia,
        'p_idempotency_key': idempotencyKey,
      });
      return (res as Map<String, dynamic>)['id'] as String;
    } on PostgrestException catch (e) {
      throw AppException(_mensajeDb(e));
    }
  }

  /// SOLO SANDBOX: ver comentario en supabase/schema.sql. Se reemplaza por el
  /// checkout de Wompi + webhook cuando se conecte la pasarela.
  Future<void> simularPago(String pedidoId) async {
    try {
      await _client.rpc('simular_pago', params: {'p_pedido_id': pedidoId});
    } on PostgrestException catch (e) {
      throw AppException(_mensajeDb(e));
    }
  }

  Future<void> cancelarPedido(String pedidoId, String motivo) async {
    try {
      await _client.rpc('cancelar_pedido', params: {
        'p_pedido_id': pedidoId,
        'p_motivo': motivo,
      });
    } on PostgrestException catch (e) {
      throw AppException(_mensajeDb(e));
    }
  }

  Future<num> saldo() async {
    final res = await _client
        .from('billeteras')
        .select('saldo')
        .eq('profile_id', _uid)
        .maybeSingle();
    return res == null ? 0 : num.parse(res['saldo'].toString());
  }

  Future<List<Movimiento>> movimientos() async {
    final res = await _client
        .from('transacciones')
        .select('id, tipo, estado, monto, created_at')
        .eq('profile_id', _uid)
        .order('created_at', ascending: false)
        .limit(20);
    return res.map<Movimiento>(Movimiento.fromJson).toList();
  }

  /// Los mensajes que lanzamos con `raise exception` en SQL son aptos para el
  /// usuario; cualquier otro error de Postgres se oculta tras un mensaje genérico.
  String _mensajeDb(PostgrestException e) {
    if (e.code == 'P0001') return e.message;
    return 'No se pudo completar la operación. Inténtalo de nuevo';
  }
}
