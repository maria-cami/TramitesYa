import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';

/// Un pedido en la lista "últimos pedidos" del panel.
class PedidoReciente {
  PedidoReciente({
    required this.codigo,
    required this.estado,
    required this.valor,
    required this.creado,
  });

  final String codigo;
  final String estado;
  final num valor;
  final DateTime creado;

  factory PedidoReciente.fromJson(Map<String, dynamic> j) => PedidoReciente(
        codigo: (j['codigo'] ?? '') as String,
        estado: (j['estado'] ?? '') as String,
        valor: num.parse('${j['valor'] ?? 0}'),
        creado: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

/// Números que muestra el resumen del administrador.
class ResumenAdmin {
  ResumenAdmin({
    required this.usuarios,
    required this.ayudantes,
    required this.pedidosTotal,
    required this.pedidosHoy,
    required this.porEstado,
    required this.ingresos,
    required this.ingresosHoy,
    required this.pagadoAyudantes,
    required this.ultimos,
    this.planesActivos = 0, this.ingresosPlanesMes = 0,
  });

  final int usuarios;
  final int ayudantes;
  final int pedidosTotal;
  final int pedidosHoy;
  final Map<String, int> porEstado;
  final num ingresos;
  final num ingresosHoy;
  final num pagadoAyudantes;
  final List<PedidoReciente> ultimos;
  final int planesActivos;
  final num ingresosPlanesMes;

  /// Pedidos que aún no terminan (buscando ayudante, asignado o recogido).
  int get enCurso =>
      (porEstado['buscando_ayudante'] ?? 0) +
      (porEstado['asignado'] ?? 0) +
      (porEstado['recogido'] ?? 0);

  factory ResumenAdmin.fromJson(Map<String, dynamic> j) {
    int entero(String k) => int.parse('${j[k] ?? 0}');
    num numero(String k) => num.parse('${j[k] ?? 0}');
    final estados = Map<String, dynamic>.from((j['por_estado'] ?? {}) as Map);
    final ultimos = List<Map<String, dynamic>>.from(
      ((j['ultimos'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    return ResumenAdmin(
      usuarios: entero('usuarios'),
      ayudantes: entero('ayudantes'),
      pedidosTotal: entero('pedidos_total'),
      pedidosHoy: entero('pedidos_hoy'),
      porEstado: {for (final e in estados.entries) e.key: int.parse('${e.value}')},
      ingresos: numero('ingresos'),
      ingresosHoy: numero('ingresos_hoy'),
      pagadoAyudantes: numero('pagado_ayudantes'),
      ultimos: ultimos.map(PedidoReciente.fromJson).toList(),
      planesActivos: entero('planes_activos'),
      ingresosPlanesMes: numero('ingresos_planes_mes'),
    );
  }
}

/// Un pedido en la lista de "Pedidos" del administrador.
class PedidoAdmin {
  PedidoAdmin({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.valor,
    required this.creado,
    required this.tramite,
    required this.usuario,
    required this.ayudante,
    required this.recogida,
    required this.entrega,
    required this.motivo,
  });

  final String id;
  final String codigo;
  final String estado;
  final num valor;
  final DateTime creado;
  final String tramite;
  final String usuario;
  final String? ayudante;
  final String recogida;
  final String entrega;
  final String? motivo;

  factory PedidoAdmin.fromJson(Map<String, dynamic> j) => PedidoAdmin(
        id: j['id'] as String,
        codigo: (j['codigo'] ?? '') as String,
        estado: (j['estado'] ?? '') as String,
        valor: num.parse('${j['valor'] ?? 0}'),
        creado: DateTime.parse(j['created_at'] as String).toLocal(),
        tramite: (j['tramite'] ?? '') as String,
        usuario: (j['usuario'] ?? 'Sin nombre') as String,
        ayudante: j['ayudante'] as String?,
        recogida: (j['recogida_direccion'] ?? '') as String,
        entrega: (j['entrega_direccion'] ?? '') as String,
        motivo: j['motivo_cancelacion'] as String?,
      );
}

/// Un usuario o ayudante en las listas del administrador.
class PersonaAdmin {
  PersonaAdmin({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.email,
    required this.bloqueado,
    required this.creado,
    required this.pedidos,
  });

  final String id;
  final String nombre;
  final String? telefono;
  final String email;
  final bool bloqueado;
  final DateTime creado;

  /// Usuario: pedidos creados. Ayudante: servicios entregados.
  final int pedidos;

  factory PersonaAdmin.fromJson(Map<String, dynamic> j) => PersonaAdmin(
        id: j['id'] as String,
        nombre: (j['nombre'] ?? 'Sin nombre') as String,
        telefono: j['telefono'] as String?,
        email: (j['email'] ?? '') as String,
        bloqueado: (j['bloqueado'] ?? false) as bool,
        creado: DateTime.parse(j['created_at'] as String).toLocal(),
        pedidos: int.parse('${j['pedidos'] ?? 0}'),
      );
}

/// Un trámite del catálogo con su valor vigente.
class TramiteAdmin {
  TramiteAdmin({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.activo,
    required this.valor,
  });

  final String id;
  final String nombre;
  final String? categoria;
  final bool activo;
  final num valor;

  factory TramiteAdmin.fromJson(Map<String, dynamic> j) => TramiteAdmin(
        id: j['id'] as String,
        nombre: (j['nombre'] ?? '') as String,
        categoria: j['categoria'] as String?,
        activo: (j['activo'] ?? true) as bool,
        valor: num.parse('${j['valor'] ?? 0}'),
      );
}

/// Consultas del administrador. El servidor valida el rol en cada función.
class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  Future<dynamic> _rpc(String funcion, [Map<String, dynamic>? params]) async {
    try {
      return await _client.rpc(funcion, params: params);
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') throw AppException(e.message);
      throw AppException('No se pudo completar la acción. Inténtalo de nuevo');
    }
  }

  List<Map<String, dynamic>> _lista(dynamic res) => List<Map<String, dynamic>>.from(
        ((res ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );

  Future<ResumenAdmin> resumen() async {
    final res = await _rpc('admin_resumen');
    return ResumenAdmin.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// [estado] vacío = todos.
  Future<List<PedidoAdmin>> pedidos(String estado) async {
    final res = await _rpc('admin_pedidos', {'p_estado': estado.isEmpty ? null : estado});
    return _lista(res).map(PedidoAdmin.fromJson).toList();
  }

  /// [rol]: 'usuario' o 'ayudante'.
  Future<List<PersonaAdmin>> personas(String rol) async {
    final res = await _rpc('admin_personas', {'p_rol': rol});
    return _lista(res).map(PersonaAdmin.fromJson).toList();
  }

  Future<void> bloquear(String id, bool bloqueado) =>
      _rpc('admin_bloquear', {'p_id': id, 'p_bloqueado': bloqueado});

  Future<List<TramiteAdmin>> catalogo() async {
    final res = await _rpc('admin_catalogo');
    return _lista(res).map(TramiteAdmin.fromJson).toList();
  }

  /// [id] null = crear trámite nuevo.
  Future<void> guardarTramite({
    String? id,
    required String nombre,
    String? categoria,
    required num valor,
    required bool activo,
  }) =>
      _rpc('admin_guardar_tramite', {
        'p_id': id,
        'p_nombre': nombre,
        'p_categoria': categoria,
        'p_valor': valor,
        'p_activo': activo,
      });
}