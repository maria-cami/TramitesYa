import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'service_card.dart';

/// Inicio del ayudante: interruptor de disponibilidad y pedidos que buscan
/// ayudante. Se refresca solo cada 20 s mientras estés disponible.
class AvailableTab extends ConsumerStatefulWidget {
  const AvailableTab({super.key});

  @override
  ConsumerState<AvailableTab> createState() => _AvailableTabState();
}

class _AvailableTabState extends ConsumerState<AvailableTab> {
  Timer? _timer;
  bool _disponible = true;
  String? _aceptandoId;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _disponible) ref.invalidate(disponiblesProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _aceptar(Pedido p) async {
    if (_aceptandoId != null) return;
    setState(() => _aceptandoId = p.id);
    try {
      await ref.read(appRepositoryProvider).aceptarPedido(p.id);
      ref
        ..invalidate(disponiblesProvider)
        ..invalidate(misServiciosProvider)
        ..invalidate(servicioProvider(p.id));
      if (!mounted) return;
      mostrarMensaje(context, 'Pedido aceptado. ¡Manos a la obra!');
      context.push('/servicio/${p.id}');
    } on AppException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
      ref.invalidate(disponiblesProvider);
    } catch (_) {
      if (mounted) {
        mostrarMensaje(context, 'No hay conexión. Revisa tu internet', error: true);
      }
    } finally {
      if (mounted) setState(() => _aceptandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponibles = ref.watch(disponiblesProvider);
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const IconoTile(Icons.verified_user_outlined, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _disponible ? 'Disponible' : 'No disponible',
                        style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Switch(
                      value: _disponible,
                      activeTrackColor: kVerde,
                      thumbColor: WidgetStateProperty.all(Colors.white),
                      onChanged: (v) {
                        setState(() => _disponible = v);
                        if (v) ref.invalidate(disponiblesProvider);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_disponible ? kVerde : kGris).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _disponible
                        ? 'Estás disponible para recibir solicitudes'
                        : 'Estás en pausa: no verás solicitudes nuevas',
                    style: TextStyle(
                      color: _disponible ? kVerde : kGris,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'Solicitudes disponibles',
            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: !_disponible
              ? const EstadoVacio(
                  icono: Icons.pause_circle_outline,
                  texto: 'Activa "Disponible" para ver solicitudes.',
                )
              : disponibles.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => ErrorReintentar(
                    onReintentar: () => ref.invalidate(disponiblesProvider),
                  ),
                  data: (lista) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(disponiblesProvider);
                      await ref.read(disponiblesProvider.future);
                    },
                    child: lista.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(
                                height: 320,
                                child: EstadoVacio(
                                  icono: Icons.inbox_outlined,
                                  texto:
                                      'No hay solicitudes por ahora. Desliza hacia abajo para actualizar.',
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: lista.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => ServiceCard(
                              pedido: lista[i],
                              onAceptar: () => _aceptar(lista[i]),
                              aceptando: _aceptandoId == lista[i].id,
                            ),
                          ),
                  ),
                ),
        ),
      ],
    );
  }
}