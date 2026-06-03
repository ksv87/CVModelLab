typedef MessageParams = Map<String, Object?>;

String paramString(MessageParams params, String key, [String fallback = '']) {
  final Object? value = params[key];
  return value == null ? fallback : '$value';
}

int paramInt(MessageParams params, String key, [int fallback = 0]) {
  final Object? value = params[key];
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value') ?? fallback;
}

double paramDouble(MessageParams params, String key, [double fallback = 0]) {
  final Object? value = params[key];
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}
