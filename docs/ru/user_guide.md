# Руководство пользователя

[English version](../user_guide.md) | [README.ru](../../README.ru.md)

## Открыть COCO annotations

На home/open screen выберите COCO annotations JSON. Файл должен содержать `images`, `annotations` и `categories`. CV Model Lab валидирует ссылки, обязательные поля и bounding boxes, затем показывает warnings вместо падения на первом плохом объекте.

## Открыть predictions

Выберите COCO predictions JSON. Predictions могут ссылаться на изображения через `image_id` или `file_name`. Если оба поля есть, приоритет у `image_id`. Позже можно добавить второй prediction file для model comparison.

## Выбрать images directory

На desktop выберите директорию с изображениями. В Web/PWA выберите файлы или directory/file set, если это поддерживает браузер. Matching поддерживает точный COCO `file_name`, relative paths вроде `val2017/image.jpg` и basename fallback, если он однозначен.

## Анализировать FP/FN

После загрузки откройте dashboard и Error Browser. TP, FP и FN считаются из текущих IoU и confidence thresholds. Image viewer показывает GT boxes, predictions, labels, scores, IoU и match reasons.

## Использовать фильтры

Фильтры сужают список изображений по class, TP/FP/FN, confidence range, IoU threshold, object size, class confusion, missing local image и другим image-level flags. При изменении thresholds evaluation пересчитывается.

## Сравнить модели

Загрузите второй prediction JSON для того же dataset. Model Compare показывает per-class precision/recall differences и image-level statuses: fixed, broken, improved, regressed.

## Экспортировать отчеты

Через export dialog можно сохранить HTML и CSV reports. CSV включает per-class metrics, image errors, matches, small-object stats, confusion matrix, dataset health и worst cases. Annotated Image Export сохраняет visual overlays.

## Сохранить проект

Desktop workflows могут сохранять и открывать project file с dataset paths, image root, model runs и evaluation config. Web/PWA workflows используют выбранные браузером файлы и restore mode, где он поддерживается.
