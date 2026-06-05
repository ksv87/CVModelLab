import 'package:cv_model_lab/cv_model_lab.dart';

import 'app_localizations.dart';

class AppLocalizationsRu extends AppLocalizations {
  const AppLocalizationsRu() : super(AppLocale.ru);

  @override
  String? lookup(MessageKey key, MessageParams p) {
    return switch (key) {
      MessageKey.remoteOpenRemoteProject => 'Открыть удалённый проект',
      MessageKey.remoteConnectToServer => 'Подключиться к серверу',
      MessageKey.remoteServerUrl => 'Адрес сервера',
      MessageKey.remoteApiKey => 'API-ключ',
      MessageKey.remoteSaveApiKey => 'Сохранить API-ключ для этого сервера',
      MessageKey.remoteTestConnection => 'Проверить подключение',
      MessageKey.remoteConnected => 'Подключено',
      MessageKey.remoteConnectionFailed =>
        'Ошибка подключения: ${p['error'] ?? ''}',
      MessageKey.remoteServerManifests => 'Проекты сервера',
      MessageKey.remoteCustomPaths => 'Произвольные пути на сервере',
      MessageKey.remoteOpenManifestProject => 'Открыть проект-манифест сервера',
      MessageKey.remoteCreateFromServerPaths =>
        'Создать удалённый проект из путей сервера',
      MessageKey.remoteSelectAnnotations => 'Выберите JSON с аннотациями',
      MessageKey.remoteSelectImagesRoot => 'Выберите каталог с изображениями',
      MessageKey.remoteSelectPredictions => 'Выберите JSON с предсказаниями',
      MessageKey.remoteOpenProject => 'Открыть проект',
      MessageKey.remoteLoadingProject => 'Загрузка удалённого проекта…',
      MessageKey.remoteNoManifests => 'На сервере не настроены проекты.',
      MessageKey.remoteImagesRoot => 'Каталог изображений',
      MessageKey.remoteAnnotations => 'Аннотации',
      MessageKey.remotePredictions => 'Предсказания',
      MessageKey.remoteSaveRemoteProject => 'Сохранить файл удалённого проекта',
      MessageKey.remoteApiKeyRequired => 'Этот сервер требует API-ключ.',
      MessageKey.remoteBrowseServer => 'Обзор сервера',
      MessageKey.remoteUp => 'Вверх',
      MessageKey.remoteForgetApiKey => 'Забыть сохранённый ключ',
      MessageKey.remoteApiKeyCleared => 'Сохранённый API-ключ удалён',
      MessageKey.remoteApiKeyInvalid => 'Неверный API-ключ.',
      MessageKey.remoteProject => 'Удалённый проект',
      MessageKey.themeTooltip => 'Тема',
      MessageKey.themeSystem => 'Системная',
      MessageKey.themeLight => 'Светлая',
      MessageKey.themeDark => 'Тёмная',
      MessageKey.navProject => 'Проект',
      MessageKey.navImages => 'Изображения',
      MessageKey.navMetrics => 'Метрики',
      MessageKey.navCompare => 'Сравнение',
      MessageKey.navReports => 'Отчёты',
      MessageKey.navMore => 'Ещё',
      MessageKey.mobileOverlayOptions => 'Параметры наложения',
      MessageKey.mobileNextImage => 'Следующее изображение',
      MessageKey.mobilePrevImage => 'Предыдущее изображение',
      MessageKey.mobileNextError => 'Следующая ошибка',
      MessageKey.mobilePrevError => 'Предыдущая ошибка',
      MessageKey.mobileOpenFilters => 'Открыть фильтры',
      MessageKey.mobileApplyFilters => 'Применить фильтры',
      MessageKey.mobileResetFilters => 'Сбросить фильтры',
      MessageKey.mobileFilters => 'Фильтры',
      MessageKey.mobileFullMatrix => 'Полная матрица',
      MessageKey.mobileTopConfusedPairs => 'Топ путаниц классов',
      MessageKey.mobileMissedPairs => 'Пропущенные объекты',
      MessageKey.mobileBackgroundFpPairs => 'Ложные на фоне',
      MessageKey.mobileLargeExportWarning =>
        'Большие экспорты могут выполняться долго в мобильном браузере.',
      MessageKey.mobileCompactLayout => 'Компактный режим',
      MessageKey.mobileDetails => 'Детали',
      MessageKey.mobileShowDetails => 'Показать детали',
      MessageKey.mobileBackToList => 'К списку',
      MessageKey.mobileModelView => 'Просмотр модели',
      MessageKey.mobileDiffView => 'Просмотр различий',
      MessageKey.mobileBaseModel => 'Базовая',
      MessageKey.mobileCandidateModel => 'Кандидат',
      MessageKey.mobileFitToScreen => 'Вписать в экран',
      MessageKey.mobileRemoteClientMode => 'Режим удалённого клиента',
      MessageKey.mobileRemoteClientExplanation =>
        'Мобильные приложения работают как удалённые клиенты. Запустите CV Model Lab Server и подключитесь к его URL.',
      MessageKey.mobileLocalUnavailable =>
        'Локальные проекты недоступны на мобильных.',
      MessageKey.mobileOpenRecentRemoteProject =>
        'Открыть недавний удалённый проект',
      MessageKey.mobileRememberApiKeyOnDevice =>
        'Запомнить API-ключ на этом устройстве',
      MessageKey.mobileForgetSavedApiKey => 'Забыть сохранённый API-ключ',
      MessageKey.mobileDisconnectServer => 'Отключиться от сервера',
      MessageKey.mobileExportDesktopPwaOnly =>
        'Этот экспорт доступен в настольной версии и PWA.',
      MessageKey.mobileExportLimited =>
        'Поддержка на мобильных ограничена в этой версии.',
      MessageKey.mobileServerUnreachable => 'Сервер недоступен',
      MessageKey.mobileNetworkError => 'Ошибка сети',
      MessageKey.parseInvalidJson => 'Некорректный JSON: ${p['error'] ?? ''}',
      MessageKey.parseAnnotationsRootMustBeObject =>
        'Корень COCO-аннотаций должен быть объектом',
      MessageKey.parseAnnotationsListsRequired =>
        'images, annotations и categories должны быть списками',
      MessageKey.parseImageMustBeObject =>
        'Запись изображения должна быть объектом',
      MessageKey.parseImageRequiresIdAndFileName =>
        'Запись изображения должна содержать id и file_name',
      MessageKey.parseDuplicateImageIdSkipped =>
        'дублирующийся image id ${p['id']} пропущен',
      MessageKey.parseCategoryMustBeObject =>
        'Запись категории должна быть объектом',
      MessageKey.parseCategoryRequiresIdAndName =>
        'Запись категории должна содержать id и name',
      MessageKey.parseDuplicateCategoryIdSkipped =>
        'дублирующийся category id ${p['id']} пропущен',
      MessageKey.parseAnnotationMustBeObject =>
        'Аннотация должна быть объектом',
      MessageKey.parseAnnotationUnknownImageId =>
        'Аннотация ссылается на неизвестный image_id',
      MessageKey.parseAnnotationUnknownCategoryId =>
        'Аннотация ссылается на неизвестный category_id',
      MessageKey.parsePredictionsRootMustBeList =>
        'Корень COCO-предсказаний должен быть списком',
      MessageKey.parsePredictionMustBeObject =>
        'Предсказание должно быть объектом',
      MessageKey.parsePredictionUnknownCategoryId =>
        'Предсказание ссылается на неизвестный category_id',
      MessageKey.parsePredictionUnknownImageId =>
        'Предсказание ссылается на неизвестный image_id',
      MessageKey.parsePredictionRequiresImageIdOrFileName =>
        'Предсказание должно содержать image_id или file_name',
      MessageKey.parsePredictionFileNameBasenameFallback =>
        'file_name предсказания сопоставлен по имени файла',
      MessageKey.parsePredictionFileNameAmbiguous =>
        'имя файла в prediction file_name неоднозначно',
      MessageKey.parsePredictionUnknownFileName =>
        'Предсказание ссылается на неизвестный file_name',
      MessageKey.parsePredictionRequiresNumericScore =>
        'Предсказание должно содержать числовой score',
      MessageKey.parsePredictionScoreOutOfRange =>
        'score предсказания вне ожидаемого диапазона 0..1',
      MessageKey.parseBboxMustHaveFourNumbers =>
        'bbox должен содержать 4 числа',
      MessageKey.parseBboxNonPositiveSize =>
        'ширина и высота bbox должны быть положительными',
      MessageKey.parseMissingImageFile => 'файл изображения не найден',
      MessageKey.parseMoreMissingImageFiles =>
        'ещё ${p['count']} файлов изображений не найдено',
      MessageKey.errorInvalidJson =>
        'Выбранный файл не является корректным JSON или не соответствует ожидаемому формату CV Model Lab.',
      MessageKey.errorPermissionDenied =>
        'CV Model Lab не смог получить доступ к выбранному файлу или папке. Выберите файл заново или используйте доступную директорию.',
      MessageKey.errorApUnavailable =>
        'Расчёт COCO AP недоступен в этой среде. В web-версии импортируйте JSON с AP-метриками.',
      MessageKey.errorOperationFailed =>
        'Операцию не удалось завершить. Проверьте подробности или выберите другой файл либо папку.',
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
      MessageKey.reportTitle => 'Отчёт CV Model Lab',
      MessageKey.reportDatasetSummary => 'Сводка датасета',
      MessageKey.reportModelRunSummary => 'Сводка запуска модели',
      MessageKey.reportOverallMetrics => 'Общие метрики',
      MessageKey.reportPerClassMetrics => 'Метрики по классам',
      MessageKey.reportSmallObjectStats => 'Статистика малых объектов',
      MessageKey.reportConfusionMatrix => 'Матрица ошибок',
      MessageKey.reportDatasetHealth => 'Проверка датасета',
      MessageKey.reportWorstCases => 'Худшие случаи',
      MessageKey.reportRecommendations => 'Рекомендации',
      MessageKey.reportCocoApMetrics => 'Метрики COCO AP',
      MessageKey.reportModelComparison => 'Сравнение моделей',
      MessageKey.reportImageErrors => 'Ошибки по изображениям',
      MessageKey.reportMatches => 'Сопоставления',
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
      MessageKey.mmApNotComputed => 'AP-метрики для этой модели не рассчитаны.',
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
      MessageKey.mmSmallRecall => 'Полнота малых',
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
        'title' => 'Низкая полнота для класса "${p['class_name']}"',
        'action' =>
          'Проверьте пропущенные объекты, согласованность разметки, добавьте примеры и рассмотрите изменение разрешения или аугментаций.',
        _ => 'Модель пропускает много объектов этого класса.',
      };

  String _recLowPrecision(MessageParams p) => switch (_part(p)) {
        'title' => 'Низкая точность для класса "${p['class_name']}"',
        'action' =>
          'Проверьте ложные срабатывания, добавьте сложные отрицательные примеры, пересмотрите таксономию классов и порог score.',
        _ =>
          'Многие предсказания этого класса являются ложными срабатываниями.',
      };

  String _recRareClass(MessageParams p) => switch (_part(p)) {
        'title' => 'Редкий класс "${p['class_name']}"',
        'action' =>
          'Соберите больше примеров или не полагайтесь на метрики этого класса.',
        _ => 'У этого класса слишком мало эталонных примеров.',
      };

  String _recClassImbalance(MessageParams p) => switch (_part(p)) {
        'title' => 'Обнаружен дисбаланс классов',
        'action' =>
          'Соберите больше данных для редких классов или используйте oversampling.',
        _ => 'Некоторые классы имеют очень малую долю эталонных объектов.',
      };

  String _recSmallObject(MessageParams p) => switch (_part(p)) {
        'title' => 'Слабое качество на малых объектах',
        'action' =>
          'Рассмотрите повышение входного разрешения, tiling, добавление примеров малых объектов или проверку очень маленьких аннотаций.',
        _ =>
          'Малые объекты класса "${p['class_name']}" имеют заметно более низкую полноту, чем крупные объекты.',
      };

  String _recHighConfidenceFp(MessageParams p) => switch (_part(p)) {
        'title' => 'Ложные срабатывания с высокой уверенностью',
        'action' =>
          'Проверьте сложные отрицательные примеры, добавьте фоновые примеры и проверьте калибровку score.',
        _ =>
          'Некоторые ложные срабатывания имеют высокую уверенность, что снижает надёжность выбора порога.',
      };

  String _recManyFn(MessageParams p) => switch (_part(p)) {
        'title' => 'Много пропущенных объектов',
        'action' =>
          'Проверьте случаи пропусков, согласованность разметки, входное разрешение, аугментации и распределение train/val.',
        _ =>
          'Пропущенные объекты составляют значимую часть текущего профиля ошибок.',
      };

  String _recClassConfusion(MessageParams p) => switch (_part(p)) {
        'title' =>
          'Путаница классов: "${p['gt_class_name']}" предсказан как "${p['pred_class_name']}"',
        'action' =>
          'Проверьте правила разметки и визуальную похожесть классов. Добавьте различающие примеры.',
        _ => 'Модель путает эти два класса при сопоставлении без учёта класса.',
      };

  String _recDatasetHealth(MessageParams p) => switch (_part(p)) {
        'title' => 'Обнаружены ошибки в датасете',
        'action' =>
          'Исправьте проблемы датасета, прежде чем доверять метрикам.',
        _ =>
          'Проверка датасета нашла ошибки, из-за которых метрики могут быть ненадёжными.',
      };

  String _recCandidateRegression(MessageParams p) => switch (_part(p)) {
        'title' => 'Модель-кандидат регрессировала',
        'action' =>
          'Проверьте изображения с ухудшениями перед выбором кандидата для продакшена.',
        _ =>
          'Модель-кандидат добавила ухудшившиеся изображения по сравнению с базовым запуском.',
      };

  String _recThresholdLowPrecision(MessageParams p) => switch (_part(p)) {
        'title' => 'Точность низкая, полнота приемлемая',
        'action' => 'Попробуйте повысить порог уверенности.',
        _ =>
          'Текущий порог сохраняет много детекций, но допускает много ложных срабатываний.',
      };

  String _recThresholdLowRecall(MessageParams p) => switch (_part(p)) {
        'title' => 'Полнота низкая, точность приемлемая',
        'action' =>
          'Попробуйте снизить порог уверенности или улучшить полноту данных и модели.',
        _ =>
          'Текущий порог может быть слишком строгим, либо модели нужно улучшить полноту.',
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
          _ => 'Изображение "$file" указано в COCO, но файл не найден.',
        },
      DatasetIssueType.unusedImageFile => switch (part) {
          'title' => 'Неиспользуемый файл изображения',
          'recommendation' =>
            'Удалите файл или добавьте для него запись изображения.',
          _ => 'Файл "$file" присутствует, но не используется датасетом.',
        },
      DatasetIssueType.unknownAnnotationImageId => switch (part) {
          'title' => 'Аннотация ссылается на неизвестное изображение',
          'recommendation' =>
            'Удалите аннотацию или добавьте отсутствующую запись изображения.',
          _ =>
            'Аннотация ${p['annotation_id']} ссылается на image_id ${p['image_id']}, которого нет в датасете.',
        },
      DatasetIssueType.unknownAnnotationCategoryId => switch (part) {
          'title' => 'Аннотация ссылается на неизвестную категорию',
          'recommendation' =>
            'Добавьте категорию в "categories" или исправьте аннотацию.',
          _ =>
            'Аннотация ${p['annotation_id']} ссылается на category_id ${p['category_id']}, которая не объявлена.',
        },
      DatasetIssueType.unknownPredictionImageId => switch (part) {
          'title' => 'Предсказание ссылается на неизвестное изображение',
          'recommendation' =>
            'Проверьте, что предсказания и аннотации используют одинаковые image_id и file_name.',
          _ =>
            'Предсказание ссылается на image_id ${p['image_id']}, которого нет в датасете.',
        },
      DatasetIssueType.unknownPredictionCategoryId => switch (part) {
          'title' => 'Предсказание ссылается на неизвестную категорию',
          'recommendation' =>
            'Согласуйте category_id предсказаний с категориями датасета.',
          _ =>
            'Предсказание ссылается на category_id ${p['category_id']}, которая не объявлена.',
        },
      DatasetIssueType.invalidBbox => switch (part) {
          'title' => 'Некорректный bbox',
          'recommendation' => 'Удалите или исправьте вырожденный bbox.',
          _ => 'Bbox имеет неположительную ширину или высоту.',
        },
      DatasetIssueType.bboxOutsideImage => switch (part) {
          'title' => 'BBox вне изображения',
          'recommendation' => 'Исправьте координаты bbox.',
          _ => 'BBox полностью находится вне границ изображения.',
        },
      DatasetIssueType.bboxPartiallyOutsideImage => switch (part) {
          'title' => 'BBox частично вне изображения',
          'recommendation' => 'Обрежьте bbox по границам изображения.',
          _ => 'BBox выходит за границы изображения.',
        },
      DatasetIssueType.extremeAspectRatio => switch (part) {
          'title' => 'Экстремальное соотношение сторон',
          'recommendation' => 'Проверьте, не является ли bbox ошибочным.',
          _ => 'BBox имеет экстремальное соотношение сторон.',
        },
      DatasetIssueType.tinyBbox => switch (part) {
          'title' => 'Очень маленький bbox',
          'recommendation' => 'Проверьте, что аннотация не является ошибкой.',
          _ => 'BBox очень маленький.',
        },
      DatasetIssueType.hugeBbox => switch (part) {
          'title' => 'Очень большой bbox',
          'recommendation' => 'Подтвердите, что такой bbox указан намеренно.',
          _ => 'BBox покрывает большую часть изображения.',
        },
      DatasetIssueType.imageWithoutGroundTruth => switch (part) {
          'title' => 'Изображение без эталонной разметки',
          'recommendation' =>
            'Подтвердите, что изображение намеренно является отрицательным примером.',
          _ => 'Изображение "$file" не имеет аннотаций.',
        },
      DatasetIssueType.classWithoutGroundTruth => switch (part) {
          'title' => 'Класс без эталонной разметки',
          'recommendation' =>
            'Удалите неиспользуемый класс или добавьте обучающие данные.',
          _ => 'Класс "$cls" не имеет эталонных объектов.',
        },
      DatasetIssueType.rareClass => switch (part) {
          'title' => 'Редкий класс',
          'recommendation' => 'Соберите больше примеров для этого класса.',
          _ => 'Класс "$cls" имеет мало эталонных объектов.',
        },
      DatasetIssueType.classImbalance => switch (part) {
          'title' => 'Дисбаланс класса',
          'recommendation' =>
            'Рассмотрите балансировку датасета или веса классов.',
          _ => 'Класс "$cls" имеет малую долю эталонных объектов.',
        },
      DatasetIssueType.duplicateImageId => switch (part) {
          'title' => 'Дублирующийся image id',
          'recommendation' => 'Сделайте image_id уникальными.',
          _ => 'image_id встречается больше одного раза.',
        },
      DatasetIssueType.duplicateFileName => switch (part) {
          'title' => 'Дублирующееся file_name',
          'recommendation' =>
            'Убедитесь, что каждая запись изображения имеет уникальный file_name.',
          _ => 'file_name используется несколькими image id.',
        },
      DatasetIssueType.duplicateAnnotationId => switch (part) {
          'title' => 'Дублирующийся annotation id',
          'recommendation' => 'Сделайте annotation_id уникальными.',
          _ => 'annotation_id встречается больше одного раза.',
        },
      DatasetIssueType.predictionWithoutImage => switch (part) {
          'title' => 'Предсказание без изображения',
          'recommendation' =>
            'Согласуйте предсказания со списком изображений датасета.',
          _ => 'Предсказание не сопоставляется с изображением датасета.',
        },
      DatasetIssueType.predictionOnImageWithoutGroundTruth => switch (part) {
          'title' => 'Предсказания на изображении без эталонной разметки',
          'recommendation' => 'Проверьте полноту эталонной разметки.',
          _ =>
            'Изображение имеет предсказания, но не имеет эталонной разметки.',
        },
    };
  }
}
