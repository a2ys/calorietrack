/// Time-of-day greeting: "Good morning" with a matching emoji.
({String text, String emoji}) greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return (text: 'Good morning', emoji: '☀️');
  if (h >= 12 && h < 17) return (text: 'Good afternoon', emoji: '🌤️');
  if (h >= 17 && h < 21) return (text: 'Good evening', emoji: '🌆');
  // Late night and the small hours stay calm: still just "Good evening".
  return (text: 'Good evening', emoji: '🌙');
}

/// First word of a name, trimmed: "  Aayush Shukla " -> "Aayush".
String firstName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}
