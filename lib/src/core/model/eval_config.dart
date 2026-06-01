enum SmallObjectMode {
  coco,
}

class EvalConfig {
  const EvalConfig({
    this.iouThreshold = 0.5,
    this.confidenceThreshold = 0.25,
    this.classAwareMatching = true,
    this.ignoreCrowd = true,
    this.smallObjectMode = SmallObjectMode.coco,
  });

  final double iouThreshold;
  final double confidenceThreshold;
  final bool classAwareMatching;
  final bool ignoreCrowd;
  final SmallObjectMode smallObjectMode;

  EvalConfig copyWith({
    double? iouThreshold,
    double? confidenceThreshold,
    bool? classAwareMatching,
    bool? ignoreCrowd,
    SmallObjectMode? smallObjectMode,
  }) {
    return EvalConfig(
      iouThreshold: iouThreshold ?? this.iouThreshold,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      classAwareMatching: classAwareMatching ?? this.classAwareMatching,
      ignoreCrowd: ignoreCrowd ?? this.ignoreCrowd,
      smallObjectMode: smallObjectMode ?? this.smallObjectMode,
    );
  }
}
