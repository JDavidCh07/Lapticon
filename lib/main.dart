import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';

import 'config.dart';
import 'screens/auth_screen.dart';
import 'screens/encomiendas_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/viajes_screen.dart';
import 'services/api_service.dart';
import 'widgets/common.dart';
import 'widgets/brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? error;
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (e) {
    error = e;
  }
  runApp(LapticonApp(errorInicial: error));
}

class LapticonApp extends StatelessWidget {
  final Object? errorInicial;
  const LapticonApp({super.key, this.errorInicial});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lapticon',
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: temaLapticon(),
    home: errorInicial != null
        ? Scaffold(
            body: ErrorView(
              error:
                  'No se pudo iniciar Firebase. ${textoError(errorInicial!)}',
              reintentar: main,
            ),
          )
        : StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return snapshot.data == null
                  ? const AuthScreen()
                  : InicioScreen(key: ValueKey(snapshot.data!.uid));
            },
          ),
  );
}

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});
  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen>
    with WidgetsBindingObserver {
  Timer? medianoche;
  bool revisando = false;
  int revision = 0;
  final api = ApiService();
  late Future<Map<String, dynamic>?> perfil;
  int pagina = 0;
  @override
  void initState() {
    super.initState();
    cargarPerfil();
    WidgetsBinding.instance.addObserver(this);
    revisarViajes();
    programarMedianoche();
  }

  void programarMedianoche() {
    medianoche?.cancel();
    final ahora = DateTime.now();
    medianoche = Timer(
      DateTime(ahora.year, ahora.month, ahora.day + 1).difference(ahora),
      () {
        revisarViajes();
        programarMedianoche();
      },
    );
  }

  Future<void> revisarViajes() async {
    if (revisando) return;
    revisando = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await api.panelViajes(uid);
    } catch (_) {
      // La pantalla de viajes permite consultar el error y reintentar.
    } finally {
      revisando = false;
      if (mounted) setState(() => revision++);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      revisarViajes();
      programarMedianoche();
    }
  }

  void cargarPerfil() =>
      perfil = api.perfil(FirebaseAuth.instance.currentUser!.uid);
  @override
  void dispose() {
    medianoche?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: perfil,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Lapticon'),
            actions: [
              IconButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                tooltip: 'Cerrar sesiÃ³n',
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: ErrorView(
            error: snapshot.error!,
            reintentar: () => setState(cargarPerfil),
          ),
        );
      }
      if (snapshot.data == null) {
        return PerfilScreen(
          inicial: const {},
          completarRegistro: true,
          onSaved: () => setState(cargarPerfil),
        );
      }
      return Scaffold(
        body: [
          const EncomiendasScreen(),
          ViajesScreen(key: ValueKey(revision)),
          PerfilScreen(
            inicial: snapshot.data!,
            onSaved: () => setState(cargarPerfil),
          ),
        ][pagina],
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: NavigationBar(
            selectedIndex: pagina,
            onDestinationSelected: (value) => setState(() => pagina = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'Encomiendas',
              ),
              NavigationDestination(
                icon: Icon(Icons.flight_takeoff),
                label: 'Viajes',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      );
    },
  );
}
