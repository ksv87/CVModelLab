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

## COCO AP Metrics

Стандартные pycocotools-совместимые метрики, вычисляемые через Python sidecar на desktop:

- `AP@[.5:.95]` — mean average precision, усреднённый по IoU thresholds 0.50…0.95.
- `AP50` / `AP75` — average precision при IoU 0.50 и 0.75.
- `APsmall` / `APmedium` / `APlarge` — AP по размеру объекта (COCO area thresholds).
- `AR1` / `AR10` / `AR100` — max recall при 1, 10 и 100 детекциях на изображение.
- `ARsmall` / `ARmedium` / `ARlarge` — AR по размеру объекта.
- Per-class AP, AP50, AP75, AR для каждой категории.

Все AP-метрики хранятся как ratio в `[0, 1]` и отображаются как `xx.x%` в человекочитаемых отчётах.

## Multi-model Comparison

Multi-model comparison агрегирует заранее вычисленные `EvalResult` и `ApEvalResult` для трёх и более запусков без повторного detection matching.

Метрики ранжирования leaderboard: `AP`, `AP50`, `AP75`, `precision`, `recall`, `F1`, `TP`, `FP`, `FN`, `imagesWithErrors`, `smallObjectRecall`.

Типы расхождений по изображениям: `allCorrect`, `allWrong`, `onlyOneModelCorrect`, `onlyOneModelWrong`, `someModelsWrong`, `largeErrorSpread`, `classDisagreement`, `predictionCountDisagreement`.
