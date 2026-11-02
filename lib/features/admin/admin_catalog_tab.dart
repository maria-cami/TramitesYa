import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/admin_repository.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Trámites: catálogo de trámites y su valor. Si cambias el valor, los pedidos
/// anteriores conservan el precio con el que se crearon.
class AdminCatalogTab extends ConsumerWidget {
  const AdminCatalogTab({super.key});

  Future<void> _abrirFormulario(BuildContext context, WidgetRef ref, [TramiteAdmin? t]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormTramite(tramite: t),
    );
    if (guardado == true) {
      ref.invalidate(catalogoAdminProvider);
      if (context.mounted) {
        mostrarMensaje(context, t == null ? 'Trámite creado' : 'Trámite actualizado');
      }
    }
  }

  Future<void> _alternar(BuildContext context, WidgetRef ref, TramiteAdmin t) async {
    try {
      await ref.read(adminRepositoryProvider).guardarTramite(
            id: t.id,
            nombre: t.nombre,
            categoria: t.categoria,
            valor: t.valor,
            activo: !t.activo,
          );
      ref.invalidate(catalogoAdminProvider);
    } on AppException catch (e) {
      if (context.mounted) mostrarMensaje(context, e.mensaje, error: true);
    } catch (_) {
      if (context.mounted) {
        mostrarMensaje(context, 'No hay conexión. Revisa tu internet', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoAdminProvider);

    return PaginaAdmin(
      titulo: 'Trámites',
      subtitulo: 'Catálogo y valor de cada trámite.',
      accion: FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () => _abrirFormulario(context, ref),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Nuevo'),
      ),
      onRefresh: () async {
        ref.invalidate(catalogoAdminProvider);
        await ref.read(catalogoAdminProvider.future);
      },
      hijos: [
        catalogo.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => SizedBox(
            height: 220,
            child: ErrorReintentar(
              onReintentar: () => ref.invalidate(catalogoAdminProvider),
            ),
          ),
          data: (lista) {
            if (lista.isEmpty) {
              return const SizedBox(
                height: 200,
                child: EstadoVacio(
                  icono: Icons.list_alt_outlined,
                  texto: 'Aún no hay trámites. Crea el primero con "Nuevo".',
                ),
              );
            }
            return Column(
              children: [
                for (final t in lista)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => _abrirFormulario(context, ref, t),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.nombre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: t.activo ? kNavy : kGris,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (t.categoria != null && t.categoria!.isNotEmpty)
                                      t.categoria!,
                                    formatCop(t.valor),
                                  ].join(' · '),
                                  style: const TextStyle(color: kGris, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            t.activo ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.activo ? kVerde : kGris,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Switch(
                            value: t.activo,
                            activeTrackColor: kVerde,
                            thumbColor: WidgetStateProperty.all(Colors.white),
                            onChanged: (_) => _alternar(context, ref, t),
                          ),
                        ],
                      ),
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

/// Formulario para crear o editar un trámite.
class _FormTramite extends ConsumerStatefulWidget {
  const _FormTramite({this.tramite});

  final TramiteAdmin? tramite;

  @override
  ConsumerState<_FormTramite> createState() => _FormTramiteState();
}

class _FormTramiteState extends ConsumerState<_FormTramite> {
  late final _nombre = TextEditingController(text: widget.tramite?.nombre ?? '');
  late final _categoria = TextEditingController(text: widget.tramite?.categoria ?? '');
  late final _valor = TextEditingController(
    text: widget.tramite == null ? '' : widget.tramite!.valor.round().toString(),
  );
  late bool _activo = widget.tramite?.activo ?? true;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _categoria.dispose();
    _valor.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    final valor = int.tryParse(_valor.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre del trámite');
      return;
    }
    if (valor == null || valor <= 0) {
      setState(() => _error = 'Escribe un valor mayor que cero');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).guardarTramite(
            id: widget.tramite?.id,
            nombre: nombre,
            categoria: _categoria.text.trim(),
            valor: valor,
            activo: _activo,
          );
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No hay conexión. Revisa tu internet');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tramite == null ? 'Nuevo trámite' : 'Editar trámite'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombre,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoría (opcional)',
                hintText: 'Medicamentos, Banco, Documentos…',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valor,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Valor (COP)',
                prefixText: r'$ ',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              subtitle: const Text('Los usuarios solo ven los trámites activos'),
              value: _activo,
              activeTrackColor: kVerde,
              onChanged: (v) => setState(() => _activo = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(color: kError, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}