import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models.dart';
import 'api_service.dart';

class VuelosService {
  final http.Client client;
  final String key;
  VuelosService({http.Client? client, this.key = aerodataKey})
    : client = client ?? http.Client();
  void close() => client.close();

  Future<List<Vuelo>> consultar(String numero, DateTime fecha) async {
    if (key.trim().isEmpty ||
        key.startsWith('PEGA_AQUI_') ||
        key.startsWith('TU_CLAVE_')) {
      throw const ApiException(
        'La consulta de vuelos no está disponible en este momento.',
      );
    }
    final codigo = numero.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final uri = Uri.https(
      aerodataHost,
      '/flights/number/$codigo/${fechaApi(fecha)}',
      {
        'dateLocalRole': 'Departure',
        'withAircraftImage': 'false',
        'withLocation': 'false',
      },
    );
    try {
      final r = await client
          .get(
            uri,
            headers: {
              'X-RapidAPI-Key': key.trim(),
              'X-RapidAPI-Host': aerodataHost,
            },
          )
          .timeout(const Duration(seconds: 30));
      if ([204, 404].contains(r.statusCode)) {
        throw const ApiException(
          'No se encontró el vuelo en esa fecha. Prueba otro código o día.',
        );
      }
      if ([401, 403].contains(r.statusCode)) {
        throw const ApiException(
          'El servicio de vuelos no pudo autorizar la consulta.',
        );
      }
      if (r.statusCode == 429) {
        throw const ApiException(
          'Se alcanzó el límite de consultas de AeroDataBox. Intenta más tarde.',
        );
      }
      if (r.statusCode != 200) {
        throw ApiException(
          'No se pudo consultar AeroDataBox (${r.statusCode}).',
        );
      }
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      if (data is! List) throw const FormatException();
      final vuelos = <Vuelo>[];
      for (final item in data) {
        // Los registros incompletos no se presentan como vuelos verificados.
        try {
          final registro = Map<String, dynamic>.from(item);
          for (final extremo in ['departure', 'arrival']) {
            final aeropuerto = registro[extremo]?['airport'];
            if (aeropuerto is Map &&
                texto(aeropuerto['municipalityName']).isEmpty &&
                texto(aeropuerto['iata']).isNotEmpty) {
              final respuesta = await client
                  .get(
                    Uri.https(
                      aerodataHost,
                      '/airports/iata/${aeropuerto['iata']}',
                    ),
                    headers: {
                      'X-RapidAPI-Key': key.trim(),
                      'X-RapidAPI-Host': aerodataHost,
                    },
                  )
                  .timeout(const Duration(seconds: 30));
              if (respuesta.statusCode != 200) {
                throw const ApiException(
                  'No pudimos identificar las ciudades del vuelo. Intenta nuevamente.',
                );
              }
              final detalle = jsonDecode(utf8.decode(respuesta.bodyBytes));
              aeropuerto['municipalityName'] = detalle['municipalityName'];
            }
          }
          final vuelo = Vuelo.fromJson(registro);
          if (fechaApi(vuelo.fecha) == fechaApi(fecha) &&
              vuelo.numero == codigo &&
              vuelo.codigoOrigen.isNotEmpty &&
              vuelo.codigoDestino.isNotEmpty &&
              vuelo.origen.isNotEmpty &&
              vuelo.destino.isNotEmpty &&
              !vuelo.cancelado) {
            vuelos.add(vuelo);
          }
        } on FormatException {
          continue;
        } on TypeError {
          continue;
        } on NoSuchMethodError {
          continue;
        }
      }
      if (vuelos.isEmpty) {
        throw const ApiException(
          'No hay una salida utilizable para esa fecha: el vuelo puede estar cancelado o tener datos incompletos.',
        );
      }
      return vuelos;
    } on TimeoutException {
      throw const ApiException(
        'La consulta del vuelo tardó demasiado. Puedes reintentar.',
      );
    } on http.ClientException {
      throw const ApiException(
        'No se pudo conectar con AeroDataBox. Revisa tu conexión.',
      );
    } on FormatException {
      throw const ApiException(
        'AeroDataBox devolvió datos que no pudimos interpretar.',
      );
    }
  }
}
