import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/common.dart';
import '../widgets/brand.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final correo = TextEditingController();
  final clave = TextEditingController();
  final confirmacion = TextEditingController();
  bool registro = false, ocupado = false, ocultar = true;
  String? error;
  @override
  void dispose() {
    correo.dispose();
    clave.dispose();
    confirmacion.dispose();
    super.dispose();
  }

  Future<void> entrar() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      if (registro) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: correo.text.trim(),
          password: clave.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: correo.text.trim(),
          password: clave.text,
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = textoError(e));
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MarcaLapticon(size: 88)),
                  const SizedBox(height: 12),
                  Text(
                    'Lapticon',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: tinta,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 32),
                  Text(
                    registro ? 'Crea tu cuenta' : 'Inicia sesión',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: correo,
                    enabled: !ocupado,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                    validator: (v) =>
                        v == null ||
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(v.trim())
                        ? 'Escribe un correo válido.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: clave,
                    enabled: !ocupado,
                    obscureText: ocultar,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      suffixIcon: IconButton(
                        tooltip: ocultar
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: () => setState(() => ocultar = !ocultar),
                        icon: Icon(
                          ocultar ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 6
                        ? 'Usa al menos 6 caracteres.'
                        : null,
                  ),
                  if (registro) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmacion,
                      enabled: !ocupado,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirma la contraseña',
                      ),
                      validator: (v) => v != clave.text
                          ? 'Las contraseñas no coinciden.'
                          : null,
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  BotonGuardar(
                    ocupado: ocupado,
                    onPressed: entrar,
                    texto: registro ? 'Crear cuenta' : 'Entrar',
                  ),
                  TextButton(
                    onPressed: ocupado
                        ? null
                        : () => setState(() {
                            registro = !registro;
                            error = null;
                            form.currentState?.reset();
                          }),
                    child: Text(
                      registro ? 'Ya tengo una cuenta' : 'Quiero registrarme',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
