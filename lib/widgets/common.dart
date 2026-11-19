import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/api_service.dart';
import 'brand.dart';

String? requerido(String? valor) =>
    valor == null || valor.trim().isEmpty ? 'Completa este campo.' : null;

String textoError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Escribe un correo válido.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'El correo o la contraseña no son correctos.',
      'email-already-in-use' => 'Ese correo ya está registrado.',
      'weak-password' => 'Usa al menos 6 caracteres.',
      'network-request-failed' => 'Revisa tu conexión a internet.',
      'too-many-requests' => 'Demasiados intentos. Intenta más tarde.',
      'user-disabled' => 'Esta cuenta está deshabilitada.',
      _ => 'No pudimos iniciar sesión. Intenta nuevamente.',
    };
  }
  if (error is ApiException) {
    if (RegExp(
      r'type |subtype|RAPIDAPI|API_KEY|Bearer|token|<html',
      caseSensitive: false,
    ).hasMatch(error.mensaje)) {
      return 'No pudimos completar la solicitud. Intenta nuevamente.';
    }
    return error.mensaje;
  }
  return 'No pudimos cargar la información. Intenta nuevamente.';
}

void avisar(BuildContext context, String mensaje) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(mensaje),
      ),
    );

Future<bool> confirmar(
  BuildContext context,
  String titulo,
  String mensaje,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback reintentar;
  const ErrorView({super.key, required this.error, required this.reintentar});
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Color(0xFFE8EEFF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              error is ApiException && (error as ApiException).conexion
                  ? Icons.wifi_off_rounded
                  : Icons.info_outline_rounded,
              size: 36,
              color: azul,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            textoError(error),
            textAlign: TextAlign.center,
            style: const TextStyle(color: tinta, fontSize: 16),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: reintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  final String texto;
  final IconData icono;
  const EmptyView(
    this.texto, {
    super.key,
    this.icono = Icons.inventory_2_outlined,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 16),
    child: Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEFF),
            borderRadius: BorderRadius.circular(34),
          ),
          child: Icon(icono, size: 46, color: azul),
        ),
        const SizedBox(height: 22),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: tinta,
          ),
        ),
      ],
    ),
  );
}

class EstadoChip extends StatelessWidget {
  final String estado;
  const EstadoChip(this.estado, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'recibida' || 'completado' => const Color(0xFF15816D),
      'tomada' || 'contactado' => const Color(0xFFBF7711),
      'vencida' || 'cancelado' || 'cancelada' => const Color(0xFFB34453),
      _ => azul,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              nombreEstado(estado),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RouteLine extends StatelessWidget {
  final String origen, destino;
  final bool claro;
  const RouteLine(this.origen, this.destino, {super.key, this.claro = false});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(
          origen,
          style: TextStyle(
            color: claro ? Colors.white : tinta,
            fontWeight: FontWeight.w800,
            fontSize: 21,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(
          Icons.arrow_forward_rounded,
          color: claro ? Colors.white70 : azul,
          size: 24,
        ),
      ),
      Expanded(
        child: Text(
          destino,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: claro ? Colors.white : tinta,
            fontWeight: FontWeight.w800,
            fontSize: 21,
          ),
        ),
      ),
    ],
  );
}

class ViajeCard extends StatelessWidget {
  final Viaje viaje;
  final int? pendientes;
  final VoidCallback? onTap;
  const ViajeCard({
    super.key,
    required this.viaje,
    this.pendientes,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF426CE5), Color(0xFF2446AE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: azul.withValues(alpha: .17),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flight_takeoff_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      viaje.numero,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      nombreEstado(viaje.estado),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              RouteLine(viaje.origen, viaje.destino, claro: true),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  Text(
                    mostrarFecha(viaje.fecha),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (pendientes != null)
                    Text(
                      '$pendientes / 3 encomiendas',
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class EncomiendaCard extends StatelessWidget {
  final Encomienda encomienda;
  final VoidCallback? onTap;
  const EncomiendaCard({super.key, required this.encomienda, this.onTap});
  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: azul,
                size: 21,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: EstadoChip(encomienda.estado),
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right, color: azul),
              ),
          ],
        ),
        const SizedBox(height: 16),
        RouteLine(encomienda.origen, encomienda.destino),
        if (encomienda.descripcion.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            encomienda.descripcion,
            style: const TextStyle(color: Color(0xFF596B88), height: 1.5),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              encomienda.precio,
              style: const TextStyle(
                color: tinta,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (encomienda.vencimiento != null)
              Text(
                'Hasta ${mostrarFecha(encomienda.vencimiento!.toLocal())}',
                style: const TextStyle(color: Color(0xFF78869D), fontSize: 12),
              ),
          ],
        ),
        if (encomienda.remitenteNombre?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            encomienda.remitenteNombre!,
            style: const TextStyle(color: Color(0xFF596B88)),
          ),
        ],
      ],
    ),
  );
}

class CiudadField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> ciudades;
  final String label;
  const CiudadField({
    super.key,
    required this.controller,
    required this.ciudades,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => Autocomplete<String>(
    initialValue: TextEditingValue(text: controller.text),
    optionsBuilder: (value) => value.text.trim().isEmpty
        ? const Iterable<String>.empty()
        : ciudades
              .where((c) => normalizar(c).contains(normalizar(value.text)))
              .take(12),
    onSelected: (value) => controller.text = value,
    fieldViewBuilder: (context, c, focus, submit) => TextFormField(
      controller: c,
      focusNode: focus,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.location_on_outlined),
      ),
      onChanged: (value) => controller.text = value,
      onFieldSubmitted: (_) => submit(),
      validator: (value) {
        if (requerido(value) != null) return 'Escribe una ciudad.';
        if (value!.trim().length < 2) return 'Escribe una ciudad válida.';
        return null;
      },
    ),
  );
}

String ciudadCanonica(List<String> ciudades, String texto) =>
    ciudadParaApi(texto, ciudades);

class BotonGuardar extends StatelessWidget {
  final bool ocupado;
  final VoidCallback onPressed;
  final String texto;
  const BotonGuardar({
    super.key,
    required this.ocupado,
    required this.onPressed,
    this.texto = 'Guardar',
  });
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: ocupado ? null : onPressed,
    child: ocupado
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(texto),
  );
}

class ProgresoEntrega extends StatelessWidget {
  final String estado;
  const ProgresoEntrega(this.estado, {super.key});
  @override
  Widget build(BuildContext context) {
    final actual = switch (estado) {
      'disponible' => 0,
      'tomada' => 1,
      'recibida' => 2,
      _ => -1,
    };
    if (actual < 0) return EstadoChip(estado);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= actual ? azul : const Color(0xFFEDF1F8),
                  ),
                  child: Icon(
                    [
                      Icons.inventory_2_outlined,
                      Icons.flight_takeoff,
                      Icons.check_rounded,
                    ][i],
                    color: i <= actual ? Colors.white : const Color(0xFF98A4BA),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ['Disponible', 'Tomada', 'Entregada'][i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: i <= actual ? tinta : const Color(0xFF98A4BA),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
