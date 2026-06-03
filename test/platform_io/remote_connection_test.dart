import 'dart:convert';
import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:cv_model_lab/src/platform_io/remote/cvml_api_client.dart';
import 'package:cv_model_lab/src/platform_io/remote/remote_connection.dart';
import 'package:cv_model_lab/src/platform_io/remote/remote_image_source.dart';
import 'package:cv_model_lab/src/platform_io/remote/remote_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake API client returning canned JSON keyed by path.
class FakeApiClient implements CvmlApiClient {
  FakeApiClient({
    this.getResponses = const {},
    this.postResponses = const {},
    this.bytesResponses = const {},
  });

  final Map<String, Map<String, dynamic>> getResponses;
  final Map<String, Map<String, dynamic>> postResponses;
  final Map<String, Uint8List> bytesResponses;

  final List<String> getCalls = [];

  @override
  String get baseUrl => 'http://test';

  @override
  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? query}) async {
    getCalls.add(path);
    final Map<String, dynamic>? body = getResponses[path];
    if (body == null) {
      throw RemoteApiException('not found: $path', statusCode: 404);
    }
    return body;
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    final Map<String, dynamic>? response = postResponses[path];
    if (response == null) {
      throw RemoteApiException('not found: $path', statusCode: 404);
    }
    return response;
  }

  @override
  Future<Uint8List> getBytes(String path, {Map<String, String>? query}) async {
    final Uint8List? bytes = bytesResponses[path];
    if (bytes == null) {
      throw RemoteApiException('not found: $path', statusCode: 404);
    }
    return bytes;
  }

  @override
  Uri resolveUri(String path, {Map<String, String>? query}) {
    return Uri.parse('$baseUrl$path');
  }
}

Map<String, dynamic> _fullPayload() {
  return <String, dynamic>{
    'eval': <String, dynamic>{
      'config': {
        'iou_threshold': 0.5,
        'confidence_threshold': 0.25,
        'class_aware_matching': true,
        'ignore_crowd': true,
        'small_object_mode': 'coco',
      },
      'overall': {
        'total_images': 1,
        'total_gt': 1,
        'total_predictions_before_threshold': 1,
        'total_predictions_after_threshold': 1,
        'total_tp': 1,
        'total_fp': 0,
        'total_fn': 0,
        'micro_precision': 1.0,
        'micro_recall': 1.0,
        'micro_f1': 1.0,
        'macro_precision': 1.0,
        'macro_recall': 1.0,
        'macro_f1': 1.0,
        'images_with_any_error': 0,
        'images_with_fp': 0,
        'images_with_fn': 0,
      },
      'per_class': [
        {
          'category_id': 1,
          'category_name': 'cat',
          'gt_count': 1,
          'pred_count': 1,
          'tp': 1,
          'fp': 0,
          'fn': 0,
          'precision': 1.0,
          'recall': 1.0,
          'f1': 1.0,
        },
      ],
      'image_summaries': [
        {
          'image_id': 1,
          'tp': 1,
          'fp': 0,
          'fn': 0,
          'has_tp': true,
          'has_fp': false,
          'has_fn': false,
          'has_class_confusion': false,
          'has_small_object': false,
          'has_only_background_fp': false,
          'has_missed_objects': false,
        },
      ],
      'confusion': {
        'counts': {
          'cat': {'cat': 1},
        },
      },
      'small_object': [
        {
          'category_id': 1,
          'buckets': {
            'small': {'gt_count': 0, 'tp': 0, 'fn': 0, 'recall': 0.0},
            'medium': {'gt_count': 1, 'tp': 1, 'fn': 0, 'recall': 1.0},
            'large': {'gt_count': 0, 'tp': 0, 'fn': 0, 'recall': 0.0},
          },
        },
      ],
    },
    'dataset': {
      'images': [
        {'id': 1, 'file_name': 'img1.png', 'width': 100, 'height': 100},
      ],
      'categories': [
        {'id': 1, 'name': 'cat'},
      ],
      'annotations': [
        {
          'id': 1,
          'image_id': 1,
          'category_id': 1,
          'bbox': [10, 10, 40, 40],
          'area': 1600,
          'is_crowd': false,
        },
      ],
    },
    'predictions': [
      {
        'image_id': 1,
        'category_id': 1,
        'bbox': [11, 11, 40, 40],
        'score': 0.9,
      },
    ],
    'matches': [
      {
        'type': 'truePositive',
        'image_id': 1,
        'category_id': 1,
        'reason': 'matched',
        'iou': 0.9,
        'ground_truth': {
          'id': 1,
          'image_id': 1,
          'category_id': 1,
          'bbox': [10, 10, 40, 40],
          'area': 1600,
          'is_crowd': false,
        },
        'prediction': {
          'image_id': 1,
          'category_id': 1,
          'bbox': [11, 11, 40, 40],
          'score': 0.9,
        },
      },
    ],
  };
}

void main() {
  test('lists manifests', () async {
    final connection = RemoteServerConnection(
      client: FakeApiClient(getResponses: {
        '/api/manifests': {
          'enabled': true,
          'manifests': [
            {'id': 'p1', 'name': 'Project One'},
          ],
        },
      },),
    );
    final List<ServerManifestSummary> manifests = await connection.listManifests();
    expect(manifests.single.id, 'p1');
    expect(manifests.single.name, 'Project One');
  });

  test('parses browse listing', () async {
    final connection = RemoteServerConnection(
      client: FakeApiClient(getResponses: {
        '/api/browse': {
          'root_id': 'datasets',
          'path': 'traffic',
          'entries': [
            {'name': 'annotations', 'path': 'traffic/annotations', 'kind': 'directory'},
            {
              'name': 'val.json',
              'path': 'traffic/val.json',
              'kind': 'file',
              'size_bytes': 123,
              'modified_at': '2026-06-03T00:00:00Z',
            },
          ],
        },
      },),
    );
    final ServerBrowseListing listing =
        await connection.browse(rootId: 'datasets', path: 'traffic');
    expect(listing.entries.length, 2);
    expect(listing.entries.first.isDirectory, isTrue);
    expect(listing.entries.last.sizeBytes, 123);
  });

  test('opens custom-paths session', () async {
    final connection = RemoteServerConnection(
      client: FakeApiClient(postResponses: {
        '/api/sessions/open': {
          'session_id': 'sid-1',
          'project_hash': 'hash',
          'name': 'Proj',
          'source': 'custom_paths',
          'model_runs': [
            {'id': 'run_1', 'name': 'Run 1'},
          ],
          'summary': {
            'images': 10,
            'categories': 2,
            'annotations': 30,
            'model_runs': 1,
            'missing_images': 0,
          },
        },
      },),
    );
    final ServerSessionInfo info = await connection.openCustomPaths(
      name: 'Proj',
      annotationsPath: '/a.json',
      imagesRootPath: '/imgs',
      modelRuns: [
        {'id': 'run_1', 'name': 'Run 1', 'predictions_path': '/p.json'},
      ],
    );
    expect(info.sessionId, 'sid-1');
    expect(info.images, 10);
    expect(info.modelRuns.single.id, 'run_1');
  });

  test('loadWorkspace reconstructs dataset, eval and matches', () async {
    final connection = RemoteServerConnection(
      client: FakeApiClient(getResponses: {
        '/api/sessions/sid-1/eval/run_1/full': _fullPayload(),
      },),
    );
    final workspace = await connection.loadWorkspace(
      sessionId: 'sid-1',
      modelRunId: 'run_1',
      modelRunName: 'Run 1',
    );
    expect(workspace.dataset.imagesById.length, 1);
    expect(workspace.dataset.categoriesById[1]?.name, 'cat');
    expect(workspace.modelRun.predictions.single.score, 0.9);
    expect(workspace.evalResult.overall.totalTp, 1);
    expect(workspace.evalResult.matches.single.type,
        DetectionMatchType.truePositive,);
    expect(workspace.evalResult.matches.single.groundTruth?.categoryId, 1);
  });

  test('RemoteImageSource fetches bytes lazily by file name', () async {
    final bytes = Uint8List.fromList(utf8.encode('PNGDATA'));
    final client = FakeApiClient(bytesResponses: {
      '/api/sessions/sid-1/images/1/bytes': bytes,
    },);
    final source = RemoteImageSource(
      client: client,
      sessionId: 'sid-1',
      imageIdByFileName: {'img1.png': 1},
      expectedFileNames: const ['img1.png'],
    );
    expect(await source.exists('img1.png'), isTrue);
    expect(await source.exists('missing.png'), isFalse);
    final result = await source.readImageBytes('img1.png');
    expect(result, isNotNull);
    expect(utf8.decode(result!), 'PNGDATA');
  });

  test('runApMetrics parses ApEvalResult', () async {
    final connection = RemoteServerConnection(
      client: FakeApiClient(postResponses: {
        '/api/sessions/sid-1/ap/run_1/run': {
          'evaluator_name': 'pycocotools',
          'generated_at': '2026-06-03T00:00:00Z',
          'ap': 0.5,
          'ap50': 0.7,
          'per_class': [
            {'category_id': 1, 'category_name': 'cat', 'ap': 0.5},
          ],
          'warnings': [],
        },
      },),
    );
    final ApEvalResult result =
        await connection.runApMetrics('sid-1', 'run_1');
    expect(result.ap, 0.5);
    expect(result.ap50, 0.7);
    expect(result.perClass.single.categoryName, 'cat');
  });
}
