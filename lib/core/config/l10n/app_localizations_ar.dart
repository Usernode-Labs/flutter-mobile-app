// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline =>
      'بناء التطبيقات بالذكاء الاصطناعي،\nوالآن بمشاركة الجميع.';

  @override
  String get initializingNode => 'جارٍ البدء…';

  @override
  String get resumeSplashLoading => 'جارٍ التحميل…';

  @override
  String get clockDriftWarningTitle => 'وقت النظام غير صحيح';

  @override
  String clockDriftWarningBody(String drift) {
    return 'ساعة جهازك تختلف عن ساعة العقدة بمقدار $drift. قد تلاحظ بعض التناقضات في التطبيق إلى أن يُصحَّح وقت النظام.';
  }

  @override
  String get clockDriftWarningInstruction =>
      'فعّل مزامنة الوقت التلقائية على جهازك.';

  @override
  String get clockDriftRecommendationTitle => 'توصية';

  @override
  String get clockDriftRecommendationBody =>
      'لأقل قدر من الفارق، أبقِ خيارَي «التاريخ والوقت التلقائيان» و«المنطقة الزمنية التلقائية» مفعّلين في الإعدادات ليحصل الجهاز على الوقت من الشبكة.';

  @override
  String get clockDriftDismiss => 'حسنًا';

  @override
  String clockDriftAhead(String seconds) {
    return 'متقدمة بـ $seconds ث';
  }

  @override
  String clockDriftBehind(String seconds) {
    return 'متأخرة بـ $seconds ث';
  }

  @override
  String get settingsAbout => 'حول';

  @override
  String get settingsBuildInfo => 'معلومات الإصدار';

  @override
  String get settingsDiagnostics => 'التشخيص';

  @override
  String get settingsDeviceBenchmark => 'اختبار أداء الجهاز';

  @override
  String get settingsDeviceBenchmarkSubtitle =>
      'تشغيل قياسات الأداء على الجهاز';

  @override
  String get perfTitle => 'اختبار أداء الجهاز';

  @override
  String get perfIntroTitle => 'شغّل اختبار أداء على هذا الجهاز';

  @override
  String get perfIntroDescription =>
      'قِس أحمال التجزئة والمزامنة الجزئية وإنتاج الكتل وإرسال المحفظة لترى كيف يعمل هذا الجهاز.';

  @override
  String get perfIntroNote =>
      'تبقى النتائج على هذا الجهاز حاليًا. قد يختلف الأداء بحسب مستوى البطارية والحرارة والنشاط في الخلفية.';

  @override
  String get perfCatalogLoadError => 'تعذّر تحميل قائمة الاختبارات.';

  @override
  String get perfCatalogLoading => 'جارٍ تحميل قائمة الاختبارات…';

  @override
  String get perfProfileQuick => 'فحص سريع';

  @override
  String get perfProfileStandard => 'اختبار كامل';

  @override
  String perfRunProfile(String profile) {
    return 'تشغيل: $profile';
  }

  @override
  String perfStepCount(int count) {
    return '$count خطوات';
  }

  @override
  String get perfCurrentRunTitle => 'التشغيل الحالي';

  @override
  String get perfRunInProgressTitle => 'الاختبار قيد التشغيل';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'يعمل اختبار «$profile» بالفعل على هذا الجهاز.';
  }

  @override
  String get perfRunInProgressDescriptionUnknown =>
      'يعمل اختبار بالفعل على هذا الجهاز.';

  @override
  String get perfOpenCurrentRun => 'فتح التشغيل الحالي';

  @override
  String get perfLatestResultsTitle => 'أحدث النتائج';

  @override
  String perfLatestResultsDescription(String profile) {
    return 'نتائج «$profile» جاهزة للمراجعة.';
  }

  @override
  String get perfLatestResultsDescriptionUnknown =>
      'نتائج الاختبار جاهزة للمراجعة.';

  @override
  String get perfViewLatestResults => 'عرض أحدث النتائج';

  @override
  String get perfNoRunAvailableTitle => 'لا يوجد اختبار';

  @override
  String get perfNoRunAvailableDescription =>
      'ابدأ اختبارًا من شاشة الاختبارات لترى التقدّم أو النتائج هنا.';

  @override
  String get perfBackToBenchmarks => 'العودة إلى الاختبارات';

  @override
  String get perfRunPausedNodeNotice =>
      'العقدة العاملة في الخلفية متوقفة مؤقتًا أثناء تشغيل هذا الاختبار.';

  @override
  String get perfStateRunning => 'قيد التشغيل';

  @override
  String get perfStateStarting => 'جارٍ البدء';

  @override
  String get perfStateCompleted => 'اكتمل';

  @override
  String get perfStateFailed => 'فشل';

  @override
  String get perfStateCancelled => 'أُلغي';

  @override
  String perfProgressValue(int completed, int total) {
    return '$completed من $total خطوات';
  }

  @override
  String perfPreparingProfile(String profile) {
    return 'جارٍ تجهيز: $profile';
  }

  @override
  String perfCurrentStep(String label) {
    return 'الخطوة الحالية: $label';
  }

  @override
  String perfElapsed(String duration) {
    return 'المدة المنقضية: $duration';
  }

  @override
  String get perfResultsTitle => 'النتائج';

  @override
  String get perfResultProfile => 'الملف';

  @override
  String get perfResultDevice => 'الجهاز';

  @override
  String get perfResultOperatingSystem => 'نظام التشغيل';

  @override
  String get perfResultCpu => 'المعالج';

  @override
  String get perfResultLogicalCores => 'الأنوية المنطقية';

  @override
  String get perfResultMeasurements => 'القياسات';

  @override
  String get perfSuitePrimitives => 'العمليات الأساسية';

  @override
  String get perfSuitePartialSync => 'المزامنة الجزئية';

  @override
  String get perfSuitePartialBlockProduction => 'إنتاج الكتل';

  @override
  String get perfSuiteWalletSend => 'الإرسال من المحفظة';

  @override
  String get perfScenarioDefault => 'الحالة الافتراضية';

  @override
  String perfContextTxCount(int count) {
    return '$count معاملة';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'التخطيط $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return 'الشكل $value';
  }

  @override
  String get perfDetailScenario => 'السيناريو';

  @override
  String get perfDetailAverage => 'المتوسط';

  @override
  String get perfDetailMinMax => 'الأدنى / الأعلى';

  @override
  String get perfDetailRuns => 'مرات التشغيل';

  @override
  String get perfDetailMetadataTitle => 'تفاصيل السيناريو';

  @override
  String get perfDetailImplementationTitle => 'تفاصيل التنفيذ';

  @override
  String get perfDetailNotesTitle => 'ملاحظات';

  @override
  String get perfDetailFlow => 'التدفق';

  @override
  String get perfDetailTxCount => 'عدد المعاملات';

  @override
  String get perfDetailBatchLayout => 'تخطيط الدفعة';

  @override
  String get perfDetailTransactionShape => 'شكل المعاملة';

  @override
  String get perfDetailTouchedLeaves => 'الأوراق التي جرى الوصول إليها';

  @override
  String get perfDetailProofNodes => 'عقد الإثبات';

  @override
  String get perfDetailProofSize => 'حجم الإثبات';

  @override
  String get perfCancelFailed => 'تعذّر إلغاء الاختبار الجاري.';

  @override
  String get perfRunUnavailable => 'لم يعد هذا الاختبار متاحًا.';

  @override
  String get commonOk => 'حسنًا';

  @override
  String get buildInfoVersion => 'الإصدار';

  @override
  String get buildInfoCommit => 'الإيداع (Commit)';

  @override
  String get buildInfoBranch => 'الفرع';

  @override
  String get buildInfoCommitTime => 'وقت الإيداع';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'هدف Cargo';

  @override
  String get buildInfoFeatures => 'الميزات';

  @override
  String get buildInfoOptLevel => 'مستوى التحسين';

  @override
  String get buildInfoDebug => 'التصحيح';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get zkIdentityAppNotFoundTitle => 'ثبّت ZK Passport أولًا';

  @override
  String get zkIdentityAppNotFoundDetail => 'ينشئ إثباتك ثم يعيدك إلى هنا';

  @override
  String get zkIdentityInstallCta => 'تثبيت';

  @override
  String get zkIdentityStepLabelOpenApp => 'جارٍ فتح ZK Passport';

  @override
  String get zkIdentityStepDescOpenApp =>
      'جارٍ تجهيز طلب إثبات بجواز سفرك المحفوظ';

  @override
  String get zkIdentityCheckAppCta => 'متابعة';

  @override
  String get zkIdentityAccountPreparingTitle => 'جارٍ تجهيز حسابك';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'جارٍ ربط حساب Social Vibecoding المسجَّل دخولك به';

  @override
  String get zkIdentityAccountUnavailable =>
      'سجّل الدخول إلى Social Vibecoding قبل بدء التحقق.';

  @override
  String get zkIdentityStepLabelScan => 'استخدام جواز السفر المحفوظ';

  @override
  String get zkIdentityStepDescScan =>
      'يستخدم جواز السفر المخزَّن بالفعل في ZK Passport';

  @override
  String get zkIdentityConfirmScannedBody => 'سيُستخدم جواز سفرك المحفوظ.';

  @override
  String get zkIdentityConfirmScannedYesCta => 'متابعة';

  @override
  String get zkIdentityConfirmScannedNoCta => 'ليس الآن';

  @override
  String get zkIdentityStepLabelReady => 'إنشاء الإثبات';

  @override
  String get zkIdentityStepDescReady =>
      'سيطلب منك ZK Passport الموافقة وإنشاء الإثبات';

  @override
  String get zkIdentityReadyBody =>
      'ينشئ ZK Passport الإثبات من جواز سفرك المحفوظ في نحو دقيقة.';

  @override
  String get zkIdentityReadyBullet1 => 'لا تُشارَك أي أسماء أو صور أو هويات';

  @override
  String get zkIdentityReadyBullet2 => 'ترسل إثباتًا فقط';

  @override
  String get zkIdentityReadyBullet3 => 'لا يُخزَّن أي شيء شخصي على السلسلة';

  @override
  String get zkIdentityReadyCta => 'فتح ZK Passport';

  @override
  String get zkIdentityStepLabelVerifying => 'جارٍ التحقق';

  @override
  String get zkIdentityStepDescVerifying => 'جارٍ إنشاء إثباتك وفحصه';

  @override
  String get zkIdentityStepLabelResult => 'النتيجة';

  @override
  String get zkIdentityStepDescResult => 'اطّلع على نتيجة التحقق';

  @override
  String get zkIdentitySubTaskOpening => 'جارٍ فتح ZK Passport';

  @override
  String get zkIdentitySubTaskWaiting => 'في انتظار إثباتك';

  @override
  String get zkIdentitySubTaskChecking => 'جارٍ فحص إثباتك';

  @override
  String get zkIdentitySubTaskWrapping => 'جارٍ تغليف إثباتك';

  @override
  String get zkIdentitySubTaskFinal => 'الفحص النهائي';

  @override
  String get zkIdentityResultSuccessTitle => 'أنت إنسان فريد!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      'أثبتّ أنك فريد دون مشاركة اسمك أو صورتك أو هويتك';

  @override
  String get zkIdentityStatusUniqueness => 'إنسان فريد';

  @override
  String get zkIdentityStatusUniquenessValue => 'مؤكَّد';

  @override
  String get zkIdentityStatusFaceMatchLabel => 'فحص الوجه';

  @override
  String get zkIdentityStatusPrivacyValue => 'لم يُشارَك أي شيء';

  @override
  String get zkIdentityCancelVerification => 'إلغاء';

  @override
  String get zkIdentityGoToZkPassport => 'الانتقال إلى ZK Passport';

  @override
  String get zkIdentityTryAgain => 'حاول مرة أخرى';

  @override
  String get zkIdentityWalletClaimTitle => 'اربط محفظة البرنامج';

  @override
  String get zkIdentityWalletClaimDescription =>
      'حساب Social هذا مختلف عن الحساب الذي يحتفظ بمحفظتك الحالية. تحقّق مرة واحدة من بريد برنامجك الأصلي لربطها.';

  @override
  String get zkIdentityWalletClaimEmailLabel => 'بريد البرنامج الأصلي';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      'استخدم البريد الذي سجّلت به في برنامج Homeroom الأصلي.';

  @override
  String get zkIdentityWalletClaimSendCode => 'إرسال رمز التحقق';

  @override
  String get zkIdentityWalletClaimSendingCode => 'جارٍ إرسال الرمز…';

  @override
  String get zkIdentityWalletClaimCodeSent =>
      'أدخل الرمز المكوّن من 6 أرقام المُرسَل إلى ذلك البريد.';

  @override
  String get zkIdentityWalletClaimCodeLabel => 'رمز التحقق';

  @override
  String get zkIdentityWalletClaimConnect => 'ربط المحفظة والمتابعة';

  @override
  String get zkIdentityWalletClaimConnecting => 'جارٍ ربط المحفظة…';

  @override
  String get zkIdentityWalletClaimChangeEmail => 'استخدام بريد آخر';

  @override
  String get zkIdentityWalletClaimEmailRequired =>
      'أدخل عنوان بريد إلكتروني صالحًا.';

  @override
  String get zkIdentityWalletClaimCodeRequired =>
      'أدخل الرمز المكوّن من 6 أرقام.';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'رُبطت محفظتك، لكن التطبيق لم يتمكن من إكمال تجهيزها. حاول مرة أخرى.';

  @override
  String get zkIdentityDone => 'تم';

  @override
  String get zkIdentityStatusFaceMatchVerified => 'تم التحقق';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'تم التخطي';

  @override
  String get zkIdentityStatusPrivacyLabel => 'الخصوصية';

  @override
  String get zkIdentityStatusVerifiedDateLabel => 'تاريخ التحقق';

  @override
  String get zkIdentityStatusProofIdLabel => 'معرّف الإثبات';

  @override
  String get zkIdentityStatusVerifyDurationLabel => 'التحقق';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'التغليف';

  @override
  String get zkIdentityStatusFinalCheckLabel => 'الفحص النهائي';

  @override
  String get zkIdentityResultFailureTitle => 'تعذّر التحقق';

  @override
  String get zkIdentityResultFailureSubtitle =>
      'لم تشارك اسمك أو صورتك أو هويتك';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonCopied => 'تم النسخ';

  @override
  String get buildInfoAppVersion => 'إصدار التطبيق';

  @override
  String get buildInfoBuildNumber => 'رقم البناء';

  @override
  String get settingsDebugMode => 'وضع التصحيح';

  @override
  String get settingsDebugModeEnabled => 'يجري حفظ طلبات HTTP في الذاكرة';

  @override
  String get settingsDebugModeDisabled => 'متوقف · بلا تسجيل للشبكة';

  @override
  String get settingsHttpLogs => 'سجلات HTTP';

  @override
  String get settingsHttpLogsSubtitle => 'عرض طلبات الشبكة المسجَّلة';

  @override
  String get httpLogsTitle => 'سجلات HTTP';

  @override
  String get httpLogsEmpty =>
      'لم يُسجَّل أي طلب بعد. أجرِ بعض النشاط على الشبكة لتظهر السجلات هنا.';

  @override
  String get httpLogsCopy => 'نسخ الكل';

  @override
  String get httpLogsClear => 'مسح';

  @override
  String get httpLogsCopied => 'نُسخت السجلات إلى الحافظة';

  @override
  String get httpLogsShare => 'مشاركة السجلات مع الفريق';

  @override
  String get httpLogsSharing => 'تُشارَك السجلات مع الفريق كل 30 ثانية…';

  @override
  String get httpLogsStopSharing => 'إيقاف المشاركة';

  @override
  String get httpLogsShareStopped =>
      'أوقف الخادم مشاركة السجلات. يمكنك المشاركة مجددًا في أي وقت.';

  @override
  String get httpLogsShareNoParticipant =>
      'لا يوجد معرّف مشارك بعد — أكمل الإعداد الأولي لمشاركة السجلات';

  @override
  String get httpLogsFilterHint => 'تصفية حسب عنوان URL';

  @override
  String get httpLogsNoMatches => 'لا توجد طلبات تطابق عامل التصفية.';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$count من $total';
  }

  @override
  String get widgetInstructionsTitle => 'أضف أداة Homeroom';

  @override
  String widgetInstructionsBody(String name) {
    return 'أُضيف $name إلى أداة dApps الخاصة بـ Homeroom. لعرضها على الشاشة الرئيسية، أضف الأداة مرة واحدة:';
  }

  @override
  String get widgetInstructionsStep1 =>
      'المس مساحة فارغة في الشاشة الرئيسية مع الاستمرار';

  @override
  String get widgetInstructionsStep2 =>
      'اضغط على «تعديل» في الزاوية العلوية ثم «إضافة أداة»';

  @override
  String get widgetInstructionsStep3 => 'ابحث عن Homeroom وأضف أداة dApps';

  @override
  String get widgetInstructionsDone => 'تم';

  @override
  String get svShellConnectingTitle => 'جارٍ الاتصال بـ Homeroom…';

  @override
  String get svShellOfflineMessage =>
      'تعذّر الوصول إلى Homeroom. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get stakingManagerTitle => 'وضع الستيكينغ';

  @override
  String get stakingDelegateIntro =>
      'فوّض حصتك (stake) إلى الخادم. تستمر عقدتك في العمل، لكن الخادم يقوم بالستيكينغ نيابةً عنك.';

  @override
  String get stakingServerName => 'الخادم';

  @override
  String get stakingDelegateEffect =>
      'تتوقف عقدتك عن إنتاج الكتل. أثناء التفويض تحصل على نصف نقاط إنتاج الكتل التي كنت ستكسبها بإنتاج الكتل مباشرةً على هذا الهاتف.';

  @override
  String get stakingDelegateNote =>
      'يمكنك العودة إلى الستيكينغ بنفسك في أي وقت.';

  @override
  String get stakingDelegateConfirm => 'تأكيد التفويض';

  @override
  String get stakingDelegating => 'جارٍ التفويض…';

  @override
  String get stakingDelegateError =>
      'تعذّر إرسال التفويض. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get stakingDelegationActiveTitle => 'التفويض نشط';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'حصتك مفوَّضة إلى $validator. تحصل على نصف نقاط إنتاج الكتل التي كنت ستكسبها بإنتاج الكتل مباشرةً على هذا الهاتف.';
  }

  @override
  String get stakingDone => 'تم';

  @override
  String get stakingUndelegateTitle => 'إيقاف التفويض؟';

  @override
  String get stakingUndelegateBody =>
      'تعود حصتك إلى هذا الهاتف. ستنتج عقدتك الكتل مباشرةً وتكسب كامل نقاط إنتاج الكتل.';

  @override
  String get stakingUndelegateConfirm => 'إيقاف التفويض';

  @override
  String get stakingUndelegateError =>
      'تعذّر إيقاف التفويض. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get versionUpdateRequiredTitle => 'التحديث مطلوب';

  @override
  String get versionUpdateAvailableTitle => 'يتوفر تحديث';

  @override
  String get versionUpdateAction => 'تحديث';

  @override
  String get versionUpdateLater => 'لاحقًا';

  @override
  String get versionUpdateFallbackMessage => 'يتوفر إصدار جديد من التطبيق.';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonDeny => 'رفض';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get commonApprove => 'موافقة';

  @override
  String get txConfirmTitle => 'تأكيد المعاملة';

  @override
  String get txConfirmSubtitleDefault => 'يطلب تطبيق dapp إرسال معاملة.';

  @override
  String get txAmount => 'المبلغ';

  @override
  String get txDetails => 'التفاصيل';

  @override
  String get txFrom => 'من';

  @override
  String get txTo => 'إلى';

  @override
  String get txFee => 'الرسوم';

  @override
  String get txMemo => 'المذكرة';

  @override
  String get verifyIdentityTitle => 'التحقق من الهوية';

  @override
  String verifyIdentityRequest(String name) {
    return 'يطلب $name التحقق من هويتك';
  }

  @override
  String get verifyIdentityExplanation =>
      'سيوقّع هذا تحدّيًا بمفتاحك الخاص لإثبات أنك صاحب هذه المحفظة. لن تُرسَل أي معاملة ولن يُنفَق أي رمز.';

  @override
  String get zkChallengeBusy =>
      'لا يزال إثبات zkPassport قيد المعالجة. حاول مرة أخرى بعد قليل.';

  @override
  String get zkChallengeResetDone => 'أُعيد ضبط حالة إثبات ZK';

  @override
  String provingParametersDownloadProgress(int percent) {
    return 'جارٍ تجهيز أدوات الإثبات: $percent٪. تُحفظ الملفات التي يتم تنزيلها لاستخدامها لاحقًا.';
  }

  @override
  String get provingParametersDownloadFailed =>
      'تعذّر تنزيل أدوات الإثبات. تحقّق من اتصالك وحاول مرة أخرى.';
}
