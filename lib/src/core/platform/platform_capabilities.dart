enum CvmlPlatformKind {
  desktop,
  web,
  mobile,
}

class PlatformCapabilities {
  const PlatformCapabilities({
    required this.kind,
    required this.supportsLocalStandaloneProjects,
    required this.supportsRemoteProjects,
    required this.supportsLocalDatasetPicker,
    required this.supportsServerConnection,
    required this.supportsLocalApEvaluator,
    required this.supportsReportDownload,
    required this.supportsReportShare,
  });

  final CvmlPlatformKind kind;
  final bool supportsLocalStandaloneProjects;
  final bool supportsRemoteProjects;
  final bool supportsLocalDatasetPicker;
  final bool supportsServerConnection;
  final bool supportsLocalApEvaluator;
  final bool supportsReportDownload;
  final bool supportsReportShare;

  bool get isMobile => kind == CvmlPlatformKind.mobile;

  static const PlatformCapabilities desktop = PlatformCapabilities(
    kind: CvmlPlatformKind.desktop,
    supportsLocalStandaloneProjects: true,
    supportsRemoteProjects: true,
    supportsLocalDatasetPicker: true,
    supportsServerConnection: true,
    supportsLocalApEvaluator: true,
    supportsReportDownload: true,
    supportsReportShare: false,
  );

  static const PlatformCapabilities web = PlatformCapabilities(
    kind: CvmlPlatformKind.web,
    supportsLocalStandaloneProjects: true,
    supportsRemoteProjects: true,
    supportsLocalDatasetPicker: true,
    supportsServerConnection: true,
    supportsLocalApEvaluator: false,
    supportsReportDownload: true,
    supportsReportShare: false,
  );

  static const PlatformCapabilities mobile = PlatformCapabilities(
    kind: CvmlPlatformKind.mobile,
    supportsLocalStandaloneProjects: false,
    supportsRemoteProjects: true,
    supportsLocalDatasetPicker: false,
    supportsServerConnection: true,
    supportsLocalApEvaluator: false,
    supportsReportDownload: false,
    supportsReportShare: false,
  );
}
