import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models.dart';

class ApiException implements Exception {
  final String mensaje;
  final int? status;
  final bool conexion;
  const ApiException(this.mensaje, [this.status, this.conexion = false]);
  @override
  String toString() => mensaje;
}

typedef ResultadoRuta = ({
  List<Encomienda> disponibles,
  List<Encomienda> tomadas,
});

class ApiService {
  final http.Client client;
  final Future<String?> Function(bool renovar) token;

  ApiService({http.Client? client, Future<String?> Function(bool)? token})
    : client = client ?? http.Client(),
      token =
          token ??
          ((renovar) async =>
              FirebaseAuth.instance.currentUser?.getIdToken(renovar));

  void close() => client.close();

  Future<dynamic> solicitar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool publico = false,
    bool renovar = false,
  }) async {
    final headers = {'Content-Type': 'application/json; charset=utf-8'};
    if (!publico) {
      final idToken = await token(renovar);
      if (idToken == null) {
        throw const ApiException('Inicia sesión nuevamente.', 401);
      }
      headers['Authorization'] = 'Bearer $idToken';
    }
    final uri = Uri.parse('$backendUrl$ruta').replace(queryParameters: query);
    final req = http.Request(metodo, uri)..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    try {
      final respuesta = await client
          .send(req)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 45));
      if (respuesta.statusCode == 401 && !publico && !renovar) {
        return await solicitar(
          metodo,
          ruta,
          body: body,
          query: query,
          renovar: true,
        );
      }
      dynamic data;
      try {
        data = respuesta.bodyBytes.isEmpty
            ? null
            : jsonDecode(utf8.decode(respuesta.bodyBytes));
      } on FormatException {
        throw ApiException(
          'No pudimos cargar la información. Intenta nuevamente.',
          respuesta.statusCode,
        );
      }
      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        throw ApiException(
          data is Map
              ? (data['error'] ??
                        data['message'] ??
                        data['mensaje'] ??
                        'No se pudo completar la solicitud.')
                    .toString()
              : 'No se pudo completar la solicitud (${respuesta.statusCode}).',
          respuesta.statusCode,
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiException(
        'La conexión tardó demasiado. Intenta nuevamente.',
        null,
        true,
      );
    } on http.ClientException {
      throw const ApiException(
        'No pudimos conectar. Revisa tu conexión.',
        null,
        true,
      );
    }
  }

  Future<Map<String, dynamic>?> perfil(String uid) async {
    try {
      final data = await solicitar('GET', '/api/users/$uid');
      if (data == null || data['user'] == null) return null;
      return Map<String, dynamic>.from(data['user']);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<void> guardarPerfil(Map<String, dynamic> perfil, {String? uid}) async {
    await solicitar(
      uid == null ? 'POST' : 'PUT',
      uid == null ? '/api/users/register' : '/api/users/$uid',
      body: perfil,
    );
  }

  Future<List<String>> ciudades() async {
    final data = await solicitar(
      'GET',
      '/api/ciudades/ciudades',
      publico: true,
    );
    if (data == null) return [];
    if (data is! List) throw const FormatException('Catálogo inválido.');
    return data
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<List<Encomienda>> misEncomiendas() async {
    final data = await solicitar('GET', '/api/encomiendas');
    return filas(data, [
      'encomiendas',
      'items',
    ]).map(Encomienda.fromJson).toList();
  }

  Future<void> crearEncomienda(Map<String, dynamic> datos) async {
    await solicitar(
      'POST',
      '/api/encomiendas',
      body: {
        ...datos,
        'ciudadOrigen': ciudadParaApi(texto(datos['ciudadOrigen'])),
        'ciudadDestino': ciudadParaApi(texto(datos['ciudadDestino'])),
      },
    );
  }

  Future<List<Encomienda>> disponibles() async {
    final data = await solicitar('GET', '/api/encomiendas/disponibles2');
    return filas(data, [
      'disponibles',
      'encomiendas',
    ]).map(Encomienda.fromJson).toList();
  }

  Future<String?> nombreRemitente(Encomienda encomienda) async {
    // Esta respuesta no incluye uid: solo se toma el nombre del mismo envío.
    final data = await solicitar(
      'GET',
      '/api/encomiendas/disponibles',
      query: {'origen': encomienda.origen, 'destino': encomienda.destino},
    );
    final registro = filas(data)
        .where((e) => texto(e['_id']) == encomienda.id)
        .firstOrNull;
    final nombre = registro == null
        ? null
        : cadenaOpcional(registro['remitenteNombre']);
    return nombre ?? encomienda.remitenteNombre;
  }

  Future<ResultadoRuta> buscar(Viaje viaje, {List<Encomienda>? oferta}) async {
    final data = await solicitar(
      'GET',
      '/api/encomiendas/buscar',
      query: {'origen': viaje.origen, 'destino': viaje.destino},
    );
    if (data != null && data is! Map) {
      throw const FormatException('Respuesta inválida.');
    }
    final candidatas = oferta ?? await disponibles();
    return (
      disponibles: candidatas
          .where(
            (e) =>
                claveRuta(e.origen, e.destino) ==
                claveRuta(viaje.origen, viaje.destino),
          )
          .toList(),
      tomadas: filas(data?['tomadas']).map(Encomienda.fromJson).toList(),
    );
  }

  Future<PanelViajes> panelViajes(String uid, {DateTime? ahora}) async {
    final viajes = await misViajes();
    final porRuta = <String, Viaje>{};
    for (final v in viajes) {
      porRuta.putIfAbsent(claveRuta(v.origen, v.destino), () => v);
    }
    final oferta = viajes.any((v) => v.estado == 'disponible')
        ? await disponibles()
        : <Encomienda>[];
    final rutas = <String, ResultadoRuta>{};
    await Future.wait(
      porRuta.entries.map((entrada) async {
        final resultado = await buscar(entrada.value, oferta: oferta);
        rutas[entrada.key] = (
          disponibles: resultado.disponibles,
          tomadas: resultado.tomadas
              .where((e) => e.viajeroId == uid && e.uid != uid)
              .toList(),
        );
      }),
    );
    final fallosCierre = <String>{};
    for (var i = 0; i < viajes.length; i++) {
      final v = viajes[i];
      final cantidad = rutas[claveRuta(v.origen, v.destino)]!.tomadas
          .where((e) => e.viajeroId == uid && e.estado == 'tomada')
          .length;
      if (v.debeCerrar(cantidad, ahora: ahora)) {
        try {
          await cambiarViaje(v, 'completado');
          viajes[i] = v.conEstado('completado');
        } catch (_) {
          fallosCierre.add(v.id);
        }
      }
    }
    return PanelViajes(viajes, rutas, fallosCierre);
  }

  Future<bool> tomar(Encomienda encomienda, Viaje viaje, String uid) async {
    if (!viaje.permiteAceptar || !encomienda.compatibleCon(viaje, uid)) {
      throw const ApiException(
        'Esta encomienda ya no está disponible para tu viaje.',
      );
    }
    final actual = (await misViajes())
        .where((v) => v.id == viaje.id)
        .firstOrNull;
    if (actual == null || actual.estado != 'disponible') {
      throw const ApiException('Este viaje ya cerró su recepción.');
    }
    final ruta = await buscar(actual);
    final cantidad = ruta.tomadas
        .where((e) => e.viajeroId == uid && e.estado == 'tomada')
        .length;
    if (actual.debeCerrar(cantidad)) {
      await cambiarViaje(actual, 'completado');
      throw const ApiException('Este viaje ya cerró su recepción.');
    }
    final candidata = ruta.disponibles
        .where((e) => e.id == encomienda.id)
        .firstOrNull;
    if (candidata == null || !candidata.compatibleCon(actual, uid)) {
      throw const ApiException('La encomienda ya no está disponible.');
    }
    await solicitar('PUT', '/api/encomiendas/tomar/${encomienda.id}');
    // La aceptación ya se registró: no se repite aunque falle su cierre posterior.
    try {
      final despues = await buscar(actual);
      final total = despues.tomadas
          .where((e) => e.viajeroId == uid && e.estado == 'tomada')
          .length;
      if (actual.debeCerrar(total)) await cambiarViaje(actual, 'completado');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Encomienda> entregar(
    Encomienda encomienda,
    String uid, {
    Viaje? viaje,
  }) async {
    if (encomienda.viajeroId != uid ||
        encomienda.uid == uid ||
        encomienda.estado != 'tomada') {
      throw const ApiException(
        'Solo el viajero asignado puede marcar esta entrega.',
      );
    }
    if (viaje != null) {
      final panel = await panelViajes(uid);
      if (panel.viajes.any(
        (v) => v.id == viaje.id && v.estado == 'disponible',
      )) {
        throw const ApiException(
          'Cierra la recepción del viaje antes de registrar la entrega.',
        );
      }
      if (panel.fallosCierre.isNotEmpty) {
        throw const ApiException(
          'No pudimos actualizar el viaje. Reintenta antes de entregar.',
        );
      }
    }
    final data = await solicitar(
      'PUT',
      '/api/encomiendas/${encomienda.id}/estado',
      body: {'estado': 'recibida'},
    );
    return Encomienda.fromJson(data['encomienda']);
  }

  Future<List<Viaje>> misViajes() async {
    final data = await solicitar('GET', '/api/viajes');
    return filas(data, [
        'viajes',
        'items',
      ]).map(Viaje.fromJson).where((v) => v.id.isNotEmpty).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  Future<void> crearViaje(
    Vuelo vuelo, [
    String? origen,
    String? destino,
  ]) async {
    if (vuelo.origen.isEmpty ||
        vuelo.destino.isEmpty ||
        normalizar(vuelo.origen) == normalizar(vuelo.destino)) {
      throw const ApiException('No pudimos identificar la ruta del vuelo.');
    }
    await solicitar(
      'POST',
      '/api/viajes',
      body: vuelo.paraLapticon(
        ciudadParaApi(vuelo.origen),
        ciudadParaApi(vuelo.destino),
      ),
    );
  }

  Future<void> cambiarViaje(Viaje viaje, String estado) async {
    await solicitar(
      'PATCH',
      '/api/viajes/${viaje.id}/estado',
      body: {'estado': estado},
    );
  }
}

class PanelViajes {
  final List<Viaje> viajes;
  final Map<String, ResultadoRuta> rutas;
  final Set<String> fallosCierre;
  PanelViajes(this.viajes, this.rutas, this.fallosCierre);

  List<Encomienda> get pendientes => {
    for (final r in rutas.values)
      for (final e in r.tomadas)
        if (e.estado == 'tomada') e.id: e,
  }.values.toList();
  Viaje? get activo => viajes
      .where((v) => ['disponible', 'contactado'].contains(v.estado))
      .firstOrNull;
  Viaje? get fijado {
    if (activo != null) return activo;
    // Solo se asocia un viaje cuando la ruta no tiene varios candidatos históricos.
    final candidatos = viajes.where(
      (v) => pendientes.any(
        (e) => claveRuta(e.origen, e.destino) == claveRuta(v.origen, v.destino),
      ),
    );
    return candidatos.length == 1 ? candidatos.first : null;
  }

  bool get permiteNuevo =>
      activo == null && pendientes.isEmpty && fallosCierre.isEmpty;
  ResultadoRuta rutaDe(Viaje v) =>
      rutas[claveRuta(v.origen, v.destino)] ??
      (disponibles: <Encomienda>[], tomadas: <Encomienda>[]);
}
