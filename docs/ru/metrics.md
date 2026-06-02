# Метрики

[English version](../metrics.md) | [README.ru](../../README.ru.md)

## Matching terms

**TP**: prediction matched к unmatched GT box того же class с IoU больше или равным threshold.

**FP**: prediction, который не matched к GT box того же class, является duplicate для уже matched GT, имеет low IoU или предсказывает background content.

**FN**: GT box, который остался unmatched после matching predictions.

## Precision, Recall, F1

```text
precision = TP / (TP + FP)
recall = TP / (TP + FN)
f1 = 2 * precision * recall / (precision + recall)
```

Если denominator равен zero, metric возвращается как `0`.

## Micro и Macro

Micro metrics агрегируют TP, FP и FN по всем classes перед расчетом precision, recall и F1.

Macro metrics сначала считают per-class precision, recall и F1, затем усредняют class values.

## Small, Medium, Large

Используются COCO object-size buckets:

- small: area `< 32^2`
- medium: `32^2 <= area < 96^2`
- large: area `>= 96^2`

Если `area` отсутствует, используется `bbox.width * bbox.height`.

## Confusion Matrix

Rows - GT classes, columns - predicted classes. Есть специальные buckets:

- GT class -> predicted class для class confusion.
- GT class -> `__missed__` для unmatched GT.
- `__background_fp__` -> predicted class для predictions без matching GT.

## Model Comparison

Image-level comparison statuses:

- fixed: base run имел errors, candidate run не имеет errors.
- broken: base run не имел errors, candidate run имеет errors.
- improved: candidate снизил error severity, но не полностью исправил image.
- regressed: candidate увеличил error severity.
- still correct: оба runs correct.
- still wrong: оба runs имеют errors без явного improvement/regression.
