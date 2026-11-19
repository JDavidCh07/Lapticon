String normalizar(String texto) {
  var resultado = texto.trim().toLowerCase();
  const acentos = 'áéíóúüñ';
  const simples = 'aeiouun';
  for (var i = 0; i < acentos.length; i++) {
    resultado = resultado.replaceAll(acentos[i], simples[i]);
  }
  return resultado
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String fechaApi(DateTime fecha) =>
    '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

// fechaViaje es una fecha de calendario, no se convierte de UTC a hora local.
DateTime? leerDia(dynamic valor) {
  if (valor == null) return null;
  final texto = valor.toString();
  return DateTime.tryParse(texto.length >= 10 ? texto.substring(0, 10) : texto);
}

DateTime? leerInstante(dynamic valor) =>
    valor == null ? null : DateTime.tryParse(valor.toString());

String mostrarFecha(DateTime? fecha) => fecha == null
    ? '—'
    : '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

String nombreEstado(String estado) => switch (estado) {
  'disponible' => 'Disponible',
  'tomada' => 'Tomada',
  'recibida' => 'Entregada',
  'vencida' => 'Vencida',
  'completado' => 'Completado',
  'cancelado' || 'cancelada' => 'Cancelado',
  'contactado' => 'Contactado',
  _ => estado,
};

class Viaje {
  final String id, uid, numero, origen, destino, estado;
  final DateTime fecha;

  Viaje.fromJson(Map<String, dynamic> json)
    : id = texto(json['_id']),
      uid = texto(json['uid']),
      numero = texto(json['numeroVuelo']),
      origen = texto(json['ciudadOrigen']),
      destino = texto(json['ciudadDestino']),
      estado = texto(json['estado']),
      fecha =
          leerDia(json['fechaViaje']) ??
          (throw const FormatException('Fecha de viaje inválida.'));

  Viaje conEstado(String nuevo) => Viaje.fromJson({
    '_id': id,
    'uid': uid,
    'numeroVuelo': numero,
    'ciudadOrigen': origen,
    'ciudadDestino': destino,
    'estado': nuevo,
    'fechaViaje': fechaApi(fecha),
  });

  bool debeCerrar(int cantidad, {DateTime? ahora}) {
    final hoy = ahora ?? DateTime.now();
    return estado == 'disponible' &&
        (cantidad >= 3 ||
            !fecha.isAfter(DateTime(hoy.year, hoy.month, hoy.day)));
  }

  bool get permiteAceptar {
    final hoy = DateTime.now();
    return estado == 'disponible' &&
        fecha.isAfter(DateTime(hoy.year, hoy.month, hoy.day));
  }
}

class Encomienda {
  final String id, uid, origen, destino, descripcion, moneda, estado;
  final String? viajeroId, remitenteNombre, viajeroNombre, viajeroTelefono;
  final double? valor;
  final DateTime? creacion, vencimiento, disponibleDesde, limiteEntrega;

  Encomienda.fromJson(Map<String, dynamic> json)
    : id = texto(json['_id']),
      uid = texto(json['uid']),
      origen = texto(json['ciudadOrigen']),
      destino = texto(json['ciudadDestino']),
      descripcion = json['observaciones']?.toString() ?? '',
      moneda = json['moneda']?.toString() ?? '',
      estado = texto(json['estado']),
      viajeroId = texto(json['viajeroId']).isEmpty
          ? null
          : texto(json['viajeroId']),
      remitenteNombre = cadenaOpcional(json['remitenteNombre']),
      viajeroNombre = nombreContacto(json['viajeroId']),
      viajeroTelefono = json['viajeroId'] is Map
          ? cadenaOpcional(json['viajeroId']['telefono'])
          : null,
      valor = numeroOpcional(json['valor']),
      creacion = leerInstante(json['fechaCreacion']),
      vencimiento = leerInstante(json['fechaVencimiento']),
      disponibleDesde = leerInstante(json['fechaDisponibleDesde']),
      limiteEntrega = leerInstante(json['fechaLimiteEntrega']),
      _viajeAsociado = leerViajeAsociado(json['viaje']);

  String get precio =>
      valor == null ? '—' : '$moneda ${valor!.toStringAsFixed(2)}';

  Viaje? get viajeAsociado => _viajeAsociado;
  final Viaje? _viajeAsociado;

  bool get finalizada => !['disponible', 'tomada'].contains(estado);

  bool compatibleCon(Viaje viaje, String usuario, {DateTime? ahora}) {
    final hoy = ahora ?? DateTime.now();
    if (id.isEmpty ||
        uid.isEmpty ||
        uid == usuario ||
        estado != 'disponible' ||
        viajeroId != null) {
      return false;
    }
    if (normalizar(origen) != normalizar(viaje.origen) ||
        normalizar(destino) != normalizar(viaje.destino)) {
      return false;
    }
    if (vencimiento != null && !vencimiento!.isAfter(hoy)) return false;
    // La API solo guarda el día del viaje: comparamos días de calendario.
    for (final limite in [vencimiento, limiteEntrega]) {
      if (limite != null &&
          viaje.fecha.isAfter(leerDia(limite.toLocal().toIso8601String())!)) {
        return false;
      }
    }
    if (disponibleDesde != null &&
        viaje.fecha.isBefore(
          leerDia(disponibleDesde!.toLocal().toIso8601String())!,
        )) {
      return false;
    }
    return true;
  }
}

class Vuelo {
  final String numero, aerolinea, origen, destino, salida, llegada;
  final String codigoOrigen, codigoDestino, estado;
  final DateTime fecha;

  Vuelo.fromJson(Map<String, dynamic> json)
    : numero = json['number'].toString().replaceAll(' ', '').toUpperCase(),
      aerolinea = json['airline']?['name']?.toString() ?? 'Aerolínea',
      origen = _ciudad(json['departure']['airport']),
      destino = _ciudad(json['arrival']['airport']),
      codigoOrigen = json['departure']['airport']['iata']?.toString() ?? '',
      codigoDestino = json['arrival']['airport']['iata']?.toString() ?? '',
      salida = json['departure']['scheduledTime']?['local']?.toString() ?? '',
      llegada = json['arrival']['scheduledTime']?['local']?.toString() ?? '',
      estado = json['status']?.toString() ?? '',
      fecha =
          leerDia(json['departure']['scheduledTime']?['local']) ??
          (throw const FormatException(
            'El proveedor no informó la fecha de salida.',
          ));

  static String _ciudad(Map<String, dynamic> aeropuerto) {
    final ciudad = aeropuerto['municipalityName']?.toString().trim() ?? '';
    // No confundir un nombre de aeropuerto con una ciudad del catálogo.
    return ciudad;
  }

  bool get cancelado =>
      ['canceled', 'cancelled'].contains(estado.toLowerCase());

  Map<String, dynamic> paraLapticon(
    String ciudadOrigen,
    String ciudadDestino,
  ) => {
    'numeroVuelo': numero,
    'ciudadOrigen': ciudadOrigen,
    'ciudadDestino': ciudadDestino,
    'fechaViaje': fechaApi(fecha),
  };
}

String texto(dynamic valor) {
  if (valor is String) return valor.trim();
  if (valor is Map) return texto(valor['uid'] ?? valor['_id']);
  return '';
}

double? numeroOpcional(dynamic valor) {
  final n = valor is num
      ? valor.toDouble()
      : double.tryParse(valor?.toString() ?? '');
  return n != null && n.isFinite ? n : null;
}

Viaje? leerViajeAsociado(dynamic valor) {
  if (valor is! Map) return null;
  try {
    return Viaje.fromJson(Map<String, dynamic>.from(valor));
  } on FormatException {
    return null;
  }
}

// Se utiliza al guardar tanto viajes como encomiendas. El catálogo es opcional.
String ciudadParaApi(String nombre, [List<String> catalogo = const []]) {
  final clave = normalizar(nombre);
  final coincidencia = catalogo
      .where((c) => normalizar(c) == clave)
      .firstOrNull;
  return normalizar(coincidencia ?? nombre)
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

String claveRuta(String origen, String destino) =>
    '${normalizar(origen)}|${normalizar(destino)}';

List<Map<String, dynamic>> filas(
  dynamic data, [
  List<String> envolturas = const [],
]) {
  if (data == null) return [];
  if (data is Map) {
    for (final campo in envolturas) {
      if (data.containsKey(campo)) return filas(data[campo]);
    }
    throw const FormatException('Lista inválida.');
  }
  if (data is! List) throw const FormatException('Lista inválida.');
  return data.where((e) => e != null).map((e) {
    if (e is! Map) throw const FormatException('Registro inválido.');
    return Map<String, dynamic>.from(e);
  }).toList();
}

String? cadenaOpcional(dynamic valor) =>
    valor is String && valor.trim().isNotEmpty ? valor.trim() : null;

String? nombreContacto(dynamic valor) {
  if (valor is! Map) return null;
  final partes = [
    cadenaOpcional(valor['nombre']),
    cadenaOpcional(valor['apellido']),
  ].whereType<String>().join(' ');
  return partes.isEmpty ? null : partes;
}
