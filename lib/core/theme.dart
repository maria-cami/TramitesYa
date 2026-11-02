import 'package:flutter/material.dart';

/// Paleta TrámitesYa: blanco, azul y naranja.
const kAzul = Color(0xFF0063DA); // navegación activa, enlaces, iconos
const kAzulSoft = Color(0xFFE6F0FF); // fondo suave del azul
const kBrand = Color(0xFFFF7C24); // naranja: acciones principales (CTA)
const kBrandSoft = Color(0xFFFFEFE3); // fondo suave del naranja
const kNavy = Color(0xFF062865); // títulos y texto de alto contraste
const kNavy2 = Color(0xFF0A3F96); // segundo tono para degradados
const kFondo = Color(0xFFF7FBFE); // fondo general
const kBorde = Color(0xFFD8E2EE);
const kGris = Color(0xFF64748B); // texto secundario
const kVerde = Color(0xFF16A34A); // éxito
const kAmbar = Color(0xFFF59E0B); // advertencia
const kError = Color(0xFFDC2626);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kAzul).copyWith(
    primary: kAzul,
    onPrimary: Colors.white,
    secondary: kBrand,
    onSecondary: Colors.white,
    onSurface: kNavy,
    surface: Colors.white,
    error: kError,
    outlineVariant: kBorde,
  );
  final borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: kBorde),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kFondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kNavy,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: kNavy,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: borde,
      enabledBorder: borde,
      focusedBorder: borde.copyWith(
        borderSide: const BorderSide(color: kAzul, width: 1.6),
      ),
    ),
    // Botón principal: naranja con texto blanco.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    // Botón secundario: fondo blanco y borde azul.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kAzul,
        backgroundColor: Colors.white,
        side: const BorderSide(color: kAzul),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kAzul),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: kAzul,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      checkmarkColor: Colors.white,
      side: const BorderSide(color: kBorde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    // Navegación: seleccionado en azul.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kAzulSoft,
      elevation: 8,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? kAzul : kGris,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? kAzul : kGris,
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kAzul.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorde),
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
  const IconoTile(this.icono, {super.key, this.color = kAzul, this.size = 48});

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