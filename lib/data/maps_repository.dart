import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';

/// Un punto en el mapa.
class Punto {
  const Punto(this.lat, this.lng);
  final double lat;
  final double lng;

  /// Distancia en metros en línea recta (fórmula de Haversine).
  double metrosHasta(Punto otro) {
    const r = 6371000.0;
    double rad(double g) => g * math.pi / 180;
    final dLat = rad(otro.lat - lat);
    final dLng = rad(otro.lng - lng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) * math.cos(rad(otro.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a)));
  }
}

/// Una dirección con su ubicación.
class Direccion {
  const Direccion({required this.texto, required this.lat, required this.lng});
  final String texto;
  final double lat;
  final double lng;

  Punto get punto => Punto(lat, lng);
}

/// Ubicaciones guardadas de un pedido (pueden faltar en pedidos antiguos).
class CoordenadasPedido {
  const CoordenadasPedido({this.recogida, this.entrega});
  final Punto? recogida;
  final Punto? entrega;
}

/// Búsqueda de direcciones (Nominatim / OpenStreetMap, gratis y sin llave)
/// y coordenadas de los pedidos.
class MapsRepository {
  MapsRepository(this._client);
  final SupabaseClient _client;

  static const _base = 'https://nominatim.openstreetmap.org';

  Future<dynamic> _consultar(String ruta, Map<String, String> params) async {
    final uri = Uri.parse('$_base/$ruta').replace(queryParameters: {
      ...params,
      'format': 'jsonv2',
      'addressdetails': '1',
      'accept-language': 'es',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('MAPS ERROR -> ${res.statusCode} ${res.body}');
        throw AppException('No se pudo consultar el mapa. Inténtalo de nuevo en un momento');
      }
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('MAPS ERROR -> $e');
      throw AppException('No se pudo consultar el mapa. Revisa tu internet');
    }
  }

  /// Arma un texto corto: "Carrera 70 45-10, Laureles, Medellín".
  String _texto(Map<String, dynamic> r) {
    final a = (r['address'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    String? pick(List<String> claves) {
      for (final c in claves) {
        final v = a[c];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final via = pick(['road', 'pedestrian', 'footway', 'path']);
    final numero = pick(['house_number']);
    final barrio = pick(['suburb', 'neighbourhood', 'quarter']);
    final ciudad = pick(['city', 'town', 'village', 'municipality']);

    final partes = <String>[
      if (via != null) numero == null ? via : '$via $numero',
      if (barrio != null) barrio,
      if (ciudad != null) ciudad,
    ];
    
    if (partes.isNotEmpty) return partes.join(', ');
    final nombre = (r['display_name'] as String?) ?? 'Ubicación seleccionada';
    return nombre.replaceAll(RegExp(r',\s*Colombia$'), '');
  }

  /// Busca direcciones por texto (sesgado hacia Medellín y el Valle de Aburrá).
  Future<List<Direccion>> buscar(String consulta) async {
    final json = await _consultar('search', {
      'q': consulta.trim(),
      'countrycodes': 'co',
      'limit': '6',
      'viewbox': '-75.75,6.45,-75.40,6.05',
    });
    final lista = (json as List?) ?? const [];
    return [
      for (final r in lista.cast<Map<String, dynamic>>())
        Direccion(
          texto: _texto(r),
          lat: double.parse(r['lat'].toString()),
          lng: double.parse(r['lon'].toString()),
        ),
    ];
  }

  /// Dirección aproximada de un punto del mapa; null si no hay resultado.
  Future<String?> direccionDe(Punto punto) async {
    final json = await _consultar('reverse', {
      'lat': '${punto.lat}',
      'lon': '${punto.lng}',
      'zoom': '18',
    });
    if (json is! Map<String, dynamic> || json.containsKey('error')) return null;
    return _texto(json);
  }

  Future<void> guardarCoordenadas(String pedidoId, Punto recogida, Punto entrega) async {
    try {
      await _client.rpc('guardar_coordenadas_pedido', params: {
        'p_pedido_id': pedidoId,
        'p_recogida_lat': recogida.lat,
        'p_recogida_lng': recogida.lng,
        'p_entrega_lat': entrega.lat,
        'p_entrega_lng': entrega.lng,
      });
    } on PostgrestException catch (e) {
      throw AppException(e.code == 'P0001' ? e.message : 'No se pudo guardar la ubicación');
    }
  }

  Future<CoordenadasPedido> coordenadas(String pedidoId) async {
    try {
      final f = await _client
          .from('pedidos')
          .select('recogida_lat, recogida_lng, entrega_lat, entrega_lng')
          .eq('id', pedidoId)
          .single();
      Punto? punto(String lat, String lng) =>
          f[lat] == null || f[lng] == null
              ? null
              : Punto((f[lat] as num).toDouble(), (f[lng] as num).toDouble());
      return CoordenadasPedido(
        recogida: punto('recogida_lat', 'recogida_lng'),
        entrega: punto('entrega_lat', 'entrega_lng'),
      );
    } on PostgrestException {
      throw AppException('No se pudo cargar el mapa del pedido');
    }
  }
}