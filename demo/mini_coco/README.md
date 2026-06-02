# Mini COCO Demo

This synthetic dataset is intended for smoke tests, release checks, and product demos.

- `annotations.json`: 4 images, 3 classes, 6 GT boxes.
- `predictions_model_a.json`: includes TP, FP, FN, duplicate prediction, wrong class, small-object miss, and `file_name` matching by basename.
- `predictions_model_b.json`: includes fixed examples, broken examples, improved small-object recall, and regressed/wrong-class behavior for model comparison.
- `images/`: generated placeholder PNG images.

Use model A as the baseline and model B as the candidate run.

## Dataset License

The synthetic dataset files in this directory, including generated images, COCO annotations, prediction files, precomputed metrics, saved project files, and generated sample reports, are released under CC0 1.0 Universal unless explicitly stated otherwise.

The CV Model Lab source code remains licensed under the MIT License.
