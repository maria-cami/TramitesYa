import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/maps_repository.dart';
import 'maps_providers.dart';

const _naranja = Color(0xFFFF5B00);
const _medellin = Punto(6.2442, -75.5812);

/// Abre el selector de dirección en el mapa. Devuelve null si la persona cancela.
Future<Direccion?> elegirDireccionEnMapa(
  BuildContext context, {
  required String titulo,
  Punto? inicial,
}) {
  return Navigator.of(context).push<Direccion>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddressPickerScreen(titulo: titulo, inicial: inicial),
    ),
  );
}

/// Busca una dirección por texto o mueve el mapa para dejar el pin donde es.
class AddressPickerScreen extends ConsumerStatefulWidget {
  const AddressPickerScreen({super.key, required this.titulo, this.inicial});

  final String titulo;
  final Punto? inicial;

  @override
  ConsumerState<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen> {
  final _consulta = TextEditingController();
  final _mapa = MapController();
  Timer? _espera;

  late Punto _centro = widget.inicial ?? _medellin;
  late double _zoom = widget.inicial == null ? 13 : 17;

  String? _texto; // dirección del centro actual
  Punto? _puntoDelTexto; // punto al que corresponde _texto cuando viene de una búsqueda
  bool _buscando = false;
  bool _cargandoTexto = false;
  List<Direccion>? _resultados;

  @override
  void dispose() {
    _espera?.cancel();
    _consulta.dispose();
    _mapa.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final texto = _consulta.text.trim();
    if (texto.length < 3 || _buscando) return;
    FocusScope.of(context).unfocus();
    setState(() => _buscando = true);
    try {
      final lista = await ref.read(mapsRepositoryProvider).buscar(texto);
      if (!mounted) return;
      if (lista.isEmpty) {
        mostrarMensaje(
          context,
          'No encontramos esa dirección. Prueba con el barrio y la ciudad, o mueve el mapa',
          error: true,
        );
      } else {
        setState(() => _resultados = lista);
      }
    } on AppException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _elegirResultado(Direccion d) {
    setState(() {
      _centro = d.punto;
      _zoom = 17;
      _texto = d.texto;
      _puntoDelTexto = d.punto;
      _resultados = null; // el mapa se vuelve a crear centrado en este punto
    });
  }

  /// El mapa se quedó quieto: si el pin se movió, se busca la dirección de ese punto.
  Future<void> _alQuietar() async {
    final p = _centro;
    final base = _puntoDelTexto;
    if (base != null && base.metrosHasta(p) < 15) return; // sigue en la dirección buscada
    setState(() => _cargandoTexto = true);
    try {
      final t = await ref.read(mapsRepositoryProvider).direccionDe(p);
      if (!mounted || _centro != p) return;
      setState(() {
        _texto = t;
        _puntoDelTexto = null;
      });
    } on AppException {
      if (mounted) setState(() => _texto = null);
    } finally {
      if (mounted) setState(() => _cargandoTexto = false);
    }
  }

  void _alMover(MapCamera camara, bool porGesto) {
    _centro = Punto(camara.center.latitude, camara.center.longitude);
    _zoom = camara.zoom;
    if (porGesto) {
      _espera?.cancel();
      _espera = Timer(const Duration(milliseconds: 700), _alQuietar);
    }
  }

  void _zoomMas(double delta) {
    final c = _mapa.camera;
    _mapa.move(c.center, (c.zoom + delta).clamp(3, 19).toDouble());
  }

  void _confirmar() {
    final t = _texto;
    if (t == null) return;
    Navigator.of(context).pop(Direccion(texto: t, lat: _centro.lat, lng: _centro.lng));
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _resultados;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _consulta,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  hintText: 'Busca una dirección (Ej: Cra 70 # 45-10, Laureles)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Buscar',
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _buscar,
                        ),
                ),
              ),
            ),
            Expanded(
              child: resultados != null
                  // Mientras hay resultados se muestra la lista en lugar del mapa.
                  ? Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() => _resultados = null),
                            child: const Text('Volver al mapa'),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: resultados.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) => ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(resultados[i].texto),
                              onTap: () => _elegirResultado(resultados[i]),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapa,
                          options: MapOptions(
                            initialCenter: LatLng(_centro.lat, _centro.lng),
                            initialZoom: _zoom,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                            ),
                            onPositionChanged: _alMover,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.tramitesya.app',
                            ),
                            RichAttributionWidget(
                              attributions: [
                                TextSourceAttribution('OpenStreetMap contributors'),
                              ],
                            ),
                          ],
                        ),
                        // Pin fijo al centro: la persona mueve el mapa por debajo.
                        const IgnorePointer(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 48),
                              child: Icon(Icons.location_on, size: 48, color: _naranja),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Column(
                            children: [
                              FloatingActionButton.small(
                                heroTag: 'zoom_mas',
                                onPressed: () => _zoomMas(1),
                                child: const Icon(Icons.add),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                heroTag: 'zoom_menos',
                                onPressed: () => _zoomMas(-1),
                                child: const Icon(Icons.remove),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(blurRadius: 8, color: Color(0x14000000))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _cargandoTexto
                        ? 'Buscando dirección…'
                        : (_texto ?? 'Mueve el mapa para ubicar el pin o busca una dirección'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: (_texto == null || _cargandoTexto) ? null : _confirmar,
                    child: const Text('Usar esta dirección'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}