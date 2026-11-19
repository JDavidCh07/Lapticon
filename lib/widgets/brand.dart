import 'package:material_ui/material_ui.dart';

const azul = Color(0xFF3159D9);
const tinta = Color(0xFF182B50);
const fondo = Color(0xFFF3F6FC);

ThemeData temaLapticon() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: azul,
    primary: azul,
    secondary: const Color(0xFF1597A8),
  ),
  scaffoldBackgroundColor: fondo,
  fontFamily: 'sans-serif',
  appBarTheme: const AppBarTheme(
    backgroundColor: fondo,
    foregroundColor: tinta,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFE0E6F2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFE0E6F2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: azul, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      side: const BorderSide(color: Color(0xFFD6DFF2)),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: azul,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 3,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: const Color(0xFFE8EEFF),
    labelTextStyle: WidgetStateProperty.all(
      const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  ),
);

class MarcaLapticon extends StatelessWidget {
  final double size;
  const MarcaLapticon({super.key, this.size = 76});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Lapticon',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarcaPainter()),
    ),
  );
}

class _MarcaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 100, 100),
      const Radius.circular(28),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3D74F3), Color(0xFF2446BC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    canvas.drawCircle(
      const Offset(86, 12),
      35,
      Paint()..color = Colors.white.withValues(alpha: .07),
    );
    final avion = Path()
      ..moveTo(21, 43)
      ..lineTo(45, 47)
      ..lineTo(65, 23)
      ..quadraticBezierTo(70, 19, 72, 23)
      ..lineTo(60, 50)
      ..lineTo(78, 55)
      ..lineTo(75, 61)
      ..lineTo(56, 59)
      ..lineTo(48, 77)
      ..lineTo(41, 75)
      ..lineTo(43, 56)
      ..lineTo(22, 50)
      ..close();
    canvas.drawPath(avion, Paint()..color = Colors.white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(64, 68, 20, 18),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF63DBE5),
    );
    canvas.drawLine(
      const Offset(74, 69),
      const Offset(74, 76),
      Paint()
        ..color = const Color(0xFF2446BC)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE6EBF5)),
      boxShadow: [
        BoxShadow(
          color: tinta.withValues(alpha: .035),
          blurRadius: 20,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: tinta,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
