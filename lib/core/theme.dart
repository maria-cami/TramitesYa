import 'package:flutter/material.dart';

/// Paleta TrámitesYa: naranja de acción + azul marino corporativo.
const kBrand = Color(0xFFFF5B00); // CTA, selección activa
const kNavy = Color(0xFF0B1C33); // textos, cabeceras
const kNavy2 = Color(0xFF12263F); // segundo tono para degradados
const kBrandSoft = Color(0xFFFFEDE2); // fondo suave del naranja
const kFondo = Color(0xFFF4F6F8);
const kGris = Color(0xFF8A92A6);
const kVerde = Color(0xFF10B981);
const kAmbar = Color(0xFFF59E0B);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kBrand).copyWith(
    primary: kBrand,
    onPrimary: Colors.white,
    onSurface: kNavy,
    outlineVariant: const Color(0xFFE3E7EE),
  );
  final borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kFondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: borde,
      enabledBorder: borde,
      focusedBorder: borde.copyWith(
        borderSide: const BorderSide(color: kBrand, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrand,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: kBrand,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      checkmarkColor: Colors.white,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kBrandSoft,
      elevation: 8,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? kBrand : kGris,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? kBrand : kGris,
        ),
      ),
    ),
  );
}

/// Tarjeta simple del proyecto (evita depender de CardTheme/CardThemeData,
/// que cambió de nombre entre versiones de Flutter).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kBrand.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: padding ?? const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE9EDF3)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Icono dentro de un cuadrado redondeado de color suave (como en el mockup).
class IconoTile extends StatelessWidget {
  const IconoTile(this.icono, {super.key, this.color = kBrand, this.size = 48});

  final IconData icono;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icono, color: color, size: size * 0.52),
    );
  }
}
