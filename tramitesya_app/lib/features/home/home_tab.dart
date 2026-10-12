import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// HU07 (catálogo de trámites) y HU08 (búsqueda).
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _pedir(Tramite t) => context.push('/nuevo-pedido?tramite=${t.id}');

  @override
  Widget build(BuildContext context) {
    final tramites = ref.watch(tramitesProvider);
    final perfil = ref.watch(perfilProvider).valueOrNull;
    final nombre = (perfil?['nombre_completo'] as String?)?.trim();
    final primerNombre = (nombre == null || nombre.isEmpty) ? '' : nombre.split(' ').first;
    final textos = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tramitesProvider);
        await ref.read(tramitesProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primerNombre.isEmpty ? 'Hola 👋' : 'Hola, $primerNombre 👋',
                      style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text('¿Qué trámite necesitas hoy?'),
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: IconButton(
                  tooltip: 'Notificaciones',
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: () => mostrarMensaje(context, 'Las notificaciones llegan pronto'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _busqueda,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar trámite',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _busqueda.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_busqueda.clear),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Trámites populares',
              style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          tramites.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => SizedBox(
              height: 220,
              child: ErrorReintentar(onReintentar: () => ref.invalidate(tramitesProvider)),
            ),
            data: (lista) => _Catalogo(
              lista: lista,
              consulta: _busqueda.text.trim(),
              onTap: _pedir,
            ),
          ),
          const SizedBox(height: 20),
          const _BannerSeguro(),
        ],
      ),
    );
  }
}

class _Catalogo extends StatelessWidget {
  const _Catalogo({required this.lista, required this.consulta, required this.onTap});

  final List<Tramite> lista;
  final String consulta;
  final void Function(Tramite) onTap;

  @override
  Widget build(BuildContext context) {
    // HU08: la búsqueda se activa desde 2 caracteres.
    final q = consulta.toLowerCase();
    final visibles = q.length < 2
        ? lista
        : lista.where((t) => t.nombre.toLowerCase().contains(q)).toList();

    if (visibles.isEmpty) {
      final otro = lista.where((t) => t.nombre == 'Otro trámite').firstOrNull;
      return Column(
        children: [
          const EstadoVacio(
            icono: Icons.search_off,
            texto: 'No encontramos ese trámite. Puedes describirnos lo que necesitas.',
          ),
          if (otro != null)
            OutlinedButton(
              onPressed: () => onTap(otro),
              child: const Text('Pedir otro trámite'),
            ),
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (_, i) {
        final t = visibles[i];
        return AppCard(
          padding: const EdgeInsets.all(8),
          onTap: () => onTap(t),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconoTile(t.iconData, color: t.colorIcono, size: 52),
              const SizedBox(height: 10),
              Text(
                t.nombre,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (t.valor != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Desde ${formatCop(t.valor!)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BannerSeguro extends StatelessWidget {
  const _BannerSeguro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kBrand, kBrandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seguro incluido en todos tus pedidos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Cobertura por robo, pérdida de documentos o dinero y daños.',
                  style: TextStyle(color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}