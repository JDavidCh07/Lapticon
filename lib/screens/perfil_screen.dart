import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import '../widgets/brand.dart';

class PerfilScreen extends StatefulWidget {
  final Map<String, dynamic> inicial;
  final bool completarRegistro;
  final VoidCallback? onSaved;
  const PerfilScreen({
    super.key,
    required this.inicial,
    this.completarRegistro = false,
    this.onSaved,
  });
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final api = ApiService();
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> campos;
  DateTime? nacimiento;
  bool ocupado = false;
  String? error;
  @override
  void initState() {
    super.initState();
    campos = {
      for (final key in ['nombre', 'apellido', 'telefono', 'nacionalidad'])
        key: TextEditingController(text: widget.inicial[key]?.toString() ?? ''),
    };
    nacimiento = leerDia(widget.inicial['fechaNacimiento']);
  }

  @override
  void dispose() {
    for (final c in campos.values) {
      c.dispose();
    }
    api.close();
    super.dispose();
  }

  Future<void> guardar() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await api.guardarPerfil(
        {
          for (final entrada in campos.entries)
            entrada.key: entrada.value.text.trim(),
          if (nacimiento != null) 'fechaNacimiento': fechaApi(nacimiento!),
        },
        uid: widget.completarRegistro
            ? null
            : FirebaseAuth.instance.currentUser!.uid,
      );
      if (!mounted) return;
      avisar(context, 'Perfil guardado.');
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) setState(() => error = textoError(e));
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.completarRegistro ? 'Completa tu perfil' : 'Mi perfil',
      ),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFEAF0FF),
                  child: Icon(Icons.person_outline, color: azul, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.inicial['nombre']?.toString() ?? 'Mi cuenta',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        FirebaseAuth.instance.currentUser!.email ?? '',
                        style: const TextStyle(color: Color(0xFF6A7891)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final entrada in {
            'nombre': 'Nombre',
            'apellido': 'Apellido',
            'telefono': 'Teléfono',
            'nacionalidad': 'Nacionalidad',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: campos[entrada.key],
                enabled: !ocupado,
                keyboardType: entrada.key == 'telefono'
                    ? TextInputType.phone
                    : TextInputType.text,
                decoration: InputDecoration(labelText: entrada.value),
                validator: (v) {
                  if (requerido(v) != null) return 'Completa este campo.';
                  if (entrada.key == 'telefono' &&
                      !RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(v!.trim())) {
                    return 'Escribe un teléfono válido.';
                  }
                  return null;
                },
              ),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(
              nacimiento == null
                  ? 'Fecha de nacimiento (opcional)'
                  : mostrarFecha(nacimiento),
            ),
            onPressed: ocupado
                ? null
                : () async {
                    final hoy = DateTime.now();
                    final f = await showDatePicker(
                      context: context,
                      initialDate:
                          nacimiento != null && !nacimiento!.isAfter(hoy)
                          ? nacimiento
                          : DateTime(hoy.year - 18),
                      firstDate: DateTime(1900),
                      lastDate: hoy,
                    );
                    if (f != null && mounted) setState(() => nacimiento = f);
                  },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          BotonGuardar(
            ocupado: ocupado,
            onPressed: guardar,
            texto: 'Guardar perfil',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            onPressed: ocupado
                ? null
                : () async {
                    if (!await confirmar(
                      context,
                      'Cerrar sesión',
                      '¿Quieres salir de tu cuenta?',
                    )) {
                      return;
                    }
                    try {
                      await FirebaseAuth.instance.signOut();
                    } catch (e) {
                      if (context.mounted) avisar(context, textoError(e));
                    }
                  },
          ),
        ],
      ),
    ),
  );
}
