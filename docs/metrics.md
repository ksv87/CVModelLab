# Metrics

[Русская версия](ru/metrics.md) | [README](../README.md)

## Matching Terms

**TP**: a prediction matched to an unmatched GT box of the same class with IoU greater than or equal to the configured threshold.

**FP**: a prediction that does not match a GT box of the same class, is a duplicate prediction for an already matched GT, has low IoU, or predicts background content.

**FN**: a GT box that remains unmatched after matching predictions.

## Precision, Recall, F1

```text
precision = TP / (TP + FP)
recall = TP / (TP + FN)
f1 = 2 * precision * recall / (precision + recall)
```

When a denominator is zero, the metric is reported as `0`.

## Micro and Macro

Micro metrics aggregate TP, FP, and FN across classes before computing precision, recall, and F1.

Macro metrics compute per-class precision, recall, and F1 first, then average the class values.

## Small, Medium, Large

COCO object-size buckets are used:

- small: area `< 32^2`
- medium: `32^2 <= area < 96^2`
- large: area `>= 96^2`

If `area` is missing, `bbox.width * bbox.height` is used.

## Confusion Matrix

Rows represent GT classes and columns represent predicted classes. Special buckets are included for missed GT and background false positives:

- GT class -> predicted class for class confusion.
- GT class -> `__missed__` for unmatched GT.
- `__background_fp__` -> predicted class for predictions that did not match any GT.

## Model Comparison

Image-level comparison statuses include:

- fixed: the base run had errors and the candidate run has no errors.
- broken: the base run had no errors and the candidate run has errors.
- improved: the candidate reduced error severity but did not fully fix the image.
- regressed: the candidate increased error severity.
- still correct: both runs are correct.
- still wrong: both runs have errors without a clear improvement/regression.
