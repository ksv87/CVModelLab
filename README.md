# CV Model Lab

CV Model Lab is a Flutter/Dart tool for COCO object detection evaluation and error analysis.

The initial version focuses on local COCO annotations and prediction JSON files. It parses datasets, matches detections deterministically, computes TP/FP/FN outcomes, class metrics, confusion data, and small-object statistics, and includes tests with a mini COCO fixture.

## Features

- COCO detection annotations JSON parsing.
- COCO prediction JSON parsing.
- Deterministic IoU-based matching with configurable thresholds.
- TP, FP, and FN classification.
- Per-class precision, recall, and F1 statistics.
- Confusion matrix support.
- Small-object statistics.
- Pure Dart evaluation core separated from UI and platform I/O.
- Unit tests and mini COCO test data.

## Development

Install Flutter dependencies and run the test suite:

```bash
flutter pub get
flutter test
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

This license applies only to the CV Model Lab source code.

Synthetic demo and test datasets stored in `demo/` and `test_data/` are released under CC0 1.0 Universal unless their local dataset README states otherwise.

## Third-party components and data

This repository may reference or integrate third-party models, datasets, runtimes, SDKs, and dependencies. They are subject to their own licenses.

The MIT License in this repository applies only to the CV Model Lab source code unless explicitly stated otherwise.

Users are responsible for ensuring that they have the necessary rights to use any datasets, models, weights, and artifacts processed with this software.
