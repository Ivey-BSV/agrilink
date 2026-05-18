String normalizeUsername(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return '';
  s = s.replaceAll('@', '_');
  s = s.replaceAll(RegExp(r'\s+'), '_');
  s = s.replaceAll(RegExp(r'_+'), '_');
  s = s.replaceAll(RegExp(r'^_+|_+$'), '');
  return s;
}

String? validateUsernameField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter a username';
  }
  if (value.contains('@')) {
    return 'Usernames cannot contain @. Use underscores (_) instead.';
  }
  if (value.contains(RegExp(r'\s'))) {
    return 'Usernames cannot contain spaces. Use underscores (_) instead.';
  }
  final n = normalizeUsername(value);
  if (n.length < 2) {
    return 'Username must be at least 2 characters';
  }
  return null;
}
