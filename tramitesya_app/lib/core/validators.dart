/// Validaciones de formulario según los campos definidos en las historias de usuario.
/// Se repiten en backend (CHECK de la base de datos): nunca confiar solo en el cliente.
class Validators {
  static String? requerido(String? v, [String campo = 'Este campo']) {
    if (v == null || v.trim().isEmpty) return '$campo es obligatorio';
    return null;
  }

  static String? nombre(String? v) {
    if (v == null || v.trim().length < 3) {
      return 'Ingresa tu nombre completo (mínimo 3 caracteres)';
    }
    return null;
  }

  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'El correo es obligatorio';
    if (!_emailRe.hasMatch(v.trim())) return 'Ingresa un correo válido';
    return null;
  }

  /// HU01: mínimo 8 caracteres, 1 mayúscula y 1 número.
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Incluye al menos una mayúscula';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Incluye al menos un número';
    return null;
  }

  static String? passwordLogin(String? v) {
    if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
    return null;
  }

  static String? confirmar(String? v, String original) {
    if (v == null || v.isEmpty) return 'Confirma tu contraseña';
    if (v != original) return 'Las contraseñas no coinciden';
    return null;
  }

  static final _telRe = RegExp(r'^\+?\d{10,13}$');

  static String? telefono(String? v) {
    if (v == null || v.trim().isEmpty) return 'El teléfono es obligatorio';
    final limpio = v.replaceAll(RegExp(r'[\s-]'), '');
    if (!_telRe.hasMatch(limpio)) {
      return 'Teléfono inválido (10 a 13 dígitos, opcional +57)';
    }
    return null;
  }

  /// Texto con límites de longitud (HU10: descripción 10–500, notas ≤ 300, etc.).
  static String? largo(
    String? v, {
    required String campo,
    int min = 0,
    required int max,
    bool obligatorio = true,
  }) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return obligatorio ? '$campo es obligatorio' : null;
    if (t.length < min) return '$campo debe tener al menos $min caracteres';
    if (t.length > max) return '$campo no puede superar $max caracteres';
    return null;
  }
}
