import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../services/vuelos_service.dart';
import '../widgets/common.dart';
import '../widgets/brand.dart';
import 'encomienda_detalle_screen.dart';

class ViajesScreen extends StatefulWidget {
  final Viaje? seleccionado;
  final ApiService? service;
  final String? usuario;
  const ViajesScreen({
    super.key,
    this.seleccionado,
    this.service,
    this.usuario,
  });
  @override
  State<ViajesScreen> createState() => _ViajesScreenState();
}

class _ViajesScreenState extends State<ViajesScreen> {
  late final ApiService api;
  late Future<PanelViajes> datos;
  Viaje? ultimoActivo;
  bool ocupado = false;
  String get uid => widget.usuario ?? FirebaseAuth.instance.currentUser!.uid;
  @override
  void initState() {
    super.initState();
    api = widget.service ?? ApiService();
    datos = cargar();
  }

  Future<PanelViajes> cargar() async {
    final panel = await api.panelViajes(uid);
    if (panel.activo != null) ultimoActivo = panel.activo;
    return panel;
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<void> recargar() async {
    setState(() {
      datos = cargar();
    });
    try {
      await datos;
    } catch (_) {}
  }

  void historico() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const HistoricoViajesScreen()),
  );
  Viaje? fijado(PanelViajes p) {
    if (widget.seleccionado != null) {
      return p.viajes.where((v) => v.id == widget.seleccionado!.id).firstOrNull;
    }
    if (p.activo != null) return p.activo;
    final anterior = p.viajes
        .where((v) => v.id == ultimoActivo?.id)
        .firstOrNull;
    if (anterior != null &&
        p.pendientes.any(
          (e) =>
              claveRuta(e.origen, e.destino) ==
              claveRuta(anterior.origen, anterior.destino),
        )) {
      return anterior;
    }
    return p.fijado;
  }

  Future<void> crear() async {
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ViajeFormScreen()),
    );
    if (creado == true && mounted) await recargar();
  }

  Future<void> abrir(Encomienda envio, Viaje? viaje) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EncomiendaDetalleScreen(encomienda: envio, viaje: viaje),
      ),
    );
    if (mounted) await recargar();
  }

  Future<void> cerrar(Viaje viaje, String estado) async {
    if (!await confirmar(
      context,
      estado == 'cancelado' ? 'Cancelar viaje' : 'Cerrar recepción',
      estado == 'cancelado'
          ? '¿Quieres cancelar este viaje?'
          : '¿Dejar de aceptar nuevas encomiendas?',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => ocupado = true);
    try {
      if (estado == 'cancelado') {
        final r = await api.buscar(viaje);
        if (r.tomadas.any((e) => e.viajeroId == uid && e.estado == 'tomada')) {
          throw const ApiException('Este viaje tiene entregas pendientes.');
        }
      }
      await api.cambiarViaje(viaje, estado);
      if (mounted) {
        avisar(context, 'Viaje actualizado');
        await recargar();
      }
    } catch (e) {
      if (mounted) avisar(context, textoError(e));
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.seleccionado == null ? 'Viajes' : widget.seleccionado!.numero,
      ),
      actions: [
        if (widget.seleccionado == null)
          TextButton.icon(
            onPressed: historico,
            icon: const Icon(Icons.history_rounded, size: 20),
            label: const Text('Histórico'),
          ),
        IconButton(
          onPressed: ocupado ? null : recargar,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<PanelViajes>(
      future: datos,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!, reintentar: recargar);
        }
        final panel = snapshot.data!;
        final viaje = fijado(panel);
        final pendientes = widget.seleccionado != null && viaje != null
            ? panel
                  .rutaDe(viaje)
                  .tomadas
                  .where(
                    (e) =>
                        e.viajeroId == uid &&
                        e.uid != uid &&
                        e.estado == 'tomada',
                  )
                  .toList()
            : panel.pendientes;
        final candidatos = viaje == null
            ? <Encomienda>[]
            : panel
                  .rutaDe(viaje)
                  .disponibles
                  .where((e) => e.compatibleCon(viaje, uid))
                  .toList();
        final acepta =
            viaje != null &&
            viaje.permiteAceptar &&
            pendientes.length < 3 &&
            !panel.fallosCierre.contains(viaje.id);
        return AbsorbPointer(
          absorbing: ocupado,
          child: RefreshIndicator(
            onRefresh: recargar,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (viaje != null)
                  PinnedHeaderSliver(
                    child: ColoredBox(
                      color: fondo,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                        child: ViajeCard(
                          viaje: viaje,
                          pendientes: pendientes
                              .where(
                                (e) =>
                                    claveRuta(e.origen, e.destino) ==
                                    claveRuta(viaje.origen, viaje.destino),
                              )
                              .length,
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverList.list(
                    children: [
                      if (viaje == null && pendientes.isEmpty) ...[
                        const SizedBox(height: 36),
                        const EmptyView(
                          'Tu próxima ruta te espera',
                          icono: Icons.flight_takeoff_rounded,
                        ),
                        if (panel.permiteNuevo)
                          FilledButton.icon(
                            onPressed: crear,
                            icon: const Icon(Icons.add),
                            label: const Text('Registrar viaje'),
                          ),
                      ],
                      if (panel.fallosCierre.isNotEmpty)
                        SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No pudimos cerrar la recepción.',
                                style: TextStyle(color: Color(0xFFAF3F4F)),
                              ),
                              TextButton.icon(
                                onPressed: recargar,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      if (pendientes.isNotEmpty) ...[
                        SectionTitle(
                          'Tus entregas',
                          trailing: Text(
                            '${pendientes.length}',
                            style: const TextStyle(
                              color: azul,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (final e in pendientes)
                          EncomiendaCard(
                            encomienda: e,
                            onTap: () => abrir(
                              e,
                              viaje != null &&
                                      claveRuta(e.origen, e.destino) ==
                                          claveRuta(viaje.origen, viaje.destino)
                                  ? viaje
                                  : null,
                            ),
                          ),
                      ],
                      if (acepta) ...[
                        const SectionTitle('Para tu ruta'),
                        if (candidatos.isEmpty)
                          const EmptyView('Sin encomiendas disponibles'),
                        for (final e in candidatos)
                          EncomiendaCard(
                            encomienda: e,
                            onTap: () => abrir(e, viaje),
                          ),
                      ],
                      if (viaje != null && pendientes.isEmpty && !acepta)
                        const EmptyView(
                          'Sin entregas pendientes',
                          icono: Icons.task_alt_rounded,
                        ),
                      if (viaje != null &&
                          [
                            'disponible',
                            'contactado',
                          ].contains(viaje.estado)) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => cerrar(viaje, 'completado'),
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Cerrar recepción'),
                        ),
                        if (pendientes.isEmpty)
                          TextButton(
                            onPressed: () => cerrar(viaje, 'cancelado'),
                            child: const Text('Cancelar viaje'),
                          ),
                      ],
                      if (ocupado)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class ViajeDetalleScreen extends StatelessWidget {
  final Viaje viaje;
  const ViajeDetalleScreen({super.key, required this.viaje});
  @override
  Widget build(BuildContext context) => ViajesScreen(seleccionado: viaje);
}

class HistoricoViajesScreen extends StatefulWidget {
  const HistoricoViajesScreen({super.key});
  @override
  State<HistoricoViajesScreen> createState() => _HistoricoViajesScreenState();
}

class _HistoricoViajesScreenState extends State<HistoricoViajesScreen> {
  final api = ApiService();
  late Future<List<Viaje>> datos;
  @override
  void initState() {
    super.initState();
    datos = api.misViajes();
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<void> recargar() async {
    setState(() {
      datos = api.misViajes();
    });
    try {
      await datos;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Histórico de viajes')),
    body: FutureBuilder<List<Viaje>>(
      future: datos,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!, reintentar: recargar);
        }
        final lista = snapshot.data!
            .where((v) => ['completado', 'cancelado'].contains(v.estado))
            .toList();
        return RefreshIndicator(
          onRefresh: recargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (lista.isEmpty)
                const EmptyView(
                  'Aún no hay viajes finalizados',
                  icono: Icons.history_rounded,
                ),
              for (final v in lista)
                ViajeCard(
                  viaje: v,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViajeDetalleScreen(viaje: v),
                      ),
                    );
                    if (mounted) await recargar();
                  },
                ),
            ],
          ),
        );
      },
    ),
  );
}

class ViajeFormScreen extends StatefulWidget {
  final VuelosService? consultor;
  const ViajeFormScreen({super.key, this.consultor});
  @override
  State<ViajeFormScreen> createState() => _ViajeFormScreenState();
}

class _ViajeFormScreenState extends State<ViajeFormScreen> {
  final api = ApiService();
  late final VuelosService vuelosApi;
  @override
  void initState() {
    super.initState();
    vuelosApi = widget.consultor ?? VuelosService();
  }

  final form = GlobalKey<FormState>();
  final numero = TextEditingController();
  DateTime fecha = DateTime.now();
  List<Vuelo> resultados = [];
  Vuelo? elegido;
  bool consultando = false, guardando = false;
  Object? error;
  bool get ocupado => consultando || guardando;
  @override
  void dispose() {
    numero.dispose();
    api.close();
    vuelosApi.close();
    super.dispose();
  }

  Future<void> consultar() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      consultando = true;
      error = null;
      elegido = null;
      resultados = [];
    });
    try {
      final vuelos = await vuelosApi.consultar(numero.text, fecha);
      if (mounted) {
        setState(() {
          resultados = vuelos;
          if (vuelos.length == 1) elegido = vuelos.first;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => consultando = false);
    }
  }

  Future<void> guardar() async {
    final vuelo = elegido;
    if (vuelo == null) return;
    if (!await confirmar(
      context,
      'Registrar viaje',
      '${vuelo.numero}\n${vuelo.origen} → ${vuelo.destino}\n${mostrarFecha(vuelo.fecha)}',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      guardando = true;
      error = null;
    });
    try {
      final panel = await api.panelViajes(
        FirebaseAuth.instance.currentUser!.uid,
      );
      if (!panel.permiteNuevo) {
        throw const ApiException('Ya tienes un viaje o entregas pendientes.');
      }
      await api.crearViaje(vuelo);
      if (mounted) {
        avisar(context, 'Viaje registrado');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !ocupado,
    child: Scaffold(
      appBar: AppBar(title: const Text('Nuevo viaje')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Form(
              key: form,
              child: Column(
                children: [
                  TextFormField(
                    controller: numero,
                    enabled: !ocupado,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Código del vuelo',
                      hintText: 'AV10',
                      prefixIcon: Icon(Icons.flight_outlined),
                    ),
                    onChanged: (_) => setState(() {
                      elegido = null;
                      resultados = [];
                      error = null;
                    }),
                    validator: (v) =>
                        RegExp(r'^[A-Z0-9]{2,3}[0-9]{1,4}[A-Z]?$').hasMatch(
                          (v ?? '')
                              .replaceAll(RegExp(r'\s+'), '')
                              .toUpperCase(),
                        )
                        ? null
                        : 'Escribe un código válido.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(mostrarFecha(fecha)),
                      onPressed: ocupado
                          ? null
                          : () async {
                              final hoy = DateTime.now();
                              final f = await showDatePicker(
                                context: context,
                                initialDate: fecha,
                                firstDate: DateTime(
                                  hoy.year,
                                  hoy.month,
                                  hoy.day,
                                ),
                                lastDate: hoy.add(const Duration(days: 365)),
                              );
                              if (f != null && mounted) {
                                setState(() {
                                  fecha = f;
                                  elegido = null;
                                  resultados = [];
                                  error = null;
                                });
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: BotonGuardar(
                      ocupado: ocupado,
                      onPressed: consultar,
                      texto: 'Buscar vuelo',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (resultados.length > 1) ...[
            const SectionTitle('Selecciona tu salida'),
            for (final v in resultados)
              SurfaceCard(
                onTap: ocupado ? null : () => setState(() => elegido = v),
                child: Row(
                  children: [
                    Icon(
                      identical(elegido, v)
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: azul,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${v.codigoOrigen} → ${v.codigoDestino}\n${v.salida}',
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (elegido case final vuelo?) ...[
            const SectionTitle('Tu vuelo'),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vuelo.aerolinea,
                    style: const TextStyle(
                      color: azul,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RouteLine(vuelo.origen, vuelo.destino),
                  const SizedBox(height: 8),
                  Text(
                    '${vuelo.codigoOrigen} → ${vuelo.codigoDestino}',
                    style: const TextStyle(color: Color(0xFF78869D)),
                  ),
                  const Divider(height: 32),
                  Text('Salida · ${vuelo.salida}'),
                  if (vuelo.llegada.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Llegada · ${vuelo.llegada}'),
                  ],
                ],
              ),
            ),
            BotonGuardar(
              ocupado: ocupado,
              onPressed: guardar,
              texto: 'Registrar viaje',
            ),
            const SizedBox(height: 12),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                textoError(error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'AeroDataBox · aerodatabox.com',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF78869D)),
          ),
        ],
      ),
    ),
  );
}
