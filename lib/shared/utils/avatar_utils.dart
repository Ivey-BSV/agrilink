String avatarInitialLetter(String name, {bool uppercase = true}) {
  if (name.isEmpty) return 'U';
  final letter = name[0];
  return uppercase ? letter.toUpperCase() : letter;
}
