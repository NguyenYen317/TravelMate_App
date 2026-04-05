enum AIChatRole { user, bot }

class AIChatMessage {
  const AIChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final AIChatRole role;
  final String text;
  final DateTime createdAt;
}
