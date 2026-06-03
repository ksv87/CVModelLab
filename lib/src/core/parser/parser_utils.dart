import '../i18n/message_key.dart';
import '../model/bbox.dart';
import 'parse_result.dart';

typedef IssueSink = void Function(ParseIssue issue);

int? readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value % 1 == 0) {
    return value.toInt();
  }
  return null;
}

double? readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

BBox? readBBox(Object? value, String path, IssueSink addIssue) {
  if (value is! List || value.length != 4) {
    addIssue(
      ParseIssue(
        severity: ParseIssueSeverity.warning,
        message: 'bbox must contain exactly 4 numbers',
        path: path,
        key: MessageKey.parseBboxMustHaveFourNumbers,
      ),
    );
    return null;
  }

  final List<double> numbers = [];
  for (var index = 0; index < value.length; index += 1) {
    final double? number = readDouble(value[index]);
    if (number == null) {
      addIssue(
        ParseIssue(
          severity: ParseIssueSeverity.warning,
          message: 'bbox value must be numeric',
          path: '$path[$index]',
          key: MessageKey.parseBboxMustHaveFourNumbers,
        ),
      );
      return null;
    }
    numbers.add(number);
  }

  if (numbers[2] <= 0 || numbers[3] <= 0) {
    addIssue(
      ParseIssue(
        severity: ParseIssueSeverity.warning,
        message: 'bbox width and height must be positive',
        path: path,
        key: MessageKey.parseBboxNonPositiveSize,
      ),
    );
    return null;
  }

  return BBox(
    x: numbers[0],
    y: numbers[1],
    width: numbers[2],
    height: numbers[3],
  );
}

String basename(String path) {
  final String normalized = path.replaceAll('\\', '/');
  final int slashIndex = normalized.lastIndexOf('/');
  return slashIndex == -1 ? normalized : normalized.substring(slashIndex + 1);
}
