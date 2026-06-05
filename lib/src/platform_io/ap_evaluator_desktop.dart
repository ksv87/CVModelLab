import 'dart:convert';
import 'dart:io';

import '../core/ap_eval/ap_eval_models.dart';
import 'ap_eval_script.dart';

ApEvaluator createApEvaluator() => const _DesktopApEvaluator();

enum _Runner { uv, python3 }

// Resolved absolute paths — detected once per app session.
String? _resolvedUv;
String? _resolvedPython3;
_Runner? _detectedRunner;
bool _runnerDetected = false;

class _DesktopApEvaluator implements ApEvaluator {
  const _DesktopApEvaluator();

  bool get _isNativeMobile => Platform.isAndroid || Platform.isIOS;

  Future<_Runner?> _detectRunner() async {
    if (_runnerDetected) return _detectedRunner;
    _runnerDetected = true;

    // Prefer uv: login shell first (picks up ~/.zprofile PATH on macOS),
    // then explicit candidate paths for GUI apps that lack shell PATH.
    final String? uvPath =
        await _resolveViaLoginShell('uv') ?? _findInCandidates(_uvCandidates());
    if (uvPath != null) {
      _resolvedUv = uvPath;
      return _detectedRunner = _Runner.uv;
    }

    // Fallback: bare python3 with pycocotools already installed.
    final String? py = await _resolveViaLoginShell('python3') ??
        _findInCandidates(_python3Candidates());
    if (py != null) {
      try {
        final ProcessResult r =
            await Process.run(py, ['-c', 'import pycocotools']);
        if (r.exitCode == 0) {
          _resolvedPython3 = py;
          return _detectedRunner = _Runner.python3;
        }
      } on ProcessException {
        // python3 found but pycocotools not installed.
      }
    }

    return null;
  }

  /// Runs `which <cmd>` inside a login shell to pick up user PATH.
  /// Returns the absolute path or null. Only used for detection; execution
  /// always uses the resolved absolute path directly.
  Future<String?> _resolveViaLoginShell(String cmd) async {
    if (Platform.isWindows) return null;
    final List<String> shells = ['/bin/zsh', '/bin/bash'];
    for (final String shell in shells) {
      if (!File(shell).existsSync()) continue;
      try {
        final ProcessResult r =
            await Process.run(shell, ['-l', '-c', 'which $cmd']);
        if (r.exitCode == 0) {
          final String path =
              (r.stdout as String).trim().split('\n').first.trim();
          if (path.isNotEmpty && File(path).existsSync()) return path;
        }
      } on ProcessException {
        continue;
      }
    }
    return null;
  }

  /// Checks a list of well-known install locations without PATH.
  String? _findInCandidates(List<String> candidates) {
    for (final String path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  List<String> _uvCandidates() {
    if (Platform.isWindows) {
      final String local = Platform.environment['LOCALAPPDATA'] ?? '';
      return [if (local.isNotEmpty) '$local\\uv\\uv.exe'];
    }
    final String home = Platform.environment['HOME'] ?? '';
    return [
      if (home.isNotEmpty) '$home/.local/bin/uv',
      if (home.isNotEmpty) '$home/.cargo/bin/uv',
      '/opt/homebrew/bin/uv',
      '/usr/local/bin/uv',
      '/usr/bin/uv',
    ];
  }

  List<String> _python3Candidates() {
    if (Platform.isWindows) return [];
    return [
      '/opt/homebrew/bin/python3',
      '/usr/local/bin/python3',
      '/usr/bin/python3',
    ];
  }

  @override
  Future<String?> checkAvailability() async {
    if (_isNativeMobile) {
      return 'COCO AP evaluation runs on the server for Android/iOS clients. '
          'Local AP evaluation is not available on mobile.';
    }
    final _Runner? runner = await _detectRunner();
    if (runner != null) return null;
    return 'AP evaluation requires one of:\n'
        '- uv (recommended) — install from https://docs.astral.sh/uv/\n'
        '  uv handles Python and pycocotools automatically.\n'
        '- Python 3.8+ with pycocotools — run: pip install pycocotools';
  }

  @override
  Future<ApEvalResult> evaluate({
    required String annotationsPath,
    required String predictionsPath,
    ApEvalConfig config = const ApEvalConfig(),
  }) async {
    if (_isNativeMobile) {
      throw Exception('Local AP evaluation is not available on mobile.');
    }
    final _Runner? runner = await _detectRunner();
    if (runner == null) throw Exception(await checkAvailability());

    // Write the embedded sidecar to a temp .py so it ships inside the app
    // binary and needs no on-disk packaging. PEP 723 metadata (read by uv) is
    // part of the script text, so it survives.
    final String ts = DateTime.now().millisecondsSinceEpoch.toString();
    final String scriptPath =
        '${Directory.systemTemp.path}/cvml_ap_eval_$ts.py';
    final String outputPath = '${Directory.systemTemp.path}/cvml_ap_$ts.json';

    try {
      await File(scriptPath).writeAsString(apEvalScriptSource);

      final (String exe, List<String> args) = switch (runner) {
        _Runner.uv => (
            _resolvedUv!,
            [
              'run',
              scriptPath,
              '--annotations',
              annotationsPath,
              '--predictions',
              predictionsPath,
              '--output',
              outputPath,
            ],
          ),
        _Runner.python3 => (
            _resolvedPython3!,
            [
              scriptPath,
              '--annotations',
              annotationsPath,
              '--predictions',
              predictionsPath,
              '--output',
              outputPath,
            ],
          ),
      };

      final ProcessResult result = await Process.run(exe, args);

      if (result.exitCode != 0) {
        final String stderr = (result.stderr as String).trim();
        String message = 'AP evaluation failed (exit ${result.exitCode})';
        try {
          final dynamic parsed = jsonDecode(stderr);
          if (parsed is Map && parsed['error'] != null) {
            message = parsed['error'] as String;
          }
        } on FormatException {
          if (stderr.isNotEmpty) message = '$message: $stderr';
        }
        throw Exception(message);
      }

      final File outputFile = File(outputPath);
      if (!outputFile.existsSync()) {
        throw Exception('AP evaluator produced no output file.');
      }

      final String jsonStr = await outputFile.readAsString();
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('AP evaluator output is not a JSON object.');
      }

      return const ApEvalResultParser().fromJson(decoded);
    } finally {
      _tryDelete(outputPath);
      _tryDelete(scriptPath);
    }
  }

  @override
  Future<ApEvalResult> evaluateFromJson({
    required String annotationsJson,
    required String predictionsJson,
    ApEvalConfig config = const ApEvalConfig(),
  }) async {
    if (_isNativeMobile) {
      throw Exception('Local AP evaluation is not available on mobile.');
    }
    final String ts = DateTime.now().millisecondsSinceEpoch.toString();
    final String annPath = '${Directory.systemTemp.path}/cvmlab_ann_$ts.json';
    final String predPath = '${Directory.systemTemp.path}/cvmlab_pred_$ts.json';
    try {
      await File(annPath).writeAsString(annotationsJson);
      await File(predPath).writeAsString(predictionsJson);
      return await evaluate(
        annotationsPath: annPath,
        predictionsPath: predPath,
        config: config,
      );
    } finally {
      _tryDelete(annPath);
      _tryDelete(predPath);
    }
  }

  void _tryDelete(String path) {
    final File f = File(path);
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } on Object {
        // best-effort
      }
    }
  }
}
