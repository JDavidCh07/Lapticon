import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import '../widgets/brand.dart';

class EncomiendaDetalleScreen extends StatefulWidget {
  final Encomienda encomienda;
  final Viaje? viaje;
  final ApiService? service;
  final String? usuario;
  const EncomiendaDetalleScreen({
    super.key,
    required this.encomienda,
    this.viaje,
    this.service,
    this.usuario,
  });
  @override
  State<EncomiendaDetalleScreen> createState() =>
      _EncomiendaDetalleScreenState();
}

class _EncomiendaDetalleScreenState extends State<EncomiendaDetalleScreen> {
  late final ApiService api;
  String? remitenteNombre;
  bool consultandoRemitente = false, falloRemitente = false;
  late Encomienda envio;
  bool ocupado = false, vigente = true;
  Object? error;
  String get uid => widget.usuario ?? FirebaseAuth.instance.currentUser!.uid;
  @override
  void initState() {
    super.initState();
    api = widget.service ?? ApiService();
    envio = widget.encomienda;
    remitenteNombre = envio.remitenteNombre;
    if (envio.uid != uid) cargarRemitente();
  }

  Future<void> cargarRemitente() async {
    if (consultandoRemitente || envio.uid == uid) return;
    setState(() {
      consultandoRemitente = true;
      falloRemitente = false;
    });
    try {
      final nombre = await api.nombreRemitente(envio);
      if (mounted) setState(() => remitenteNombre = nombre ?? remitenteNombre);
    } catch (_) {
      // El contacto es opcional; un fallo no deshabilita la aceptación.
      if (mounted) setState(() => falloRemitente = true);
    } finally {
      if (mounted) setState(() => consultandoRemitente = false);
    }
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  Future<void> actualizar() async {
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      List<Encomienda> lista;
      if (envio.uid == uid) {
        lista = await api.misEncomiendas();
      } else if (widget.viaje != null) {
        final r = await api.buscar(widget.viaje!);
        lista = [...r.disponibles, ...r.tomadas];
      } else {
        final p = await api.panelViajes(uid);
        lista = p.pendientes;
      }
      final e = lista.where((e) => e.id == envio.id).firstOrNull;
      if (mounted) {
        setState(() {
          if (e != null) {
            envio = e;
            vigente = true;
          } else if (envio.estado != 'recibida') {
            vigente = false;
            error = const ApiException('Este envío ya no está disponible.');
          }
        });
      }
      if (mounted && envio.uid != uid) {
        remitenteNombre = envio.remitenteNombre ?? remitenteNombre;
        await cargarRemitente();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          vigente = false;
        });
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> tomar() async {
    if (!await confirmar(
      context,
      'Aceptar encomienda',
      '${envio.origen} → ${envio.destino}\n${envio.precio}',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      final cierreActualizado = await api.tomar(envio, widget.viaje!, uid);
      if (mounted) {
        avisar(
          context,
          cierreActualizado
              ? 'Encomienda aceptada'
              : 'Encomienda aceptada. Actualiza el viaje.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          vigente = false;
        });
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> entregar() async {
    if (!await confirmar(
      context,
      'Confirmar entrega',
      '¿Ya entregaste esta encomienda en destino?',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      final e = await api.entregar(envio, uid, viaje: widget.viaje);
      if (mounted) {
        setState(() => envio = e);
        avisar(context, 'Entrega registrada');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          vigente = false;
        });
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esRemitente = envio.uid == uid;
    final viaje = esRemitente ? envio.viajeAsociado : widget.viaje;
    return PopScope(
      canPop: !ocupado,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tu encomienda'),
          actions: [
            IconButton(
              onPressed: ocupado ? null : actualizar,
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            EncomiendaCard(encomienda: envio),
            if (!esRemitente)
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, color: azul),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Remitente',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: tinta,
                            ),
                          ),
                        ),
                        if (consultandoRemitente)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    if (remitenteNombre != null) ...[
                      const SizedBox(height: 12),
                      Text(remitenteNombre!),
                    ] else if (!consultandoRemitente) ...[
                      const SizedBox(height: 12),
                      const Text('Nombre no disponible'),
                    ],
                    if (falloRemitente)
                      TextButton.icon(
                        onPressed: consultandoRemitente
                            ? null
                            : cargarRemitente,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Actualizar remitente'),
                      ),
                  ],
                ),
              ),
            if (esRemitente && envio.viajeroId != null)
              SurfaceCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFEAF0FF),
                      child: Icon(Icons.person_outline_rounded, color: azul),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Viajero asignado',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: tinta,
                            ),
                          ),
                          if (envio.viajeroNombre != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(envio.viajeroNombre!),
                            ),
                          if (envio.viajeroTelefono != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(envio.viajeroTelefono!),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seguimiento',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: tinta,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ProgresoEntrega(envio.estado),
                ],
              ),
            ),
            if ([
              envio.creacion,
              envio.vencimiento,
              envio.disponibleDesde,
              envio.limiteEntrega,
            ].any((f) => f != null))
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (envio.creacion != null)
                      Text(
                        'Publicado · ${mostrarFecha(envio.creacion!.toLocal())}',
                      ),
                    if (envio.vencimiento != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Vencimiento · ${mostrarFecha(envio.vencimiento!.toLocal())}',
                        ),
                      ),
                    if (envio.disponibleDesde != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Disponible desde · ${mostrarFecha(envio.disponibleDesde!.toLocal())}',
                        ),
                      ),
                    if (envio.limiteEntrega != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Fecha límite · ${mostrarFecha(envio.limiteEntrega!.toLocal())}',
                        ),
                      ),
                  ],
                ),
              ),
            if (viaje != null) ...[
              const SectionTitle('Viaje'),
              ViajeCard(viaje: viaje),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  textoError(error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (vigente &&
                widget.viaje != null &&
                widget.viaje!.permiteAceptar &&
                envio.compatibleCon(widget.viaje!, uid))
              BotonGuardar(
                ocupado: ocupado,
                onPressed: tomar,
                texto: 'Aceptar encomienda',
              ),
            if (vigente &&
                envio.viajeroId == uid &&
                envio.uid != uid &&
                envio.estado == 'tomada')
              BotonGuardar(
                ocupado: ocupado,
                onPressed: entregar,
                texto: 'Marcar como entregada',
              ),
            if (!vigente)
              OutlinedButton(
                onPressed: ocupado ? null : actualizar,
                child: const Text('Actualizar'),
              ),
            if (ocupado)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
