class ApEvalConfig {
  const ApEvalConfig({
    this.iouThresholds = const [
      0.50,
      0.55,
      0.60,
      0.65,
      0.70,
      0.75,
      0.80,
      0.85,
      0.90,
      0.95,
    ],
    this.maxDetections = 100,
    this.useCats = true,
  });

  final List<double> iouThresholds;
  final int maxDetections;
  final bool useCats;
}

class ClassApMetric {
  const ClassApMetric({
    required this.categoryId,
    required this.categoryName,
    this.ap,
    this.ap50,
    this.ap75,
    this.ar,
  });

  final int categoryId;
  final String categoryName;
  final double? ap;
  final double? ap50;
  final double? ap75;
  final double? ar;
}

class ApEvalResult {
  const ApEvalResult({
    this.ap,
    this.ap50,
    this.ap75,
    this.apSmall,
    this.apMedium,
    this.apLarge,
    this.ar1,
    this.ar10,
    this.ar100,
    this.arSmall,
    this.arMedium,
    this.arLarge,
    this.perClass = const [],
    required this.evaluatorName,
    required this.generatedAt,
    this.warnings = const [],
  });

  final double? ap;
  final double? ap50;
  final double? ap75;
  final double? apSmall;
  final double? apMedium;
  final double? apLarge;
  final double? ar1;
  final double? ar10;
  final double? ar100;
  final double? arSmall;
  final double? arMedium;
  final double? arLarge;
  final List<ClassApMetric> perClass;
  final String evaluatorName;
  final DateTime generatedAt;
  final List<String> warnings;
}

abstract interface class ApEvaluator {
  /// Returns null if all prerequisites are met, or a human-readable error.
  Future<String?> checkAvailability();

  /// Runs evaluation using on-disk file paths.
  Future<ApEvalResult> evaluate({
    required String annotationsPath,
    required String predictionsPath,
    ApEvalConfig config,
  });

  /// Runs evaluation from in-memory JSON strings (e.g. demo project).
  /// The implementation writes temp files and delegates to [evaluate].
  Future<ApEvalResult> evaluateFromJson({
    required String annotationsJson,
    required String predictionsJson,
    ApEvalConfig config,
  });
}

class ApEvalResultParser {
  const ApEvalResultParser();

  ApEvalResult fromJson(Map<String, dynamic> json) {
    final List<ClassApMetric> perClass = [];
    final dynamic perClassRaw = json['per_class'];
    if (perClassRaw is List) {
      for (final dynamic item in perClassRaw) {
        if (item is Map<String, dynamic>) {
          perClass.add(
            ClassApMetric(
              categoryId: (item['category_id'] as num?)?.toInt() ?? 0,
              categoryName: item['category_name'] as String? ?? '',
              ap: (item['ap'] as num?)?.toDouble(),
              ap50: (item['ap50'] as num?)?.toDouble(),
              ap75: (item['ap75'] as num?)?.toDouble(),
              ar: (item['ar'] as num?)?.toDouble(),
            ),
          );
        }
      }
    }

    final List<String> warnings = [];
    final dynamic warningsRaw = json['warnings'];
    if (warningsRaw is List) {
      for (final dynamic w in warningsRaw) {
        if (w is String) {
          warnings.add(w);
        }
      }
    }

    return ApEvalResult(
      ap: (json['ap'] as num?)?.toDouble(),
      ap50: (json['ap50'] as num?)?.toDouble(),
      ap75: (json['ap75'] as num?)?.toDouble(),
      apSmall: (json['ap_small'] as num?)?.toDouble(),
      apMedium: (json['ap_medium'] as num?)?.toDouble(),
      apLarge: (json['ap_large'] as num?)?.toDouble(),
      ar1: (json['ar1'] as num?)?.toDouble(),
      ar10: (json['ar10'] as num?)?.toDouble(),
      ar100: (json['ar100'] as num?)?.toDouble(),
      arSmall: (json['ar_small'] as num?)?.toDouble(),
      arMedium: (json['ar_medium'] as num?)?.toDouble(),
      arLarge: (json['ar_large'] as num?)?.toDouble(),
      perClass: perClass,
      evaluatorName: json['evaluator_name'] as String? ?? '',
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      warnings: warnings,
    );
  }

  Map<String, dynamic> toJson(ApEvalResult result) {
    return <String, dynamic>{
      'evaluator_name': result.evaluatorName,
      'generated_at': result.generatedAt.toUtc().toIso8601String(),
      if (result.ap != null) 'ap': result.ap,
      if (result.ap50 != null) 'ap50': result.ap50,
      if (result.ap75 != null) 'ap75': result.ap75,
      if (result.apSmall != null) 'ap_small': result.apSmall,
      if (result.apMedium != null) 'ap_medium': result.apMedium,
      if (result.apLarge != null) 'ap_large': result.apLarge,
      if (result.ar1 != null) 'ar1': result.ar1,
      if (result.ar10 != null) 'ar10': result.ar10,
      if (result.ar100 != null) 'ar100': result.ar100,
      if (result.arSmall != null) 'ar_small': result.arSmall,
      if (result.arMedium != null) 'ar_medium': result.arMedium,
      if (result.arLarge != null) 'ar_large': result.arLarge,
      'per_class': [
        for (final ClassApMetric cls in result.perClass)
          <String, dynamic>{
            'category_id': cls.categoryId,
            'category_name': cls.categoryName,
            if (cls.ap != null) 'ap': cls.ap,
            if (cls.ap50 != null) 'ap50': cls.ap50,
            if (cls.ap75 != null) 'ap75': cls.ap75,
            if (cls.ar != null) 'ar': cls.ar,
          },
      ],
      'warnings': result.warnings,
    };
  }
}
