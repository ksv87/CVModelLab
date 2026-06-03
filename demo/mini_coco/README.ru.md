# Mini COCO Demo

[English version](README.md)

Этот synthetic dataset используется для smoke tests, release checks и product
demos.

- `annotations.json`: 4 images, 3 classes, 6 GT boxes.
- `predictions_model_a.json`: содержит TP, FP, FN, duplicate prediction, wrong
  class, small-object miss и `file_name` matching by basename.
- `predictions_model_b.json`: содержит fixed examples, broken examples,
  improved small-object recall и regressed/wrong-class behavior для model
  comparison.
- `images/`: generated placeholder PNG images.

Используйте model A как baseline, а model B как candidate run.

## Лицензия датасета

Синтетические файлы датасета в этом каталоге, включая сгенерированные изображения, COCO annotations, prediction files, precomputed metrics, сохранённые project files и сгенерированные примеры отчётов, распространяются по CC0 1.0 Universal, если явно не указано иное.

Исходный код CV Model Lab остаётся под лицензией MIT.
