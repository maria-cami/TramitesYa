import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// HU09–HU16 — Creación de una solicitud en 4 pasos:
/// 1) tipo de trámite  2) detalle  3) direcciones  4) resumen y pago.
class NewOrderScreen extends ConsumerStatefulWidget {
  const NewOrderScreen({super.key, this.tramiteId});

  /// Si viene desde el catálogo, el trámite llega preseleccionado.
  final String? tramiteId;

  @override
  ConsumerState<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends ConsumerState<NewOrderScreen> {
  static const _titulos = ['Tipo de trámite', 'Cuéntanos los detalles', 'Direcciones', 'Resumen'];

  final _formDetalle = GlobalKey<FormState>();
  final _formDirecciones = GlobalKey<FormState>();

  final _descripcion = TextEditingController();
  final _notas = TextEditingController();
  final _recogida = TextEditingController();
  final _recogidaRef = TextEditingController();
  final _entrega = TextEditingController();
  final _entregaRef = TextEditingController();

  // Una sola clave por pantalla: si el usuario reintenta tras un error de red,
  // el servidor devuelve el mismo pedido y NO cobra dos veces (HU16).
  final String _idempotencyKey = const Uuid().v4();

  int _paso = 0;
  Tramite? _tramite;
  bool _preseleccionado = false;
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in [_descripcion, _notas, _recogida, _recogidaRef, _entrega, _entregaRef]) {
      c.dispose();
    }
    super.dispose();
  }

  /// HU07: al llegar con un trámite del catálogo se salta directo al detalle.
  void _aplicarPreseleccion(List<Tramite> lista) {
    if (_preseleccionado) return;
    _preseleccionado = true;
    final id = widget.tramiteId;
    if (id == null) return;
    final t = lista.where((x) => x.id == id).firstOrNull;
    if (t != null) {
      _tramite = t;
      _paso = 1;
    }
  }

  void _atras() {
    if (_enviando) return;
    if (_paso == 0) {
      context.pop();
    } else {
      setState(() => _paso--);
    }
  }

  Future<void> _siguiente() async {
    switch (_paso) {
      case 0:
        if (_tramite == null) {
          mostrarMensaje(context, 'Selecciona un tipo de trámite', error: true);
          return;
        }
      case 1:
        if (!_formDetalle.currentState!.validate()) return;
      case 2:
        if (!_formDirecciones.currentState!.validate()) return;
        // HU13: aviso si recogida y entrega son la misma dirección.
        if (_recogida.text.trim().toLowerCase() == _entrega.text.trim().toLowerCase()) {
          final seguir = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Misma dirección'),
              content: const Text(
                'La dirección de recogida y la de entrega son iguales. ¿Es correcto?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Corregir'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sí, continuar'),
                ),
              ],
            ),
          );
          if (seguir != true) return;
        }
    }
    if (mounted) setState(() => _paso++);
  }

  Future<void> _confirmar() async {
    final tramite = _tramite;
    if (_enviando || tramite == null) return;
    setState(() => _enviando = true);
    try {
      final repo = ref.read(appRepositoryProvider);
      final pedidoId = await repo.crearPedido(
        tramiteId: tramite.id,
        descripcion: _descripcion.text,
        notas: _notas.text,
        recogidaDireccion: _recogida.text,
        recogidaReferencia: _recogidaRef.text,
        entregaDireccion: _entrega.text,
        entregaReferencia: _entregaRef.text,
        idempotencyKey: _idempotencyKey,
      );
      // SANDBOX: sustituir por el checkout de Wompi cuando se conecte la pasarela.
      await repo.simularPago(pedidoId);
      ref.invalidate(pedidosProvider);
      if (!mounted) return;
      mostrarMensaje(context, 'Pedido confirmado. Estamos buscando un ayudante');
      context.go('/pedido/$pedidoId');
    } on AppException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } catch (_) {
      if (mounted) {
        mostrarMensaje(context, 'No hay conexión. Revisa tu internet e inténtalo de nuevo',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tramites = ref.watch(tramitesProvider);
    tramites.whenData(_aplicarPreseleccion);

    return PopScope(
      canPop: _paso == 0 && !_enviando,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _atras();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _atras),
          title: Text(_titulos[_paso]),
        ),
        body: SafeArea(
          child: tramites.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                ErrorReintentar(onReintentar: () => ref.invalidate(tramitesProvider)),
            data: (lista) => Column(
              children: [
                LinearProgressIndicator(value: (_paso + 1) / _titulos.length),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: switch (_paso) {
                      0 => _pasoTipo(lista),
                      1 => _pasoDetalle(),
                      2 => _pasoDirecciones(),
                      _ => _pasoResumen(),
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _paso < 3
                      ? FilledButton(onPressed: _siguiente, child: const Text('Continuar'))
                      : FilledButton(
                          onPressed: _enviando ? null : _confirmar,
                          child: _enviando
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : Text(
                                  'Confirmar y pagar ${formatCop(_tramite?.valor ?? 0)}',
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Paso 1: tipo de trámite (HU09) ----
  Widget _pasoTipo(List<Tramite> lista) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Qué necesitas que hagamos por ti?',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        for (final t in lista)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => setState(() => _tramite = t),
              child: Row(
                children: [
                  Icon(t.iconData, color: kBrand),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t.nombre)),
                  if (t.valor != null)
                    Text(formatCop(t.valor!), style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(width: 8),
                  Icon(
                    _tramite?.id == t.id ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: _tramite?.id == t.id ? kBrand : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---- Paso 2: descripción (HU10) ----
  Widget _pasoDetalle() {
    return Form(
      key: _formDetalle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _descripcion,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                Validators.largo(v, campo: 'La descripción', min: 10, max: 500),
            decoration: const InputDecoration(
              labelText: 'Describe lo que necesitas',
              alignLabelWithHint: true,
              helperText: 'Entre 10 y 500 caracteres',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notas,
            maxLines: 3,
            maxLength: 300,
            validator: (v) =>
                Validators.largo(v, campo: 'Las notas', max: 300, obligatorio: false),
            decoration: const InputDecoration(
              labelText: 'Información adicional (opcional)',
              alignLabelWithHint: true,
              hintText: 'Notas, referencias…',
            ),
          ),
        ],
      ),
    );
  }

  // ---- Paso 3: direcciones (HU12, HU13) ----
  Widget _pasoDirecciones() {
    String? dir(String? v) => Validators.largo(v, campo: 'La dirección', min: 5, max: 200);
    String? ref150(String? v) =>
        Validators.largo(v, campo: 'La referencia', max: 150, obligatorio: false);

    return Form(
      key: _formDirecciones,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dirección de recogida', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            controller: _recogida,
            textInputAction: TextInputAction.next,
            validator: dir,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _recogidaRef,
            textInputAction: TextInputAction.next,
            validator: ref150,
            decoration: const InputDecoration(
              labelText: 'Referencia (opcional)',
              hintText: 'Torre B, apto 302',
            ),
          ),
          const SizedBox(height: 24),
          Text('Dirección de entrega', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            controller: _entrega,
            textInputAction: TextInputAction.next,
            validator: dir,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _entregaRef,
            textInputAction: TextInputAction.done,
            validator: ref150,
            decoration: const InputDecoration(labelText: 'Referencia (opcional)'),
          ),
        ],
      ),
    );
  }

  // ---- Paso 4: resumen, costo y seguro (HU14, HU15) ----
  Widget _pasoResumen() {
    final valor = _tramite?.valor ?? 0;

    Widget fila(String etiqueta, String texto) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 96, child: Text(etiqueta, style: Theme.of(context).textTheme.bodySmall)),
              Expanded(child: Text(texto)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              fila('Trámite', _tramite?.nombre ?? '—'),
              fila('Descripción', _descripcion.text.trim()),
              if (_notas.text.trim().isNotEmpty) fila('Notas', _notas.text.trim()),
              const Divider(),
              fila('Recogida', _unirDireccion(_recogida.text, _recogidaRef.text)),
              fila('Entrega', _unirDireccion(_entrega.text, _entregaRef.text)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          // HU14: editar sin perder lo ingresado en los otros pasos.
          onPressed: () => setState(() => _paso = 1),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar detalles'),
        ),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text('Servicio'), Text(formatCop(valor))],
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF159A63)),
                    SizedBox(width: 6),
                    Text('Seguro incluido'),
                  ]),
                  Text('Gratis', style: TextStyle(color: Color(0xFF159A63))),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total a pagar',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(formatCop(valor),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Modo de pruebas: no se realiza ningún cobro real.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _unirDireccion(String direccion, String referencia) {
    final d = direccion.trim();
    final r = referencia.trim();
    return r.isEmpty ? d : '$d ($r)';
  }
}
