import 'message_key.dart';
import 'message_params.dart';

class LocalizedMessage {
  const LocalizedMessage({
    required this.key,
    this.params = const <String, Object?>{},
    this.fallback,
  });

  final MessageKey key;
  final MessageParams params;
  final String? fallback;
}
