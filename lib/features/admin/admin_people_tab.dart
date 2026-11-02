import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/admin_repository.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Lista de usuarios o ayudantes, con búsqueda y bloqueo.
/// Un bloqueado no puede crear pedidos (usuario) ni aceptar servicios (ayudante).
class AdminPeopleTab extends ConsumerStatefulWidget {
  const AdminPeopleTab({super.key, required this.rol});

  /// 'usuario' o 'ayudante'.
  final String rol;

  @override
  ConsumerState<AdminPeopleTab> createState() => _AdminPeopleTabState();
}

class _AdminPeopleTabState extends ConsumerState<AdminPeopleTab> {
  String _buscar = '';
  String? _ocupadoId;

  bool get _esAyudante => widget.rol == 'ayudante';

  bool _coincide(PersonaAdmin p) {
    final q = _buscar.trim().toLowerCase();
    if (q.isEmpty) return true;
    return p.nombre.toLowerCase().contains(q) ||
        p.email.toLowerCase().contains(q) ||
        (p.telefono ?? '').contains(q);
  }

  Future<void> _cambiarBloqueo(PersonaAdmin p) async {
    final bloquear = !p.bloqueado;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(bloquear ? 'Bloquear cuenta' : 'Desbloquear cuenta'),
        content: Text(
          bloquear
              ? '${p.nombre} no podrá ${_esAyudante ? 'aceptar servicios' : 'crear pedidos'} '
                  'mientras esté bloqueado.'
              : '${p.nombre} volverá a ${_esAyudante ? 'poder aceptar servicios' : 'poder crear pedidos'}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(bloquear ? 'Bloquear' : 'Desbloquear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _ocupadoId = p.id);
    try {
      await ref.read(adminRepositoryProvider).bloquear(p.id, bloquear);
      ref.invalidate(personasAdminProvider(widget.rol));
      if (mounted) {
        mostrarMensaje(context, bloquear ? 'Cuenta bloqueada' : 'Cuenta desbloqueada');
      }
    } on AppException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } catch (_) {
      if (mounted) mostrarMensaje(context, 'No hay conexión. Revisa tu internet', error: true);
    } finally {
      if (mounted) setState(() => _ocupadoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personas = ref.watch(personasAdminProvider(widget.rol));

    return PaginaAdmin(
      titulo: _esAyudante ? 'Ayudantes' : 'Usuarios',
      subtitulo: _esAyudante
          ? 'Quienes realizan los trámites.'
          : 'Quienes piden los trámites.',
      onRefresh: () async {
        ref.invalidate(personasAdminProvider(widget.rol));
        await ref.read(personasAdminProvider(widget.rol).future);
      },
      hijos: [
        TextField(
          onChanged: (v) => setState(() => _buscar = v),
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre, correo o teléfono',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        personas.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => SizedBox(
            height: 220,
            child: ErrorReintentar(
              onReintentar: () => ref.invalidate(personasAdminProvider(widget.rol)),
            ),
          ),
          data: (lista) {
            final visibles = lista.where(_coincide).toList();
            if (visibles.isEmpty) {
              return SizedBox(
                height: 200,
                child: EstadoVacio(
                  icono: Icons.people_outline,
                  texto: _buscar.isEmpty
                      ? 'Aún no hay ${_esAyudante ? 'ayudantes' : 'usuarios'}.'
                      : 'No encontramos a nadie con esa búsqueda.',
                ),
              );
            }
            return Column(
              children: [
                for (final p in visibles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FilaPersona(
                      p,
                      esAyudante: _esAyudante,
                      ocupado: _ocupadoId == p.id,
                      onBloqueo: () => _cambiarBloqueo(p),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FilaPersona extends StatelessWidget {
  const _FilaPersona(
    this.p, {
    required this.esAyudante,
    required this.ocupado,
    required this.onBloqueo,
  });

  final PersonaAdmin p;
  final bool esAyudante;
  final bool ocupado;
  final VoidCallback onBloqueo;

  @override
  Widget build(BuildContext context) {
    final inicial = p.nombre.isEmpty ? '?' : p.nombre[0].toUpperCase();
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: kAzulSoft,
            foregroundColor: kAzul,
            child: Text(inicial, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (p.bloqueado) ...[
                      const SizedBox(width: 8),
                      const EstadoChip(etiqueta: 'Bloqueado', color: kError),
                    ],
                  ],
                ),
                Text(
                  p.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kGris, fontSize: 12),
                ),
                Text(
                  [
                    if (p.telefono != null && p.telefono!.isNotEmpty) p.telefono!,
                    '${p.pedidos} ${esAyudante ? 'servicios' : 'pedidos'}',
                    'desde ${formatFecha(p.creado)}',
                  ].join(' · '),
                  style: const TextStyle(color: kGris, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ocupado
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: p.bloqueado ? kAzul : kError,
                  ),
                  onPressed: onBloqueo,
                  child: Text(p.bloqueado ? 'Desbloquear' : 'Bloquear'),
                ),
        ],
      ),
    );
  }
}