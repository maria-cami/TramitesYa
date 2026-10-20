import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/maps_repository.dart';
import 'maps_providers.dart';

const _naranja = Color(0xFFFF5B00);

/// Mapa del pedido con la recogida (A), la entrega (B) y la línea entre ambas.
/// Si el pedido no tiene coordenadas (pedidos antiguos), no muestra nada.
class RutaPedidoMapa extends ConsumerWidget {
  const RutaPedidoMapa({super.key, required this.pedidoId});

  final String pedidoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coords = ref.watch(coordenadasPedidoProvider(pedidoId));
    return coords.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (c) {
        final a = c.recogida;
        final b = c.entrega;
        if (a == null || b == null) return const SizedBox.shrink();
        return _MapaRuta(recogida: a, entrega: b);
      },
    );
  }
}

class _MapaRuta extends StatelessWidget {
  const _MapaRuta({required this.recogida, required this.entrega});

  final Punto recogida;
  final Punto entrega;

  String _distancia() {
    final m = recogida.metrosHasta(entrega);
    return m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  Widget _pin(String letra) => Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: _naranja,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
        ),
        child: Text(
          letra,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final a = LatLng(recogida.lat, recogida.lng);
    final b = LatLng(entrega.lat, entrega.lng);
    final muyCerca = recogida.metrosHasta(entrega) < 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: a,
                initialZoom: 17,
                // Encuadra A y B en la pantalla (salvo que estén casi en el mismo punto).
                initialCameraFit: muyCerca
                    ? null
                    : CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints([a, b]),
                        padding: const EdgeInsets.all(48),
                      ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tramitesya.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(points: [a, b], color: _naranja, strokeWidth: 5),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(point: a, width: 30, height: 30, child: _pin('A')),
                    Marker(point: b, width: 30, height: 30, child: _pin('B')),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.straighten, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Distancia entre recogida (A) y entrega (B): ${_distancia()} (en línea recta)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}