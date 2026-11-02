// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline => 'Создание приложений с ИИ,\nтеперь в мультиплеере.';

  @override
  String get initializingNode => 'Запуск…';

  @override
  String get resumeSplashLoading => 'Загрузка…';

  @override
  String get clockDriftWarningTitle => 'Неверное системное время';

  @override
  String clockDriftWarningBody(String drift) {
    return 'Часы вашего устройства расходятся с часами узла на $drift. Пока системное время не исправлено, в приложении возможны сбои и несоответствия.';
  }

  @override
  String get clockDriftWarningInstruction =>
      'Включите автоматическую синхронизацию времени на устройстве.';

  @override
  String get clockDriftRecommendationTitle => 'Рекомендация';

  @override
  String get clockDriftRecommendationBody =>
      'Чтобы расхождение было минимальным, оставьте в настройках включёнными «Автоматические дата и время» и «Автоматический часовой пояс» — тогда устройство будет получать время из сети.';

  @override
  String get clockDriftDismiss => 'ОК';

  @override
  String clockDriftAhead(String seconds) {
    return 'спешат на $seconds с';
  }

  @override
  String clockDriftBehind(String seconds) {
    return 'отстают на $seconds с';
  }

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsBuildInfo => 'Сведения о сборке';

  @override
  String get settingsDiagnostics => 'Диагностика';

  @override
  String get settingsDeviceBenchmark => 'Тест производительности';

  @override
  String get settingsDeviceBenchmarkSubtitle =>
      'Запустить замеры производительности на устройстве';

  @override
  String get perfTitle => 'Тест производительности';

  @override
  String get perfIntroTitle =>
      'Запустите тест производительности на этом устройстве';

  @override
  String get perfIntroDescription =>
      'Замерьте хеширование, частичную синхронизацию, создание блоков и отправку из кошелька, чтобы увидеть, как работает это устройство.';

  @override
  String get perfIntroNote =>
      'Пока результаты хранятся только на этом устройстве. Производительность может меняться в зависимости от заряда батареи, нагрева и фоновой активности.';

  @override
  String get perfCatalogLoadError => 'Не удалось загрузить каталог тестов.';

  @override
  String get perfCatalogLoading => 'Загрузка каталога тестов…';

  @override
  String get perfProfileQuick => 'Быстрая проверка';

  @override
  String get perfProfileStandard => 'Полный тест';

  @override
  String perfRunProfile(String profile) {
    return 'Запустить: $profile';
  }

  @override
  String perfStepCount(int count) {
    return 'Шагов: $count';
  }

  @override
  String get perfCurrentRunTitle => 'Текущий запуск';

  @override
  String get perfRunInProgressTitle => 'Тест выполняется';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'На этом устройстве уже выполняется тест «$profile».';
  }

  @override
  String get perfRunInProgressDescriptionUnknown =>
      'На этом устройстве уже выполняется тест.';

  @override
  String get perfOpenCurrentRun => 'Открыть текущий запуск';

  @override
  String get perfLatestResultsTitle => 'Последние результаты';

  @override
  String perfLatestResultsDescription(String profile) {
    return 'Результаты теста «$profile» готовы к просмотру.';
  }

  @override
  String get perfLatestResultsDescriptionUnknown =>
      'Результаты теста готовы к просмотру.';

  @override
  String get perfViewLatestResults => 'Смотреть последние результаты';

  @override
  String get perfNoRunAvailableTitle => 'Нет запусков';

  @override
  String get perfNoRunAvailableDescription =>
      'Запустите тест на экране тестов, чтобы увидеть здесь ход выполнения или результаты.';

  @override
  String get perfBackToBenchmarks => 'Назад к тестам';

  @override
  String get perfRunPausedNodeNotice =>
      'Фоновый узел приостановлен, пока выполняется этот тест.';

  @override
  String get perfStateRunning => 'Выполняется';

  @override
  String get perfStateStarting => 'Запуск';

  @override
  String get perfStateCompleted => 'Завершён';

  @override
  String get perfStateFailed => 'Ошибка';

  @override
  String get perfStateCancelled => 'Отменён';

  @override
  String perfProgressValue(int completed, int total) {
    return '$completed из $total шагов';
  }

  @override
  String perfPreparingProfile(String profile) {
    return 'Подготовка: $profile';
  }

  @override
  String perfCurrentStep(String label) {
    return 'Текущий шаг: $label';
  }

  @override
  String perfElapsed(String duration) {
    return 'Прошло: $duration';
  }

  @override
  String get perfResultsTitle => 'Результаты';

  @override
  String get perfResultProfile => 'Профиль';

  @override
  String get perfResultDevice => 'Устройство';

  @override
  String get perfResultOperatingSystem => 'ОС';

  @override
  String get perfResultCpu => 'Процессор';

  @override
  String get perfResultLogicalCores => 'Логические ядра';

  @override
  String get perfResultMeasurements => 'Замеры';

  @override
  String get perfSuitePrimitives => 'Примитивы';

  @override
  String get perfSuitePartialSync => 'Частичная синхронизация';

  @override
  String get perfSuitePartialBlockProduction => 'Создание блоков';

  @override
  String get perfSuiteWalletSend => 'Отправка из кошелька';

  @override
  String get perfScenarioDefault => 'Вариант по умолчанию';

  @override
  String perfContextTxCount(int count) {
    return '$count тр.';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'Раскладка $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return 'Форма $value';
  }

  @override
  String get perfDetailScenario => 'Сценарий';

  @override
  String get perfDetailAverage => 'Среднее';

  @override
  String get perfDetailMinMax => 'Мин. / Макс.';

  @override
  String get perfDetailRuns => 'Запуски';

  @override
  String get perfDetailMetadataTitle => 'Сведения о сценарии';

  @override
  String get perfDetailImplementationTitle => 'Сведения о реализации';

  @override
  String get perfDetailNotesTitle => 'Примечания';

  @override
  String get perfDetailFlow => 'Поток';

  @override
  String get perfDetailTxCount => 'Число транзакций';

  @override
  String get perfDetailBatchLayout => 'Раскладка пакета';

  @override
  String get perfDetailTransactionShape => 'Форма транзакции';

  @override
  String get perfDetailTouchedLeaves => 'Затронутые листья';

  @override
  String get perfDetailProofNodes => 'Узлы доказательства';

  @override
  String get perfDetailProofSize => 'Размер доказательства';

  @override
  String get perfCancelFailed => 'Не удалось отменить текущий тест.';

  @override
  String get perfRunUnavailable => 'Этот тест больше недоступен.';

  @override
  String get commonOk => 'ОК';

  @override
  String get buildInfoVersion => 'Версия';

  @override
  String get buildInfoCommit => 'Коммит';

  @override
  String get buildInfoBranch => 'Ветка';

  @override
  String get buildInfoCommitTime => 'Время коммита';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Цель Cargo';

  @override
  String get buildInfoFeatures => 'Функции';

  @override
  String get buildInfoOptLevel => 'Уровень оптимизации';

  @override
  String get buildInfoDebug => 'Отладка';

  @override
  String get retry => 'Повторить';

  @override
  String get zkIdentityAppNotFoundTitle => 'Сначала установите ZK Passport';

  @override
  String get zkIdentityAppNotFoundDetail =>
      'Он создаёт ваше доказательство и возвращает вас сюда';

  @override
  String get zkIdentityInstallCta => 'Установить';

  @override
  String get zkIdentityStepLabelOpenApp => 'Открываем ZK Passport';

  @override
  String get zkIdentityStepDescOpenApp =>
      'Готовим запрос на доказательство с вашим сохранённым паспортом';

  @override
  String get zkIdentityCheckAppCta => 'Продолжить';

  @override
  String get zkIdentityAccountPreparingTitle => 'Подготовка аккаунта';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'Подключаем ваш аккаунт Social Vibecoding, в который вы вошли';

  @override
  String get zkIdentityAccountUnavailable =>
      'Войдите в Social Vibecoding, прежде чем начать проверку.';

  @override
  String get zkIdentityStepLabelScan => 'Использовать сохранённый паспорт';

  @override
  String get zkIdentityStepDescScan =>
      'Используется паспорт, уже сохранённый в ZK Passport';

  @override
  String get zkIdentityConfirmScannedBody =>
      'Будет использован ваш сохранённый паспорт.';

  @override
  String get zkIdentityConfirmScannedYesCta => 'Продолжить';

  @override
  String get zkIdentityConfirmScannedNoCta => 'Не сейчас';

  @override
  String get zkIdentityStepLabelReady => 'Создать доказательство';

  @override
  String get zkIdentityStepDescReady =>
      'ZK Passport попросит вас подтвердить и создать доказательство';

  @override
  String get zkIdentityReadyBody =>
      'ZK Passport создаёт доказательство из вашего сохранённого паспорта примерно за минуту.';

  @override
  String get zkIdentityReadyBullet1 => 'Имя, фото и документ не передаются';

  @override
  String get zkIdentityReadyBullet2 => 'Вы отправляете только доказательство';

  @override
  String get zkIdentityReadyBullet3 => 'Никаких личных данных в блокчейне';

  @override
  String get zkIdentityReadyCta => 'Открыть ZK Passport';

  @override
  String get zkIdentityStepLabelVerifying => 'Проверка';

  @override
  String get zkIdentityStepDescVerifying =>
      'Создаём и проверяем ваше доказательство';

  @override
  String get zkIdentityStepLabelResult => 'Результат';

  @override
  String get zkIdentityStepDescResult => 'Посмотрите итог проверки';

  @override
  String get zkIdentitySubTaskOpening => 'Открываем ZK Passport';

  @override
  String get zkIdentitySubTaskWaiting => 'Ждём ваше доказательство';

  @override
  String get zkIdentitySubTaskChecking => 'Проверяем ваше доказательство';

  @override
  String get zkIdentitySubTaskWrapping => 'Упаковываем ваше доказательство';

  @override
  String get zkIdentitySubTaskFinal => 'Итоговая проверка';

  @override
  String get zkIdentityResultSuccessTitle => 'Вы — уникальный человек!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      'Вы доказали свою уникальность, не раскрыв имя, фото и документ';

  @override
  String get zkIdentityStatusUniqueness => 'Уникальный человек';

  @override
  String get zkIdentityStatusUniquenessValue => 'Подтверждено';

  @override
  String get zkIdentityStatusFaceMatchLabel => 'Проверка лица';

  @override
  String get zkIdentityStatusPrivacyValue => 'Ничего не передано';

  @override
  String get zkIdentityCancelVerification => 'Отмена';

  @override
  String get zkIdentityGoToZkPassport => 'Перейти в ZK Passport';

  @override
  String get zkIdentityTryAgain => 'Попробовать снова';

  @override
  String get zkIdentityWalletClaimTitle => 'Подключите кошелёк программы';

  @override
  String get zkIdentityWalletClaimDescription =>
      'Этот аккаунт Social отличается от аккаунта, к которому привязан ваш прежний кошелёк. Один раз подтвердите e-mail исходной программы, чтобы подключить его.';

  @override
  String get zkIdentityWalletClaimEmailLabel => 'E-mail исходной программы';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      'Укажите e-mail, с которым вы регистрировались в исходной программе Homeroom.';

  @override
  String get zkIdentityWalletClaimSendCode => 'Отправить код подтверждения';

  @override
  String get zkIdentityWalletClaimSendingCode => 'Отправляем код…';

  @override
  String get zkIdentityWalletClaimCodeSent =>
      'Введите 6-значный код, отправленный на этот e-mail.';

  @override
  String get zkIdentityWalletClaimCodeLabel => 'Код подтверждения';

  @override
  String get zkIdentityWalletClaimConnect => 'Подключить кошелёк и продолжить';

  @override
  String get zkIdentityWalletClaimConnecting => 'Подключаем кошелёк…';

  @override
  String get zkIdentityWalletClaimChangeEmail => 'Указать другой e-mail';

  @override
  String get zkIdentityWalletClaimEmailRequired =>
      'Введите действительный адрес e-mail.';

  @override
  String get zkIdentityWalletClaimCodeRequired => 'Введите 6-значный код.';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'Кошелёк подключён, но приложению не удалось завершить его подготовку. Повторите попытку.';

  @override
  String get zkIdentityDone => 'Готово';

  @override
  String get zkIdentityStatusFaceMatchVerified => 'Пройдена';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'Пропущена';

  @override
  String get zkIdentityStatusPrivacyLabel => 'Конфиденциальность';

  @override
  String get zkIdentityStatusVerifiedDateLabel => 'Проверено';

  @override
  String get zkIdentityStatusProofIdLabel => 'ID доказательства';

  @override
  String get zkIdentityStatusVerifyDurationLabel => 'Проверка';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'Упаковка';

  @override
  String get zkIdentityStatusFinalCheckLabel => 'Итоговая проверка';

  @override
  String get zkIdentityResultFailureTitle => 'Не удалось проверить';

  @override
  String get zkIdentityResultFailureSubtitle =>
      'Вы не передавали имя, фото и документ';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonCopied => 'Скопировано';

  @override
  String get buildInfoAppVersion => 'Версия приложения';

  @override
  String get buildInfoBuildNumber => 'Номер сборки';

  @override
  String get settingsDebugMode => 'Режим отладки';

  @override
  String get settingsDebugModeEnabled => 'HTTP-запросы записываются в память';

  @override
  String get settingsDebugModeDisabled => 'Выкл. · сетевой журнал не ведётся';

  @override
  String get settingsHttpLogs => 'HTTP-журналы';

  @override
  String get settingsHttpLogsSubtitle => 'Просмотр записанных сетевых запросов';

  @override
  String get httpLogsTitle => 'HTTP-журналы';

  @override
  String get httpLogsEmpty =>
      'Запросов пока нет. Выполните какое-нибудь сетевое действие, чтобы увидеть здесь журналы.';

  @override
  String get httpLogsCopy => 'Копировать всё';

  @override
  String get httpLogsClear => 'Очистить';

  @override
  String get httpLogsCopied => 'Журналы скопированы в буфер обмена';

  @override
  String get httpLogsShare => 'Делиться журналами с командой';

  @override
  String get httpLogsSharing => 'Журналы отправляются команде каждые 30 с…';

  @override
  String get httpLogsStopSharing => 'Прекратить отправку';

  @override
  String get httpLogsShareStopped =>
      'Сервер остановил отправку журналов. Вы можете снова включить её в любой момент.';

  @override
  String get httpLogsShareNoParticipant =>
      'ID участника пока нет — завершите знакомство с приложением, чтобы делиться журналами';

  @override
  String get httpLogsFilterHint => 'Фильтр по URL';

  @override
  String get httpLogsNoMatches => 'Нет запросов, подходящих под фильтр.';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$count из $total';
  }

  @override
  String get widgetInstructionsTitle => 'Добавьте виджет Homeroom';

  @override
  String widgetInstructionsBody(String name) {
    return '$name добавлено в ваш виджет dApps Homeroom. Чтобы увидеть его на главном экране, один раз добавьте виджет:';
  }

  @override
  String get widgetInstructionsStep1 =>
      'Нажмите и удерживайте пустое место на главном экране';

  @override
  String get widgetInstructionsStep2 =>
      'Нажмите «Изменить» в верхнем углу, затем «Добавить виджет»';

  @override
  String get widgetInstructionsStep3 =>
      'Найдите Homeroom и добавьте виджет dApps';

  @override
  String get widgetInstructionsDone => 'Готово';

  @override
  String get svShellConnectingTitle => 'Подключение к Homeroom…';

  @override
  String get svShellOfflineMessage =>
      'Не удаётся связаться с Homeroom. Проверьте подключение и повторите попытку.';

  @override
  String get stakingManagerTitle => 'Режим стейкинга';

  @override
  String get stakingDelegateIntro =>
      'Делегируйте свой стейк серверу. Ваш узел продолжит работать, но стейкинг от вашего имени будет вести сервер.';

  @override
  String get stakingServerName => 'Сервер';

  @override
  String get stakingDelegateEffect =>
      'Ваш узел перестанет создавать блоки. Пока стейк делегирован, вы получаете половину очков за создание блоков, которые заработали бы, создавая блоки напрямую на этом телефоне.';

  @override
  String get stakingDelegateNote =>
      'Вы можете в любой момент вернуться к собственному стейкингу.';

  @override
  String get stakingDelegateConfirm => 'Подтвердить делегирование';

  @override
  String get stakingDelegating => 'Делегирование…';

  @override
  String get stakingDelegateError =>
      'Не удалось отправить делегирование. Проверьте подключение и повторите попытку.';

  @override
  String get stakingDelegationActiveTitle => 'Делегирование активно';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'Ваш стейк делегирован валидатору $validator. Вы получаете половину очков за создание блоков, которые заработали бы, создавая блоки напрямую на этом телефоне.';
  }

  @override
  String get stakingDone => 'Готово';

  @override
  String get stakingUndelegateTitle => 'Остановить делегирование?';

  @override
  String get stakingUndelegateBody =>
      'Ваш стейк вернётся на этот телефон. Ваш узел будет создавать блоки напрямую и получать все очки за создание блоков.';

  @override
  String get stakingUndelegateConfirm => 'Остановить делегирование';

  @override
  String get stakingUndelegateError =>
      'Не удалось остановить делегирование. Проверьте подключение и повторите попытку.';

  @override
  String get versionUpdateRequiredTitle => 'Требуется обновление';

  @override
  String get versionUpdateAvailableTitle => 'Доступно обновление';

  @override
  String get versionUpdateAction => 'Обновить';

  @override
  String get versionUpdateLater => 'Позже';

  @override
  String get versionUpdateFallbackMessage =>
      'Доступна новая версия приложения.';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonDeny => 'Отклонить';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get commonApprove => 'Одобрить';

  @override
  String get txConfirmTitle => 'Подтвердите транзакцию';

  @override
  String get txConfirmSubtitleDefault =>
      'Dapp запрашивает отправку транзакции.';

  @override
  String get txAmount => 'Сумма';

  @override
  String get txDetails => 'Подробности';

  @override
  String get txFrom => 'От';

  @override
  String get txTo => 'Кому';

  @override
  String get txFee => 'Комиссия';

  @override
  String get txMemo => 'Мемо';

  @override
  String get verifyIdentityTitle => 'Подтверждение личности';

  @override
  String verifyIdentityRequest(String name) {
    return '$name запрашивает подтверждение вашей личности';
  }

  @override
  String get verifyIdentityExplanation =>
      'Будет подписан запрос вашим закрытым ключом, чтобы подтвердить, что кошелёк принадлежит вам. Транзакция не отправляется, токены не тратятся.';

  @override
  String get zkChallengeBusy =>
      'Доказательство zkPassport ещё обрабатывается. Повторите попытку чуть позже.';

  @override
  String get zkChallengeResetDone => 'Состояние ZK-доказательства сброшено';
}
