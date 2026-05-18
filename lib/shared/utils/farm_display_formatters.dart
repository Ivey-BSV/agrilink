String formatFarmDisplayLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return value;
  return trimmed
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String formatFarmTypeLabel(String type) {
  const typeMap = {
    'cash_crops': 'Cash Crops',
    'specialty_crops': 'Specialty Crops',
    'livestock': 'Livestock',
    'mixed': 'Mixed Operation',
    'homestead': 'Homestead',
  };
  return typeMap[type] ?? formatFarmDisplayLabel(type);
}

String formatFarmEstablishedDate(DateTime date) {
  const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
}
