import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Tarjeta "Mi plan" para la pestaña Cuenta.
class PlanResumenCard extends ConsumerWidget {
  const PlanResumenCard({super.key});

  String _detalle(EstadoPlan p) {
    if (!p.activo) return 'Necesitas un plan para aceptar servicios.';
    final partes = <String>[
      if (p.pedidosLimite != null)
        '${p.pedidosUsados} de ${p.pedidosLimite} pedidos este mes'
      else if (p.rol == 'usuario')
        'Pedidos ilimitados',
      if (p.vence != null) 'Vence el ${formatFecha(p.vence!)}',
    ];
    return partes.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(miPlanProvider);
    final textos = Theme.of(context).textTheme;

    return AppCard(
      child: plan.when(
        loading: () => const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Row(
          children: [
            const Expanded(child: Text('No se pudo cargar tu plan')),
            TextButton(
              onPressed: () => ref.invalidate(miPlanProvider),
              child: const Text('Reintentar'),
            ),
          ],
        ),
        data: (p) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_outlined, color: kBrand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.activo ? (p.nombre ?? 'Plan') : 'Sin plan activo',
                    style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (p.prueba) const EstadoChip(etiqueta: 'Prueba', color: kAmbar),
              ],
            ),
            const SizedBox(height: 6),
            Text(_detalle(p), style: textos.bodySmall),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlanScreen()),
              ),
              child: Text(p.activo && !p.prueba ? 'Cambiar de plan' : 'Ver planes'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de planes disponibles para el rol de la persona.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  String? _activando;

  Future<void> _elegir(Plan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cambiar a ${plan.nombre}'),
        content: Text(
          plan.precio == 0
              ? 'Pasarás al plan gratis.'
              : 'Se activará por 30 días. Modo de pruebas: no se realiza ningún cobro real.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _activando = plan.id);
    try {
      await ref.read(appRepositoryProvider).activarPlan(plan.id);
      ref.invalidate(miPlanProvider);
      if (mounted) mostrarMensaje(context, 'Plan ${plan.nombre} activado');
    } on AppException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } catch (_) {
      if (mounted) {
        mostrarMensaje(context, 'No hay conexión. Revisa tu internet', error: true);
      }
    } finally {
      if (mounted) setState(() => _activando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planes = ref.watch(planesProvider);
    final actual = ref.watch(miPlanProvider).valueOrNull;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Planes')),
      body: SafeArea(
        child: planes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              ErrorReintentar(onReintentar: () => ref.invalidate(planesProvider)),
          data: (lista) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'El servicio se paga directamente al ayudante. TrámitesYa solo cobra el plan.',
                style: textos.bodyMedium?.copyWith(color: kGris),
              ),
              const SizedBox(height: 16),
              for (final p in lista)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.nombre,
                                style: textos.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              p.precio == 0 ? 'Gratis' : '${formatCop(p.precio)} / mes',
                              style: const TextStyle(
                                color: kNavy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(p.descripcion, style: textos.bodyMedium),
                        const SizedBox(height: 12),
                        if (actual?.planId == p.id && actual?.activo == true)
                          const EstadoChip(etiqueta: 'Plan actual', color: kVerde)
                        else
                          FilledButton(
                            onPressed: _activando == null ? () => _elegir(p) : null,
                            child: _activando == p.id
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Elegir este plan'),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Modo de pruebas: los planes se activan sin cobro real.',
                textAlign: TextAlign.center,
                style: textos.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}