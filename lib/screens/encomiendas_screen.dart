import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import '../widgets/brand.dart';
import 'encomienda_detalle_screen.dart';

class EncomiendasScreen extends StatefulWidget {
  final bool historico;
  final ApiService? service;
  const EncomiendasScreen({super.key, this.historico = false, this.service});
  @override
  State<EncomiendasScreen> createState() => _EncomiendasScreenState();
}

class _EncomiendasScreenState extends State<EncomiendasScreen> {
  late final ApiService api;
  late Future<List<Encomienda>> datos;
  @override
  void initState() {
    super.initState();
    api = widget.service ?? ApiService();
    datos = api.misEncomiendas();
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<void> recargar() async {
    setState(() {
      datos = api.misEncomiendas();
    });
    try {
      await datos;
    } catch (_) {}
  }

  void historico() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EncomiendasScreen(historico: true)),
  );
  Future<void> crear() async {
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EncomiendaFormScreen()),
    );
    if (creado == true && mounted) await recargar();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Encomienda>>(
    future: datos,
    builder: (context, snapshot) {
      final lista =
          (snapshot.data ?? <Encomienda>[])
              .where((e) => e.finalizada == widget.historico)
              .toList()
            ..sort(
              (a, b) => (b.creacion ?? DateTime(1970)).compareTo(
                a.creacion ?? DateTime(1970),
              ),
            );
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.historico ? 'Histórico de envíos' : 'Encomiendas'),
          actions: [
            if (!widget.historico)
              TextButton.icon(
                onPressed: historico,
                icon: const Icon(Icons.history_rounded, size: 20),
                label: const Text('Histórico'),
              ),
            IconButton(
              onPressed: recargar,
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: !widget.historico && lista.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: crear,
                icon: const Icon(Icons.add),
                label: const Text('Nueva encomienda'),
              )
            : null,
        body: snapshot.connectionState != ConnectionState.done
            ? const Center(child: CircularProgressIndicator())
            : snapshot.hasError
            ? ErrorView(error: snapshot.error!, reintentar: recargar)
            : RefreshIndicator(
                onRefresh: recargar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  children: [
                    if (lista.isEmpty) ...[
                      const SizedBox(height: 38),
                      EmptyView(
                        widget.historico
                            ? 'Aún no hay envíos finalizados'
                            : 'Tu próximo envío empieza aquí',
                      ),
                      if (!widget.historico)
                        FilledButton.icon(
                          onPressed: crear,
                          icon: const Icon(Icons.add),
                          label: const Text('Crear encomienda'),
                        ),
                    ] else ...[
                      SectionTitle(
                        widget.historico
                            ? 'Tus envíos anteriores'
                            : 'Tus envíos',
                        trailing: Text(
                          '${lista.length}',
                          style: const TextStyle(
                            color: azul,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final e in lista)
                        EncomiendaCard(
                          encomienda: e,
                          onTap: e.viajeroId == null
                              ? null
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EncomiendaDetalleScreen(
                                        encomienda: e,
                                      ),
                                    ),
                                  );
                                  if (mounted) await recargar();
                                },
                        ),
                    ],
                  ],
                ),
              ),
      );
    },
  );
}

class EncomiendaFormScreen extends StatefulWidget {
  const EncomiendaFormScreen({super.key});
  @override
  State<EncomiendaFormScreen> createState() => _EncomiendaFormScreenState();
}

class _EncomiendaFormScreenState extends State<EncomiendaFormScreen> {
  final api = ApiService();
  final form = GlobalKey<FormState>();
  final origen = TextEditingController(),
      destino = TextEditingController(),
      descripcion = TextEditingController(),
      valor = TextEditingController();
  List<String> ciudades = [];
  String moneda = 'COP';
  bool ocupado = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    cargarCiudades();
  }

  Future<void> cargarCiudades() async {
    try {
      final c = await api.ciudades();
      if (mounted) setState(() => ciudades = c);
    } catch (_) {
      /* Las sugerencias son opcionales. */
    }
  }

  @override
  void dispose() {
    for (final c in [origen, destino, descripcion, valor]) {
      c.dispose();
    }
    api.close();
    super.dispose();
  }

  Future<void> guardar() async {
    if (!form.currentState!.validate()) return;
    if (normalizar(origen.text) == normalizar(destino.text)) {
      avisar(context, 'Elige ciudades diferentes.');
      return;
    }
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await api.crearEncomienda({
        'ciudadOrigen': ciudadCanonica(ciudades, origen.text),
        'ciudadDestino': ciudadCanonica(ciudades, destino.text),
        'observaciones': descripcion.text.trim(),
        'moneda': moneda,
        'valor': double.parse(valor.text.trim().replaceAll(',', '.')),
      });
      if (mounted) {
        avisar(context, 'Encomienda publicada');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !ocupado,
    child: Scaffold(
      appBar: AppBar(title: const Text('Nueva encomienda')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SurfaceCard(
              child: AbsorbPointer(
                absorbing: ocupado,
                child: Column(
                  children: [
                    CiudadField(
                      controller: origen,
                      ciudades: ciudades,
                      label: 'Origen',
                    ),
                    const SizedBox(height: 18),
                    CiudadField(
                      controller: destino,
                      ciudades: ciudades,
                      label: 'Destino',
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Tu paquete'),
            TextFormField(
              controller: descripcion,
              enabled: !ocupado,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                alignLabelWithHint: true,
              ),
              validator: requerido,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: moneda,
              decoration: const InputDecoration(labelText: 'Moneda'),
              items: [
                'COP',
                'USD',
                'EUR',
              ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: ocupado ? null : (v) => setState(() => moneda = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: valor,
              enabled: !ocupado,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor ofrecido',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                final n = double.tryParse(
                  (v ?? '').trim().replaceAll(',', '.'),
                );
                return n == null || !n.isFinite || n <= 0
                    ? 'Escribe un valor mayor que cero.'
                    : null;
              },
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  textoError(error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            BotonGuardar(
              ocupado: ocupado,
              onPressed: guardar,
              texto: 'Publicar encomienda',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}
