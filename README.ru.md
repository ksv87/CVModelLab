# CV Model Lab

[English version](README.md)

Кроссплатформенный Flutter Desktop + PWA инструмент для анализа COCO-датасетов object detection и ошибок inference моделей.

CV Model Lab помогает разбирать качество датасета и результаты модели без backend. Приложение загружает COCO annotations, predictions и локальные изображения, считает TP/FP/FN, показывает ошибки, confusion matrix, worst cases, dataset health, сравнение моделей и экспортируемые отчеты.

## Зачем нужен CV Model Lab

Ошибки object detection сложно понять только по агрегированным метрикам. CV Model Lab закрывает практический цикл анализа после inference:

- найти false positives, false negatives, duplicate predictions и wrong-class predictions;
- сравнить две модели и увидеть, что было исправлено или сломано;
- понять, связаны ли ошибки с моделью, class imbalance, missing images, suspicious boxes или small objects;
- экспортировать отчеты для ревью датасета и модели.

## Возможности

- Загрузка COCO annotations.
- Загрузка COCO predictions по `image_id` и `file_name`.
- Детерминированный TP/FP/FN matching с настраиваемыми IoU и confidence thresholds.
- Error Browser с фильтрами по классу, типу match, confidence, IoU, размеру объекта и missing images.
- Image viewer с GT и prediction overlays.
- Dataset Health Check для missing images, suspicious boxes, rare classes и imbalance.
- Confusion Matrix с GT rows, prediction columns, missed objects и background false positives.
- Worst Cases для приоритизации ручного анализа.
- Rule-based Recommendations с deterministic evidence и suggested actions.
- English/Russian localization для Recommendations, Dataset Health issues,
  parser warnings, friendly errors и report headings.
- Model Comparison со статусами fixed, broken, improved и regressed.
- Multi-model сравнение для 3+ запусков: leaderboard, per-class ranking, image
  disagreement, pairwise regression matrix, consensus summary и Compare Viewer
  для 3+ моделей.
- COCO AP metrics (AP@[.5:.95], AP50, AP75, AP/AR по размеру объекта, AR1/10/100, per-class AP) через pycocotools sidecar на desktop или импортом precomputed AP JSON.
- HTML и CSV export.
- XLSX workbook export.
- PDF report export.
- Annotated Image Export для визуальных overlays.
- Desktop project save/load с автоматической загрузкой по сохранённым путям через Recent Projects.
- Переименование model run и проекта из AppBar workspace.
- Desktop Recent Projects и last-used folder preferences.
- Image Browser thumbnail cache с web-safe fallback.
- Web/PWA restore mode для браузерных сценариев.
- Desktop, Web/PWA и Android/iOS remote-client support из одного приложения.

## Примеры отчётов

В репозитории есть сгенерированные примеры отчётов для синтетического Showcase Demo dataset.
Их можно показывать публично: изображения сгенерированы геометрически, без реальных данных.

Рекомендуемые примеры:
- Full evaluation: `demo/showcase_coco/reports/en/all reports/cv_model_lab_report.html`
- Pairwise compare: `demo/showcase_coco/reports/en/pairwise compare/cv_model_lab_report.html`
- Multi-model compare: `demo/showcase_coco/reports/en/multi-model compare/cv_model_lab_report.html`
- RU multi-model: `demo/showcase_coco/reports/ru/multi-model compare/cv_model_lab_report.html`

В папке также лежат CSV, XLSX и PDF exports. CSV-заголовки намеренно остаются английскими для machine-readable compatibility.
Подробности: [docs/ru/showcase_demo.md](docs/ru/showcase_demo.md) и [demo/showcase_coco/reports/README.md](demo/showcase_coco/reports/README.md).

## Поддерживаемые платформы

| Платформа | Локальные standalone датасеты | Удалённые проекты сервера |
|-----------|-------------------------------|---------------------------|
| Linux / Windows / macOS desktop | Да | Да |
| Web/PWA | Да, через browser-selected files | Да |
| Android / iOS apps | Нет | Да, только remote |

Desktop builds требуют соответствующий Flutter desktop toolchain на целевой ОС. Web build работает без backend и использует browser file selection APIs.

## Android и iOS приложения

Android и iOS приложения работают только как удалённые клиенты для CV Model Lab
Server. Они запускаются в **режиме удалённого клиента**, подключаются к вручную
введённому URL сервера и открывают server manifest projects или custom server
paths через server file browser. Они не запрашивают broad storage permissions и
не открывают локальные COCO annotations, predictions, каталоги изображений,
локальные project files или локальный AP evaluator с устройства.

Подробнее: [Android и iOS как удалённые клиенты](docs/ru/mobile_apps.md) /
[Android and iOS Remote Clients](docs/mobile_apps.md).

## Мобильный PWA

Сборка Web/PWA адаптивна и подстраивается под узкие и мобильные экраны. На
компактной ширине она переключается на мобильную вёрстку с нижней навигацией
(Проект, Изображения, Метрики, Сравнение, Отчёты, Ещё), полноэкранным
просмотрщиком с зумом/панорамированием и параметрами наложения, фильтрами в
bottom sheet, мобильным представлением Confusion Matrix с топом путаниц и
диалогом экспорта для узких экранов. На широких экранах сохраняется
desktop-вёрстка.

Работает на Android Chrome, iOS Safari, установленном PWA и суженном окне
desktop-браузера. Нативные приложения Android и iOS используют отдельный
remote-only client mode, описанный выше.

Подробнее: [Мобильный PWA](docs/ru/mobile_pwa.md) / [Mobile PWA](docs/mobile_pwa.md).

## Поддерживаемые форматы

- COCO detection annotations JSON.
- COCO predictions/results JSON с `image_id`.
- COCO predictions/results JSON с `file_name`, который сопоставляется с COCO image records.
- Локальные директории или выбранные image files, сопоставление по relative path и basename fallback.

Подробнее: [Форматы данных](docs/ru/supported_formats.md) / [Supported Formats](docs/supported_formats.md).

## Быстрый старт

1. Скачайте последнюю desktop-сборку со страницы публичного релиза или откройте hosted Web/PWA build, если он доступен.
2. Запустите CV Model Lab.
3. Чтобы попробовать showcase dataset, нажмите **Open project** и выберите `demo/showcase_coco/showcase_coco.cvmlab.json`.
4. Для своих данных откройте COCO annotations, prediction JSON и директорию с изображениями или выбранные image files.

## Типичный workflow

1. Открыть COCO annotations JSON.
2. Открыть один или несколько COCO prediction JSON.
3. Выбрать images directory или набор image files.
4. Проверить parser warnings и image matching status.
5. Посмотреть overall и per-class metrics на dashboard.
6. Использовать Error Browser filters для анализа FP/FN/TP.
7. Проверить Dataset Health.
8. Открыть Confusion Matrix и Worst Cases.
9. Сравнить model runs.
10. Запустить COCO AP metrics на desktop или импортировать precomputed AP JSON.
11. Экспортировать HTML/CSV/XLSX/PDF reports или annotated images.
12. Сохранить проект на desktop или использовать Web/PWA restore mode.

Руководство: [Руководство пользователя](docs/ru/user_guide.md) / [User Guide](docs/user_guide.md).

> **Showcase dataset:** нажмите **Open project** на стартовом экране и выберите
> `demo/showcase_coco/showcase_coco.cvmlab.json`, чтобы загрузить синтетический
> road-scene dataset с тремя моделями и precomputed AP metrics.
> Подробности: [Showcase Demo](docs/ru/showcase_demo.md).

## Метрики

CV Model Lab считает:

- TP, FP и FN matches;
- precision, recall и F1;
- micro и macro averages;
- per-class statistics;
- image-level error flags;
- small, medium и large object statistics;
- confusion matrix для correct classes, wrong classes, missed GT и background FP;
- model comparison statuses: fixed, broken, improved и regressed.

Подробнее: [Метрики](docs/ru/metrics.md) / [Metrics](docs/metrics.md).

## Dataset Health Check

Dataset Health Check анализирует качество входных данных, а не качество модели. Он показывает missing image files, unused selected files, unknown references, invalid или suspicious boxes, images without GT, rare classes, classes without GT и class imbalance.

## Error Browser

Error Browser - основной экран debugging. Он объединяет image-level filters, match-type filters, class filters, confidence threshold, IoU threshold, object-size filters и missing-image status. Viewer показывает GT boxes и predictions поверх изображения.

## Confusion Matrix

Confusion Matrix использует GT categories как строки и predicted categories как колонки. Также есть специальные buckets для missed-object и background-false-positive, чтобы видеть wrong-class predictions и background hallucinations.

## Worst Cases

Worst Cases ранжирует изображения, которые стоит проверить первыми: много false positives, много false negatives, сильная class confusion, high-confidence false positives, low-IoU true positives или missing local image files.

## Recommendations

Rule-based Recommendations анализируют metrics, Dataset Health, Worst Cases, class confusion и model comparison results. Они объясняют low recall, low precision, rare classes, class imbalance, small-object issues, high-confidence false positives, dataset health errors, threshold tradeoffs и candidate regressions без LLM.

## Model Comparison

Model Comparison загружает два prediction runs для одного COCO dataset и сравнивает per-class precision/recall и image-level behavior. Изображения группируются как fixed, broken, improved, regressed, still correct или still wrong. Если у обеих моделей есть COCO AP metrics, на экране сравнения также показывается AP diff.

## Multi-model Comparison

Для трёх и более запусков на экране Model Compare есть режим Multi-model. Leaderboard ранжирует каждый запуск по выбираемой метрике с детерминированными tie-breakers; per-class ranking показывает лучшую и худшую модель по классу со spread F1/recall/AP; анализ расхождений классифицирует каждое изображение (все верны, все ошибаются, только одна модель верна/ошибается, class disagreement, large error spread и т.д.); pairwise regression matrix сводит каждую направленную пару и открывает любую ячейку в режиме Pairwise; Compare Viewer показывает одно изображение по всем выбранным моделям сеткой. Multi-model результаты экспортируются в HTML, CSV (`multi_model_leaderboard.csv`, `multi_model_per_class.csv`, `multi_model_image_disagreements.csv`, `multi_model_regression_matrix.csv`), XLSX и PDF.

## COCO AP Metrics

CV Model Lab умеет считать стандартные pycocotools-совместимые COCO average precision/recall: AP@[.5:.95], AP50, AP75, AP/AR для small/medium/large объектов, AR1/AR10/AR100 и per-class AP/AR.

- **Desktop:** приложение запускает встроенный Python sidecar (`tools/ap_evaluator/ap_eval.py`) поверх `pycocotools.COCOeval`. Sidecar работает через [uv](https://docs.astral.sh/uv/), если он установлен (зависимости ставятся автоматически), либо через `python3` с установленным `pycocotools`. Кнопка "Run COCO AP evaluation" доступна на dashboard.
- **Web/PWA:** браузер не может запускать Python, поэтому в web build AP evaluation недоступен. Вместо этого используйте **Import AP metrics JSON** для загрузки заранее посчитанного результата (например, из desktop-приложения или из ручного запуска sidecar). Импортированные AP metrics используются в тех же карточках dashboard, per-class таблице, AP diff и секциях отчетов.

AP metrics можно явно включать или выключать для HTML, CSV (`ap_metrics.csv`, `per_class_ap.csv`), XLSX и PDF export, когда они доступны; AP metrics также сохраняются в desktop project files.

Использование sidecar и формат AP JSON: [tools/ap_evaluator/README.md](tools/ap_evaluator/README.md).

## Экспорт

CV Model Lab поддерживает:

- HTML report export.
- CSV export для per-class metrics, image errors, matches, small-object stats, confusion matrix, confusion pairs, dataset health, worst cases, AP metrics и per-class AP.
- CSV export для rule-based recommendations.
- XLSX workbook export для metrics, errors, matches, health issues, worst cases, recommendations, AP metrics и comparison tables.
- PDF report export с overall metrics, per-class таблицами, confusion matrix, recommendations, AP metrics и comparison summaries.
- Annotated Image Export с overlay images.

## Серверный режим (опционально)

CV Model Lab может работать с бэкендом на Python (FastAPI), который просматривает
датасеты в разрешённых корнях, выполняет оценку COCO на стороне сервера, отдаёт
изображения, миниатюры и AP-метрики и раздаёт сборку Flutter Web/PWA. Локальный
автономный режим продолжает работать без изменений. Сервер работает только для
чтения по отношению к датасетам и записывает лишь собственный кэш и логи.

```bash
cd server
uv venv && uv pip install -e ".[dev]"
cp server.example.yaml server.yaml   # отредактируйте allowed_roots
uv run python -m cvmlab_server.main --config server.yaml
```

Затем используйте **Подключиться к серверу** на экране открытия (десктоп) или
откройте PWA, которую сервер раздаёт по своему адресу.

Полное руководство: [Серверный режим](docs/ru/server_mode.md) /
[Server Mode](docs/server_mode.md).

## Лицензия

Этот проект распространяется по лицензии MIT. Подробности см. в [LICENSE](LICENSE).

Эта лицензия применяется только к исходному коду CV Model Lab.

Синтетические demo и test datasets в каталогах `demo/` и `test_data/` распространяются по CC0 1.0 Universal, если в README конкретного датасета явно не указано иное.

## Сторонние компоненты и данные

Встроенные файлы шрифта DejaVu Sans в `assets/fonts/` распространяются по DejaVu Fonts License; см. `assets/fonts/LICENSE.DejaVu`.

Репозиторий может ссылаться на сторонние модели, датасеты, runtimes, SDK и зависимости или интегрироваться с ними. На них распространяются их собственные лицензии.

Лицензия MIT в этом репозитории применяется только к исходному коду CV Model Lab, если явно не указано иное.

Пользователи отвечают за наличие необходимых прав на использование датасетов, моделей, весов и артефактов, обрабатываемых этим программным обеспечением.
