import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/format.dart';
import 'models.dart';

/// Qué debe hacer la persona con la verificación en dos pasos al entrar.
enum EstadoMfa { ok, verificar, configurar }

/// Datos para registrar la app de autenticación (QR y clave manual).
class MfaEnrolamiento {
  MfaEnrolamiento({required this.factorId, required this.uri, required this.secreto});
  final String factorId;
  final String uri;
  final String secreto;
}

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
    bool esAyudante = false,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'nombre_completo': nombre.trim(),
          'telefono': telefono.replaceAll(RegExp(r'[\s-]'), ''),
          // El servidor solo acepta 'ayudante'; nunca 'admin' (ver handle_new_user).
          'rol': esAyudante ? 'ayudante' : 'usuario',
        },
      );
      return res.session != null;
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  /// Registro sin contraseña: Supabase crea la cuenta y envía un código por
  /// correo. La persona define su contraseña después de verificar el código.
  Future<void> iniciarRegistro({
    required String email,
    required String nombre,
    required String telefono,
    bool esAyudante = false,
  }) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: true,
        data: {
          'nombre_completo': nombre.trim(),
          'telefono': telefono.replaceAll(RegExp(r'[\s-]'), ''),
          'rol': esAyudante ? 'ayudante' : 'usuario',
          // Mientras sea true, el router obliga a crear la contraseña.
          'debe_crear_password': true,
        },
      );
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  Future<void> reenviarCodigo(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email.trim(), shouldCreateUser: true);
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  /// Si el código es correcto, Supabase abre sesión (el router la redirige a
  /// "crear contraseña" mientras debe_crear_password sea true).
  Future<void> verificarCodigo(String email, String codigo) async {
    try {
      await _client.auth.verifyOTP(
        email: email.trim(),
        token: codigo.trim(),
        type: OtpType.email,
      );
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  /// Verifica el código de recuperación de contraseña (abre una sesión temporal
  /// para poder definir la contraseña nueva).
  Future<void> verificarCodigoRecuperacion(String email, String codigo) async {
    try {
      await _client.auth.verifyOTP(
        email: email.trim(),
        token: codigo.trim(),
        type: OtpType.recovery,
      );
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  Future<void> crearPassword(String password) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: password, data: {'debe_crear_password': false}),
      );
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  // ---- Verificación en dos pasos (TOTP) ----

  Future<bool> tieneMfa() async {
    try {
      final factores = await _client.auth.mfa.listFactors();
      return factores.totp.isNotEmpty;
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  Future<EstadoMfa> estadoMfa() async {
    try {
      final factores = await _client.auth.mfa.listFactors();
      if (factores.totp.isEmpty) {
        return AppConfig.exigirDosPasos ? EstadoMfa.configurar : EstadoMfa.ok;
      }
      final nivel = _client.auth.mfa.getAuthenticatorAssuranceLevel();
      return nivel.currentLevel == AuthenticatorAssuranceLevels.aal2
          ? EstadoMfa.ok
          : EstadoMfa.verificar;
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  Future<MfaEnrolamiento> iniciarMfa() async {
    try {
      final res = await _client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'TrámitesYa',
        // Nombre único: si la persona recarga la pantalla no choca con intentos previos.
        friendlyName: 'App ${DateTime.now().millisecondsSinceEpoch}',
      );
      final totp = res.totp;
      if (totp == null) throw AppException('No se pudo generar el código QR');
      return MfaEnrolamiento(factorId: res.id, uri: totp.uri, secreto: totp.secret);
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  /// Confirma el registro de la app con el primer código que muestra.
  Future<void> confirmarMfa(String factorId, String codigo) async {
    try {
      await _client.auth.mfa.challengeAndVerify(factorId: factorId, code: codigo.trim());
    } on AuthException catch (e) {
      throw AppException(_mensaje(e));
    }
  }

  /// Segundo paso al iniciar sesión: valida el código de la app.
  Future<void> verificarMfa(String codigo) async {
    try {
      final factores = await _client.auth.mfa.listFactors();
      if (factores.totp.isEmpty) throw AppException('No tienes la verificación activada');
      await _client.auth.mfa.challengeAndVerify(
        factorId: factores.totp.first.id,
        code: codigo.trim(),
      );
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
    if (m.contains('after') && m.contains('seconds')) {
      return 'Espera un minuto antes de pedir otro código';
    }
    if (m.contains('token has expired') || m.contains('otp')) {
      return 'El código es incorrecto o ya venció';
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
        .select('nombre_completo, telefono, role')
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

  /// Estado del pedido en vivo (realtime). Emite un valor cada vez que cambia.
  Stream<String> estadoPedido(String pedidoId) {
    return _client
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .eq('id', pedidoId)
        .where((filas) => filas.isNotEmpty)
        .map((filas) => filas.first['estado'] as String);
  }

  /// Nombre del ayudante asignado al pedido (null si no hay o no se puede leer).
  Future<String?> nombreAyudante(String pedidoId) async {
    try {
      final p = await _client
          .from('pedidos')
          .select('ayudante_id')
          .eq('id', pedidoId)
          .maybeSingle();
      final id = p?['ayudante_id'] as String?;
      if (id == null) return null;
      final perfil = await _client
          .from('profiles')
          .select('nombre_completo')
          .eq('id', id)
          .maybeSingle();
      return perfil?['nombre_completo'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- Ayudante

  /// Pedidos que están buscando ayudante (la política RLS solo los muestra a ayudantes).
  Future<List<Pedido>> pedidosDisponibles() async {
    final res = await _client
        .from('pedidos')
        .select(Pedido.select)
        .eq('estado', EstadoPedido.buscandoAyudante)
        .order('created_at', ascending: true);
    return res.map<Pedido>(Pedido.fromJson).toList();
  }

  /// Servicios que este ayudante aceptó (en curso y terminados).
  Future<List<Pedido>> misServicios() async {
    final res = await _client
        .from('pedidos')
        .select(Pedido.select)
        .eq('ayudante_id', _uid)
        .order('updated_at', ascending: false);
    return res.map<Pedido>(Pedido.fromJson).toList();
  }

  /// Un pedido visto por el ayudante: disponible o asignado a él (RLS filtra el resto).
  Future<Pedido> pedidoDeAyudante(String id) async {
    final res = await _client.from('pedidos').select(Pedido.select).eq('id', id).single();
    return Pedido.fromJson(res);
  }

  Future<void> _rpcAyudante(String funcion, String pedidoId) async {
    try {
      await _client.rpc(funcion, params: {'p_pedido_id': pedidoId});
    } on PostgrestException catch (e) {
      throw AppException(_mensajeDb(e));
    }
  }

  Future<void> aceptarPedido(String id) => _rpcAyudante('aceptar_pedido', id);
  Future<void> soltarPedido(String id) => _rpcAyudante('soltar_pedido', id);
  Future<void> marcarRecogido(String id) => _rpcAyudante('marcar_recogido', id);
  Future<void> marcarEntregado(String id) => _rpcAyudante('marcar_entregado', id);

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