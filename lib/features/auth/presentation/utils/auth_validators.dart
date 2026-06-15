bool isValidEmail(String value) {
  final s = value.trim();
  if (s.isEmpty) return false;
  return RegExp(r'^[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}$').hasMatch(s);
}

String? validatePassword(String password) {
  if (password.length < 6) {
    return 'La contraseña debe tener al menos 6 caracteres';
  }
  return null;
}
