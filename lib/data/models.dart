import 'package:flutter/material.dart';

/// Trámite del catálogo con su tarifa vigente (HU07).
class Tramite {
  const Tramite({
    required this.id,
    required this.nombre,
    this.categoria,
    this.icono,
    this.valor,
  });

  final String id;
  final String nombre;
  final String? categoria;
  final String? icono;
  final num? valor;

  factory Tramite.fromJson(Map<String, dynamic> j) {
    final ahora = DateTime.now();
    final tarifas = List<Map<String, dynamic>>.from(
      (j['tarifas'] as List?) ?? const [],
    ).where((t) => !DateTime.parse(t['vigente_desde'] as String).isAfter(ahora)).toList()
      ..sort((a, b) => (b['vigente_desde'] as String).compareTo(a['vigente_desde'] as String));

    return Tramite(
      id: j['id'] as String,
      nombre: j['nombre'] as String,
      categoria: j['categoria'] as String?,
      icono: j['icono'] as String?,
      valor: tarifas.isEmpty ? null : num.parse(tarifas.first['valor'].toString()),
    );
  }

  IconData get iconData => switch (icono) {
        'medicamentos' => Icons.medication_outlined,
        'banco' => Icons.account_balance_outlined,
        'recibos' => Icons.receipt_long_outlined,
        'documentos' => Icons.send_outlined,
        'entidades' => Icons.apartment_outlined,
        _ => Icons.more_horiz,
      };

  /// Color propio de cada trámite para el icono (estilo del mockup).
  Color get colorIcono => switch (icono) {
        'medicamentos' => const Color(0xFFF08A24),
        'banco' => const Color(0xFF5B3FD9),
        'recibos' => const Color(0xFF3B82F6),
        'documentos' => const Color(0xFFE0457B),
        'entidades' => const Color(0xFF159A63),
        _ => const Color(0xFF7C6FB0),
      };
}

/// Estados del pedido tal como existen en la base de datos.
class EstadoPedido {
  static const pendientePago = 'pendiente_pago';
  static const buscandoAyudante = 'buscando_ayudante';
  static const asignado = 'asignado';
  static const recogido = 'recogido';
  static const entregado = 'entregado';
  static const cancelado = 'cancelado';

  static const enCurso = {pendientePago, buscandoAyudante, asignado, recogido};

  /// Con ayudante y en curso: hay mapa y se puede escribir en el chat (HU20, HU23).
  static bool conAyudante(String estado) => estado == asignado || estado == recogido;

  static String etiqueta(String estado) => switch (estado) {
        pendientePago => 'Pendiente de pago',
        buscandoAyudante => 'Buscando ayudante',
        asignado => 'Ayudante asignado',
        recogido => 'Recogido',
        entregado => 'Completado',
        cancelado => 'Cancelado',
        _ => estado,
      };

  static Color color(String estado) => switch (estado) {
        entregado || recogido => const Color(0xFF10B981),
        cancelado => const Color(0xFFEF4444),
        asignado => const Color(0xFF2563EB),
        _ => const Color(0xFFF59E0B),
      };

  /// Se puede cancelar desde la app mientras no haya recogida (HU19).
  static bool cancelable(String estado) =>
      estado == pendientePago || estado == buscandoAyudante;
}

class Pedido {
  const Pedido({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.descripcion,
    required this.tramiteNombre,
    required this.valor,
    required this.recogidaDireccion,
    required this.entregaDireccion,
    required this.createdAt,
    this.ayudanteId,
    this.notas,
    this.recogidaReferencia,
    this.entregaReferencia,
    this.motivoCancelacion,
  });

  final String id;
  final String codigo;
  final String estado;
  final String descripcion;
  final String? notas;
  final String tramiteNombre;
  final num valor;
  final String recogidaDireccion;
  final String? recogidaReferencia;
  final String entregaDireccion;
  final String? entregaReferencia;
  final String? motivoCancelacion;
  final String? ayudanteId;
  final DateTime createdAt;

  /// Lo que gana el ayudante: 80 % de la tarifa (el 20 % es la comisión de ejemplo).
  num get pagoAyudante => (valor * 0.8).round();

  /// Consulta con embeds: `*, catalogo_tramites(nombre), tarifas(valor)`.
  static const select = '*, catalogo_tramites(nombre), tarifas(valor)';

  factory Pedido.fromJson(Map<String, dynamic> j) {
    final tramite = j['catalogo_tramites'] as Map<String, dynamic>?;
    final tarifa = j['tarifas'] as Map<String, dynamic>?;
    return Pedido(
      id: j['id'] as String,
      codigo: (j['codigo'] as String?) ?? '',
      estado: j['estado'] as String,
      descripcion: j['descripcion'] as String,
      notas: j['notas'] as String?,
      tramiteNombre: (tramite?['nombre'] as String?) ?? 'Trámite',
      valor: num.parse((tarifa?['valor'] ?? 0).toString()),
      recogidaDireccion: j['recogida_direccion'] as String,
      recogidaReferencia: j['recogida_referencia'] as String?,
      entregaDireccion: j['entrega_direccion'] as String,
      entregaReferencia: j['entrega_referencia'] as String?,
      motivoCancelacion: j['motivo_cancelacion'] as String?,
      ayudanteId: j['ayudante_id'] as String?,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

/// Último punto reportado por el ayudante para un pedido (HU20).
class UbicacionAyudante {
  const UbicacionAyudante({
    required this.lat,
    required this.lng,
    required this.updatedAt,
    this.precisionM,
  });

  final double lat;
  final double lng;
  final double? precisionM;
  final DateTime updatedAt;

  factory UbicacionAyudante.fromJson(Map<String, dynamic> j) => UbicacionAyudante(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        precisionM: (j['precision_m'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

class MensajeChat {
  const MensajeChat({
    required this.id,
    required this.autorId,
    required this.texto,
    required this.createdAt,
  });

  final String id;
  final String autorId;
  final String texto;
  final DateTime createdAt;

  factory MensajeChat.fromJson(Map<String, dynamic> j) => MensajeChat(
        id: j['id'] as String,
        autorId: j['autor_id'] as String,
        texto: j['texto'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class Movimiento {
  const Movimiento({
    required this.id,
    required this.tipo,
    required this.estado,
    required this.monto,
    required this.createdAt,
  });

  final String id;
  final String tipo;
  final String estado;
  final num monto;
  final DateTime createdAt;

  factory Movimiento.fromJson(Map<String, dynamic> j) => Movimiento(
        id: j['id'] as String,
        tipo: j['tipo'] as String,
        estado: j['estado'] as String,
        monto: num.parse(j['monto'].toString()),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String get etiqueta => switch (tipo) {
        'pago_pedido' => 'Pago de pedido',
        'recarga_billetera' => 'Recarga de billetera',
        'reembolso' => 'Reembolso',
        'pago_ayudante' => 'Pago por servicio',
        _ => tipo,
      };
}