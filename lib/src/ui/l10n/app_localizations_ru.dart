import 'package:cv_model_lab/cv_model_lab.dart';

import 'app_localizations.dart';

class AppLocalizationsRu extends AppLocalizations {
  const AppLocalizationsRu() : super(AppLocale.ru);

  @override
  String? lookup(MessageKey key, MessageParams p) {
    return switch (key) {
      MessageKey.parseInvalidJson => 'Некорректный JSON: ${p['error'] ?? ''}',
      MessageKey.parseAnnotationsRootMustBeObject =>
        'Корень COCO annotations должен быть объектом',
      MessageKey.parseAnnotationsListsRequired =>
        'images, annotations и categories должны быть списками',
      MessageKey.parseImageMustBeObject => 'image должен быть объектом',
      MessageKey.parseImageRequiresIdAndFileName =>
        'image требует id и file_name',
      MessageKey.parseDuplicateImageIdSkipped =>
        'дублирующийся image id ${p['id']} пропущен',
      MessageKey.parseCategoryMustBeObject => 'category должен быть объектом',
      MessageKey.parseCategoryRequiresIdAndName => 'category требует id и name',
      MessageKey.parseDuplicateCategoryIdSkipped =>
        'дублирующийся category id ${p['id']} пропущен',
      MessageKey.parseAnnotationMustBeObject =>
        'annotation должен быть объектом',
      MessageKey.parseAnnotationUnknownImageId =>
        'annotation ссылается на неизвестный image_id',
      MessageKey.parseAnnotationUnknownCategoryId =>
        'annotation ссылается на неизвестный category_id',
      MessageKey.parsePredictionsRootMustBeList =>
        'Корень COCO predictions должен быть списком',
      MessageKey.parsePredictionMustBeObject =>
        'prediction должен быть объектом',
      MessageKey.parsePredictionUnknownCategoryId =>
        'prediction ссылается на неизвестный category_id',
      MessageKey.parsePredictionUnknownImageId =>
        'prediction ссылается на неизвестный image_id',
      MessageKey.parsePredictionRequiresImageIdOrFileName =>
        'prediction требует image_id или file_name',
      MessageKey.parsePredictionFileNameBasenameFallback =>
        'prediction file_name сопоставлен по basename fallback',
      MessageKey.parsePredictionFileNameAmbiguous =>
        'basename у prediction file_name неоднозначен',
      MessageKey.parsePredictionUnknownFileName =>
        'prediction ссылается на неизвестный file_name',
      MessageKey.parsePredictionRequiresNumericScore =>
        'prediction требует numeric score',
      MessageKey.parsePredictionScoreOutOfRange =>
        'prediction score вне ожидаемого диапазона 0..1',
      MessageKey.parseBboxMustHaveFourNumbers =>
        'bbox должен содержать 4 числа',
      MessageKey.parseBboxNonPositiveSize =>
        'bbox width и height должны быть положительными',
      MessageKey.parseMissingImageFile => 'файл изображения не найден',
      MessageKey.parseMoreMissingImageFiles =>
        'ещё ${p['count']} файлов изображений не найдено',
      MessageKey.errorInvalidJson =>
        'Выбранный файл не является корректным JSON или не соответствует ожидаемому формату CV Model Lab.',
      MessageKey.errorPermissionDenied =>
        'CV Model Lab не смог получить доступ к выбранному файлу или папке. Выберите файл заново или используйте доступную директорию.',
      MessageKey.errorApUnavailable =>
        'COCO AP evaluation недоступен в этой среде. В web импортируйте AP metrics JSON.',
      MessageKey.errorOperationFailed =>
        'Операцию не удалось завершить. Проверьте details или выберите другой файл/папку.',
      MessageKey.errorProjectRestoreFailed =>
        'Не удалось восстановить проект. Заново выберите файлы и повторите.',
      MessageKey.errorExportFailed =>
        'Экспорт не удался. Выберите директорию с правами записи и повторите.',
      MessageKey.recLowRecallClass => _recLowRecall(p),
      MessageKey.recLowPrecisionClass => _recLowPrecision(p),
      MessageKey.recRareClass => _recRareClass(p),
      MessageKey.recClassImbalance => _recClassImbalance(p),
      MessageKey.recSmallObjectRecallGap => _recSmallObject(p),
      MessageKey.recHighConfidenceFalsePositives => _recHighConfidenceFp(p),
      MessageKey.recManyFalseNegatives => _recManyFn(p),
      MessageKey.recClassConfusion => _recClassConfusion(p),
      MessageKey.recDatasetHealthErrors => _recDatasetHealth(p),
      MessageKey.recCandidateRegression => _recCandidateRegression(p),
      MessageKey.recThresholdLowPrecision => _recThresholdLowPrecision(p),
      MessageKey.recThresholdLowRecall => _recThresholdLowRecall(p),
      MessageKey.reportTitle => 'Отчет CV Model Lab',
      MessageKey.reportDatasetSummary => 'Сводка датасета',
      MessageKey.reportModelRunSummary => 'Сводка model run',
      MessageKey.reportOverallMetrics => 'Общие метрики',
      MessageKey.reportPerClassMetrics => 'Метрики по классам',
      MessageKey.reportSmallObjectStats => 'Статистика малых объектов',
      MessageKey.reportConfusionMatrix => 'Confusion Matrix',
      MessageKey.reportDatasetHealth => 'Dataset Health',
      MessageKey.reportWorstCases => 'Worst Cases',
      MessageKey.reportRecommendations => 'Рекомендации',
      MessageKey.reportCocoApMetrics => 'COCO AP Metrics',
      MessageKey.reportModelComparison => 'Сравнение моделей',
      MessageKey.reportImageErrors => 'Ошибки по изображениям',
      MessageKey.reportMatches => 'Matches',
      MessageKey.reportExecutiveSummary => 'Сводка',
      MessageKey.reportAppendix => 'Приложение: примеры ошибок',
      MessageKey.reportImagesByStatus => 'Изображения по статусу',
      MessageKey.mmMultiModelComparison => 'Сравнение нескольких моделей',
      MessageKey.mmPairwiseMode => 'Попарное сравнение',
      MessageKey.mmMultiModelMode => 'Мультимодельное сравнение',
      MessageKey.mmLeaderboard => 'Таблица лидеров',
      MessageKey.mmPerClassRanking => 'Рейтинг по классам',
      MessageKey.mmImageDisagreement => 'Расхождения по изображениям',
      MessageKey.mmRegressionMatrix => 'Матрица регрессий',
      MessageKey.mmCompareViewer => 'Просмотр сравнения',
      MessageKey.mmAllModelsCorrect => 'Все модели верны',
      MessageKey.mmAllModelsWrong => 'Все модели ошибаются',
      MessageKey.mmSomeModelsWrong => 'Часть моделей ошибается',
      MessageKey.mmOnlyOneModelCorrect => 'Только одна модель верна',
      MessageKey.mmOnlyOneModelWrong => 'Только одна модель ошибается',
      MessageKey.mmClassDisagreement => 'Расхождение классов',
      MessageKey.mmLargeErrorSpread => 'Большой разброс ошибок',
      MessageKey.mmPredictionCountDisagreement =>
        'Расхождение числа предсказаний',
      MessageKey.mmApNotComputed =>
        'AP-метрики для этой модели не рассчитаны.',
      MessageKey.mmSelectTwoRuns =>
        'Добавьте минимум два запуска модели для сравнения.',
      MessageKey.mmOpenPairwise => 'Открыть попарное сравнение',
      MessageKey.mmBestModel => 'Лучшая модель',
      MessageKey.mmWorstModel => 'Худшая модель',
      MessageKey.mmF1Spread => 'Разброс F1',
      MessageKey.mmErrorSpread => 'Разброс ошибок',
      MessageKey.mmRankingMetric => 'Метрика ранжирования',
      MessageKey.mmHideAllCorrect => 'Скрыть изображения без ошибок',
      MessageKey.mmIncludeAp => 'Включить AP',
      MessageKey.mmMakeActiveModel => 'Сделать активной моделью',
      MessageKey.mmRank => 'Ранг',
      MessageKey.mmModel => 'Модель',
      MessageKey.mmCorrectModels => 'Верные модели',
      MessageKey.mmWrongModels => 'Ошибающиеся модели',
      MessageKey.mmSpread => 'Разброс',
      MessageKey.mmImagesWithErrors => 'Изображений с ошибками',
      MessageKey.mmSmallRecall => 'Recall малых',
      MessageKey.mmExportTable => 'Экспортировать таблицу',
      MessageKey.mmType => 'Тип',
      MessageKey.mmImage => 'Изображение',
      MessageKey.mmClassFilter => 'Класс',
      MessageKey.mmBestErrorCount => 'Мин. число ошибок',
      MessageKey.mmWorstErrorCount => 'Макс. число ошибок',
      MessageKey.mmConsensusSummary => 'Сводка согласованности',
      MessageKey.mmModelRuns => 'Запуски моделей',
    };
  }

  String _part(MessageParams p) => '${p['part'] ?? 'message'}';

  String _recLowRecall(MessageParams p) => switch (_part(p)) {
        'title' => 'Низкий recall для класса "${p['class_name']}"',
        'action' =>
          'Проверьте false negatives, консистентность разметки, добавьте примеры и рассмотрите изменения resolution/augmentation.',
        _ => 'Модель пропускает много объектов этого класса.',
      };

  String _recLowPrecision(MessageParams p) => switch (_part(p)) {
        'title' => 'Низкий precision для класса "${p['class_name']}"',
        'action' =>
          'Проверьте false positives, добавьте hard negatives, пересмотрите taxonomy и score threshold.',
        _ => 'Многие predictions этого класса являются false positives.',
      };

  String _recRareClass(MessageParams p) => switch (_part(p)) {
        'title' => 'Редкий класс "${p['class_name']}"',
        'action' =>
          'Соберите больше samples или не доверяйте метрикам этого класса.',
        _ => 'У этого класса слишком мало ground-truth примеров.',
      };

  String _recClassImbalance(MessageParams p) => switch (_part(p)) {
        'title' => 'Обнаружен дисбаланс классов',
        'action' => 'Соберите или oversample underrepresented classes.',
        _ => 'Некоторые классы имеют очень малую долю GT objects.',
      };

  String _recSmallObject(MessageParams p) => switch (_part(p)) {
        'title' => 'Слабое качество на малых объектах',
        'action' =>
          'Рассмотрите higher input resolution, tiling, больше small-object samples или ревью tiny annotations.',
        _ =>
          'Small objects для "${p['class_name']}" имеют заметно более низкий recall, чем крупные объекты.',
      };

  String _recHighConfidenceFp(MessageParams p) => switch (_part(p)) {
        'title' => 'High-confidence false positives',
        'action' =>
          'Проверьте hard negatives, добавьте background examples, проверьте score calibration.',
        _ =>
          'Некоторые false positives имеют высокий confidence, что ухудшает надежность thresholding.',
      };

  String _recManyFn(MessageParams p) => switch (_part(p)) {
        'title' => 'Много пропущенных объектов',
        'action' =>
          'Проверьте FN cases, consistency разметки, input resolution, augmentation и train/val distribution.',
        _ => 'False negatives — значимая часть текущего профиля ошибок.',
      };

  String _recClassConfusion(MessageParams p) => switch (_part(p)) {
        'title' =>
          'Путаница классов: "${p['gt_class_name']}" предсказан как "${p['pred_class_name']}"',
        'action' =>
          'Проверьте annotation rules и visual similarity. Добавьте discriminative examples.',
        _ => 'Модель путает эти два класса в class-agnostic matching.',
      };

  String _recDatasetHealth(MessageParams p) => switch (_part(p)) {
        'title' => 'Обнаружены ошибки Dataset Health',
        'action' => 'Исправьте issues датасета перед доверием метрикам.',
        _ =>
          'Dataset Health нашел ошибки, которые могут сделать метрики ненадежными.',
      };

  String _recCandidateRegression(MessageParams p) => switch (_part(p)) {
        'title' => 'Candidate model регрессировал',
        'action' =>
          'Проверьте broken/regressed images перед выбором candidate для production.',
        _ =>
          'Candidate model добавил broken или regressed images относительно base run.',
      };

  String _recThresholdLowPrecision(MessageParams p) => switch (_part(p)) {
        'title' => 'Precision низкий, recall приемлемый',
        'action' => 'Попробуйте повысить confidence threshold.',
        _ =>
          'Текущий threshold сохраняет много detections, но пропускает много false positives.',
      };

  String _recThresholdLowRecall(MessageParams p) => switch (_part(p)) {
        'title' => 'Recall низкий, precision приемлемый',
        'action' =>
          'Попробуйте снизить confidence threshold или улучшить data/model recall.',
        _ =>
          'Текущий threshold может быть слишком строгим или модели нужен более сильный recall.',
      };

  @override
  String? datasetIssueLookup(
    DatasetIssueType type,
    String part,
    MessageParams p,
  ) {
    final String file = '${p['file_name'] ?? ''}';
    final String cls = '${p['category_name'] ?? p['category_id'] ?? ''}';
    return switch (type) {
      DatasetIssueType.missingImageFile => switch (part) {
          'title' => 'Файл изображения не найден',
          'recommendation' => 'Добавьте файл или исправьте путь file_name.',
          _ => 'Image "$file" указан в COCO, но файл не найден.',
        },
      DatasetIssueType.unusedImageFile => switch (part) {
          'title' => 'Неиспользуемый файл изображения',
          'recommendation' =>
            'Удалите файл или добавьте для него image record.',
          _ => 'File "$file" присутствует, но не referenced by dataset.',
        },
      DatasetIssueType.unknownAnnotationImageId => switch (part) {
          'title' => 'Annotation ссылается на неизвестное image',
          'recommendation' =>
            'Удалите annotation или добавьте missing image record.',
          _ =>
            'Annotation ${p['annotation_id']} ссылается на image_id ${p['image_id']}, которого нет в dataset.',
        },
      DatasetIssueType.unknownAnnotationCategoryId => switch (part) {
          'title' => 'Annotation ссылается на неизвестную category',
          'recommendation' =>
            'Добавьте category в "categories" или исправьте annotation.',
          _ =>
            'Annotation ${p['annotation_id']} ссылается на category_id ${p['category_id']}, которая не объявлена.',
        },
      DatasetIssueType.unknownPredictionImageId => switch (part) {
          'title' => 'Prediction ссылается на неизвестное image',
          'recommendation' =>
            'Проверьте, что predictions и annotations используют одинаковые image ids / file names.',
          _ =>
            'Prediction ссылается на image_id ${p['image_id']}, которого нет в dataset.',
        },
      DatasetIssueType.unknownPredictionCategoryId => switch (part) {
          'title' => 'Prediction ссылается на неизвестную category',
          'recommendation' =>
            'Согласуйте prediction category ids с dataset categories.',
          _ =>
            'Prediction ссылается на category_id ${p['category_id']}, которая не объявлена.',
        },
      DatasetIssueType.invalidBbox => switch (part) {
          'title' => 'Некорректный bbox',
          'recommendation' => 'Удалите или исправьте degenerate box.',
          _ => 'Box имеет non-positive width или height.',
        },
      DatasetIssueType.bboxOutsideImage => switch (part) {
          'title' => 'BBox вне изображения',
          'recommendation' => 'Исправьте bbox coordinates.',
          _ => 'BBox полностью вне image bounds.',
        },
      DatasetIssueType.bboxPartiallyOutsideImage => switch (part) {
          'title' => 'BBox частично вне изображения',
          'recommendation' => 'Clamp bbox to image.',
          _ => 'BBox выходит за image bounds.',
        },
      DatasetIssueType.extremeAspectRatio => switch (part) {
          'title' => 'Extreme aspect ratio',
          'recommendation' => 'Проверьте malformed box.',
          _ => 'BBox имеет extreme aspect ratio.',
        },
      DatasetIssueType.tinyBbox => switch (part) {
          'title' => 'Tiny bbox',
          'recommendation' => 'Проверьте, что annotation не является ошибкой.',
          _ => 'BBox очень маленький.',
        },
      DatasetIssueType.hugeBbox => switch (part) {
          'title' => 'Huge bbox',
          'recommendation' => 'Подтвердите, что box intentional.',
          _ => 'BBox покрывает большую часть изображения.',
        },
      DatasetIssueType.imageWithoutGroundTruth => switch (part) {
          'title' => 'Image без ground truth',
          'recommendation' =>
            'Подтвердите, что image intentionally negative sample.',
          _ => 'Image "$file" не имеет annotations.',
        },
      DatasetIssueType.classWithoutGroundTruth => switch (part) {
          'title' => 'Class без ground truth',
          'recommendation' =>
            'Удалите unused class или добавьте training data.',
          _ => 'Class "$cls" не имеет GT objects.',
        },
      DatasetIssueType.rareClass => switch (part) {
          'title' => 'Редкий класс',
          'recommendation' => 'Соберите больше samples для этого класса.',
          _ => 'Class "$cls" имеет мало GT objects.',
        },
      DatasetIssueType.classImbalance => switch (part) {
          'title' => 'Дисбаланс класса',
          'recommendation' =>
            'Рассмотрите rebalance dataset или class weights.',
          _ => 'Class "$cls" имеет малую долю GT objects.',
        },
      DatasetIssueType.duplicateImageId => switch (part) {
          'title' => 'Duplicate image id',
          'recommendation' => 'Сделайте image ids уникальными.',
          _ => 'Image id встречается больше одного раза.',
        },
      DatasetIssueType.duplicateFileName => switch (part) {
          'title' => 'Duplicate file name',
          'recommendation' =>
            'Убедитесь, что каждый image record имеет unique file_name.',
          _ => 'File_name используется несколькими image ids.',
        },
      DatasetIssueType.duplicateAnnotationId => switch (part) {
          'title' => 'Duplicate annotation id',
          'recommendation' => 'Сделайте annotation ids уникальными.',
          _ => 'Annotation id встречается больше одного раза.',
        },
      DatasetIssueType.predictionWithoutImage => switch (part) {
          'title' => 'Prediction без image',
          'recommendation' => 'Согласуйте predictions с image list датасета.',
          _ => 'Prediction не сопоставляется с image датасета.',
        },
      DatasetIssueType.predictionOnImageWithoutGroundTruth => switch (part) {
          'title' => 'Predictions на image без ground truth',
          'recommendation' => 'Проверьте полноту GT.',
          _ => 'Image имеет predictions, но не имеет ground truth.',
        },
    };
  }
}
