// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline => 'AI से ऐप बनाना,\nअब मल्टीप्लेयर में।';

  @override
  String get initializingNode => 'शुरू हो रहा है…';

  @override
  String get resumeSplashLoading => 'लोड हो रहा है…';

  @override
  String get clockDriftWarningTitle => 'सिस्टम का समय गलत है';

  @override
  String clockDriftWarningBody(String drift) {
    return 'आपके डिवाइस की घड़ी नोड की घड़ी से $drift अलग है। जब तक सिस्टम का समय ठीक नहीं होता, ऐप में कुछ गड़बड़ियाँ दिख सकती हैं।';
  }

  @override
  String get clockDriftWarningInstruction =>
      'अपने डिवाइस पर ऑटोमैटिक टाइम सिंक चालू करें।';

  @override
  String get clockDriftRecommendationTitle => 'सुझाव';

  @override
  String get clockDriftRecommendationBody =>
      'अंतर को कम से कम रखने के लिए सेटिंग में \"ऑटोमैटिक तारीख़ और समय\" और \"ऑटोमैटिक टाइम ज़ोन\" चालू रखें, ताकि डिवाइस नेटवर्क से समय ले।';

  @override
  String get clockDriftDismiss => 'ठीक है';

  @override
  String clockDriftAhead(String seconds) {
    return '$seconds सेकंड आगे';
  }

  @override
  String clockDriftBehind(String seconds) {
    return '$seconds सेकंड पीछे';
  }

  @override
  String get settingsAbout => 'जानकारी';

  @override
  String get settingsBuildInfo => 'बिल्ड की जानकारी';

  @override
  String get settingsDiagnostics => 'डायग्नोस्टिक्स';

  @override
  String get settingsDeviceBenchmark => 'डिवाइस बेंचमार्क';

  @override
  String get settingsDeviceBenchmarkSubtitle =>
      'डिवाइस पर परफ़ॉर्मेंस की माप चलाएँ';

  @override
  String get perfTitle => 'डिवाइस बेंचमार्क';

  @override
  String get perfIntroTitle => 'इस डिवाइस पर बेंचमार्क चलाएँ';

  @override
  String get perfIntroDescription =>
      'हैशिंग, आंशिक सिंक, ब्लॉक प्रोडक्शन और वॉलेट से भेजने के काम नापें, ताकि पता चले कि यह डिवाइस कैसा चलता है।';

  @override
  String get perfIntroNote =>
      'फ़िलहाल नतीजे इसी डिवाइस पर रहते हैं। बैटरी, तापमान और बैकग्राउंड गतिविधि के हिसाब से परफ़ॉर्मेंस बदल सकती है।';

  @override
  String get perfCatalogLoadError => 'बेंचमार्क सूची लोड नहीं हो सकी।';

  @override
  String get perfCatalogLoading => 'बेंचमार्क सूची लोड हो रही है…';

  @override
  String get perfProfileQuick => 'क्विक चेक';

  @override
  String get perfProfileStandard => 'पूरा बेंचमार्क';

  @override
  String perfRunProfile(String profile) {
    return 'चलाएँ: $profile';
  }

  @override
  String perfStepCount(int count) {
    return '$count चरण';
  }

  @override
  String get perfCurrentRunTitle => 'मौजूदा रन';

  @override
  String get perfRunInProgressTitle => 'बेंचमार्क चल रहा है';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'इस डिवाइस पर $profile बेंचमार्क पहले से चल रहा है।';
  }

  @override
  String get perfRunInProgressDescriptionUnknown =>
      'इस डिवाइस पर एक बेंचमार्क पहले से चल रहा है।';

  @override
  String get perfOpenCurrentRun => 'मौजूदा रन खोलें';

  @override
  String get perfLatestResultsTitle => 'ताज़ा नतीजे';

  @override
  String perfLatestResultsDescription(String profile) {
    return '$profile के नतीजे देखने के लिए तैयार हैं।';
  }

  @override
  String get perfLatestResultsDescriptionUnknown =>
      'बेंचमार्क के नतीजे देखने के लिए तैयार हैं।';

  @override
  String get perfViewLatestResults => 'ताज़ा नतीजे देखें';

  @override
  String get perfNoRunAvailableTitle => 'कोई बेंचमार्क रन नहीं';

  @override
  String get perfNoRunAvailableDescription =>
      'प्रगति या नतीजे यहाँ देखने के लिए बेंचमार्क स्क्रीन से बेंचमार्क शुरू करें।';

  @override
  String get perfBackToBenchmarks => 'बेंचमार्क पर वापस जाएँ';

  @override
  String get perfRunPausedNodeNotice =>
      'यह बेंचमार्क चलने तक बैकग्राउंड नोड रुका रहेगा।';

  @override
  String get perfStateRunning => 'चल रहा है';

  @override
  String get perfStateStarting => 'शुरू हो रहा है';

  @override
  String get perfStateCompleted => 'पूरा हुआ';

  @override
  String get perfStateFailed => 'विफल';

  @override
  String get perfStateCancelled => 'रद्द किया गया';

  @override
  String perfProgressValue(int completed, int total) {
    return '$total में से $completed चरण';
  }

  @override
  String perfPreparingProfile(String profile) {
    return 'तैयारी: $profile';
  }

  @override
  String perfCurrentStep(String label) {
    return 'मौजूदा चरण: $label';
  }

  @override
  String perfElapsed(String duration) {
    return 'बीता समय: $duration';
  }

  @override
  String get perfResultsTitle => 'नतीजे';

  @override
  String get perfResultProfile => 'प्रोफ़ाइल';

  @override
  String get perfResultDevice => 'डिवाइस';

  @override
  String get perfResultOperatingSystem => 'ओएस';

  @override
  String get perfResultCpu => 'CPU';

  @override
  String get perfResultLogicalCores => 'लॉजिकल कोर';

  @override
  String get perfResultMeasurements => 'माप';

  @override
  String get perfSuitePrimitives => 'प्रिमिटिव';

  @override
  String get perfSuitePartialSync => 'आंशिक सिंक';

  @override
  String get perfSuitePartialBlockProduction => 'ब्लॉक प्रोडक्शन';

  @override
  String get perfSuiteWalletSend => 'वॉलेट से भेजना';

  @override
  String get perfScenarioDefault => 'डिफ़ॉल्ट केस';

  @override
  String perfContextTxCount(int count) {
    return '$count लेन-देन';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'लेआउट $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return 'आकार $value';
  }

  @override
  String get perfDetailScenario => 'परिदृश्य';

  @override
  String get perfDetailAverage => 'औसत';

  @override
  String get perfDetailMinMax => 'न्यूनतम / अधिकतम';

  @override
  String get perfDetailRuns => 'रन';

  @override
  String get perfDetailMetadataTitle => 'परिदृश्य का ब्योरा';

  @override
  String get perfDetailImplementationTitle => 'इम्प्लीमेंटेशन का ब्योरा';

  @override
  String get perfDetailNotesTitle => 'टिप्पणियाँ';

  @override
  String get perfDetailFlow => 'फ़्लो';

  @override
  String get perfDetailTxCount => 'लेन-देन की संख्या';

  @override
  String get perfDetailBatchLayout => 'बैच लेआउट';

  @override
  String get perfDetailTransactionShape => 'लेन-देन का आकार';

  @override
  String get perfDetailTouchedLeaves => 'छुए गए लीफ़';

  @override
  String get perfDetailProofNodes => 'प्रूफ़ नोड';

  @override
  String get perfDetailProofSize => 'प्रूफ़ का आकार';

  @override
  String get perfCancelFailed => 'चल रहा बेंचमार्क रद्द नहीं हो सका।';

  @override
  String get perfRunUnavailable => 'यह बेंचमार्क रन अब उपलब्ध नहीं है।';

  @override
  String get commonOk => 'ठीक है';

  @override
  String get buildInfoVersion => 'वर्शन';

  @override
  String get buildInfoCommit => 'कमिट';

  @override
  String get buildInfoBranch => 'ब्रांच';

  @override
  String get buildInfoCommitTime => 'कमिट का समय';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Cargo टारगेट';

  @override
  String get buildInfoFeatures => 'फ़ीचर';

  @override
  String get buildInfoOptLevel => 'ऑप्टिमाइज़ेशन स्तर';

  @override
  String get buildInfoDebug => 'डीबग';

  @override
  String get retry => 'फिर कोशिश करें';

  @override
  String get zkIdentityAppNotFoundTitle => 'पहले ZK Passport इंस्टॉल करें';

  @override
  String get zkIdentityAppNotFoundDetail =>
      'यह आपका प्रूफ़ बनाता है, फिर आपको यहीं वापस भेज देता है';

  @override
  String get zkIdentityInstallCta => 'इंस्टॉल करें';

  @override
  String get zkIdentityStepLabelOpenApp => 'ZK Passport खुल रहा है';

  @override
  String get zkIdentityStepDescOpenApp =>
      'आपके सेव किए पासपोर्ट से प्रूफ़ का अनुरोध तैयार हो रहा है';

  @override
  String get zkIdentityCheckAppCta => 'जारी रखें';

  @override
  String get zkIdentityAccountPreparingTitle => 'आपका खाता तैयार हो रहा है';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'आपका साइन-इन किया हुआ Social Vibecoding खाता जोड़ा जा रहा है';

  @override
  String get zkIdentityAccountUnavailable =>
      'वेरिफ़िकेशन शुरू करने से पहले Social Vibecoding में साइन इन करें।';

  @override
  String get zkIdentityStepLabelScan => 'सेव किया पासपोर्ट इस्तेमाल करें';

  @override
  String get zkIdentityStepDescScan =>
      'ZK Passport में पहले से रखा पासपोर्ट इस्तेमाल होगा';

  @override
  String get zkIdentityConfirmScannedBody =>
      'आपका सेव किया हुआ पासपोर्ट इस्तेमाल होगा।';

  @override
  String get zkIdentityConfirmScannedYesCta => 'जारी रखें';

  @override
  String get zkIdentityConfirmScannedNoCta => 'अभी नहीं';

  @override
  String get zkIdentityStepLabelReady => 'प्रूफ़ बनाएँ';

  @override
  String get zkIdentityStepDescReady =>
      'ZK Passport आपसे मंज़ूरी माँगेगा और प्रूफ़ बनाएगा';

  @override
  String get zkIdentityReadyBody =>
      'ZK Passport आपके सेव किए पासपोर्ट से लगभग एक मिनट में प्रूफ़ बना देता है।';

  @override
  String get zkIdentityReadyBullet1 => 'कोई नाम, फ़ोटो या आईडी साझा नहीं होती';

  @override
  String get zkIdentityReadyBullet2 => 'आप सिर्फ़ एक प्रूफ़ भेजते हैं';

  @override
  String get zkIdentityReadyBullet3 =>
      'ऑन-चेन कुछ भी निजी जानकारी नहीं रखी जाती';

  @override
  String get zkIdentityReadyCta => 'ZK Passport खोलें';

  @override
  String get zkIdentityStepLabelVerifying => 'वेरिफ़ाई हो रहा है';

  @override
  String get zkIdentityStepDescVerifying =>
      'आपका प्रूफ़ बनाया और जाँचा जा रहा है';

  @override
  String get zkIdentityStepLabelResult => 'नतीजा';

  @override
  String get zkIdentityStepDescResult => 'अपने वेरिफ़िकेशन का नतीजा देखें';

  @override
  String get zkIdentitySubTaskOpening => 'ZK Passport खुल रहा है';

  @override
  String get zkIdentitySubTaskWaiting => 'आपके प्रूफ़ का इंतज़ार है';

  @override
  String get zkIdentitySubTaskChecking => 'आपका प्रूफ़ जाँचा जा रहा है';

  @override
  String get zkIdentitySubTaskWrapping => 'आपका प्रूफ़ पैक किया जा रहा है';

  @override
  String get zkIdentitySubTaskFinal => 'आख़िरी जाँच';

  @override
  String get zkIdentityResultSuccessTitle => 'आप एक अनोखे इंसान हैं!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      'आपने नाम, फ़ोटो या आईडी साझा किए बिना साबित किया कि आप अनोखे हैं';

  @override
  String get zkIdentityStatusUniqueness => 'अनोखा इंसान';

  @override
  String get zkIdentityStatusUniquenessValue => 'पुष्टि हुई';

  @override
  String get zkIdentityStatusFaceMatchLabel => 'चेहरे की जाँच';

  @override
  String get zkIdentityStatusPrivacyValue => 'कुछ भी साझा नहीं हुआ';

  @override
  String get zkIdentityCancelVerification => 'रद्द करें';

  @override
  String get zkIdentityGoToZkPassport => 'ZK Passport पर जाएँ';

  @override
  String get zkIdentityTryAgain => 'फिर कोशिश करें';

  @override
  String get zkIdentityWalletClaimTitle => 'अपना प्रोग्राम वॉलेट जोड़ें';

  @override
  String get zkIdentityWalletClaimDescription =>
      'यह Social खाता उस खाते से अलग है जिसमें आपका मौजूदा वॉलेट है। इसे जोड़ने के लिए अपने मूल प्रोग्राम का ईमेल एक बार वेरिफ़ाई करें।';

  @override
  String get zkIdentityWalletClaimEmailLabel => 'मूल प्रोग्राम का ईमेल';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      'अपने मूल Homeroom प्रोग्राम रजिस्ट्रेशन वाला ईमेल इस्तेमाल करें।';

  @override
  String get zkIdentityWalletClaimSendCode => 'वेरिफ़िकेशन कोड भेजें';

  @override
  String get zkIdentityWalletClaimSendingCode => 'कोड भेजा जा रहा है…';

  @override
  String get zkIdentityWalletClaimCodeSent =>
      'उस ईमेल पर भेजा गया 6 अंकों का कोड डालें।';

  @override
  String get zkIdentityWalletClaimCodeLabel => 'वेरिफ़िकेशन कोड';

  @override
  String get zkIdentityWalletClaimConnect => 'वॉलेट जोड़ें और आगे बढ़ें';

  @override
  String get zkIdentityWalletClaimConnecting => 'वॉलेट जोड़ा जा रहा है…';

  @override
  String get zkIdentityWalletClaimChangeEmail => 'दूसरा ईमेल इस्तेमाल करें';

  @override
  String get zkIdentityWalletClaimEmailRequired => 'सही ईमेल पता डालें।';

  @override
  String get zkIdentityWalletClaimCodeRequired => '6 अंकों का कोड डालें।';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'आपका वॉलेट जुड़ गया, लेकिन ऐप उसे पूरी तरह तैयार नहीं कर सका। फिर कोशिश करें।';

  @override
  String get zkIdentityDone => 'हो गया';

  @override
  String get zkIdentityStatusFaceMatchVerified => 'वेरिफ़ाई हुआ';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'छोड़ा गया';

  @override
  String get zkIdentityStatusPrivacyLabel => 'निजता';

  @override
  String get zkIdentityStatusVerifiedDateLabel => 'वेरिफ़ाई की तारीख़';

  @override
  String get zkIdentityStatusProofIdLabel => 'प्रूफ़ आईडी';

  @override
  String get zkIdentityStatusVerifyDurationLabel => 'वेरिफ़िकेशन';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'पैकिंग';

  @override
  String get zkIdentityStatusFinalCheckLabel => 'आख़िरी जाँच';

  @override
  String get zkIdentityResultFailureTitle => 'वेरिफ़ाई नहीं हो सका';

  @override
  String get zkIdentityResultFailureSubtitle =>
      'आपने अपना नाम, फ़ोटो या आईडी साझा नहीं की';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonRetry => 'फिर कोशिश करें';

  @override
  String get commonCopied => 'कॉपी हो गया';

  @override
  String get buildInfoAppVersion => 'ऐप वर्शन';

  @override
  String get buildInfoBuildNumber => 'बिल्ड नंबर';

  @override
  String get settingsDebugMode => 'डीबग मोड';

  @override
  String get settingsDebugModeEnabled =>
      'HTTP अनुरोध मेमोरी में सेव हो रहे हैं';

  @override
  String get settingsDebugModeDisabled => 'बंद · नेटवर्क लॉगिंग नहीं';

  @override
  String get settingsHttpLogs => 'HTTP लॉग';

  @override
  String get settingsHttpLogsSubtitle => 'सेव किए गए नेटवर्क अनुरोध देखें';

  @override
  String get httpLogsTitle => 'HTTP लॉग';

  @override
  String get httpLogsEmpty =>
      'अभी तक कोई अनुरोध सेव नहीं हुआ। लॉग यहाँ देखने के लिए कुछ नेटवर्क गतिविधि करें।';

  @override
  String get httpLogsCopy => 'सब कॉपी करें';

  @override
  String get httpLogsClear => 'साफ़ करें';

  @override
  String get httpLogsCopied => 'लॉग क्लिपबोर्ड पर कॉपी हो गए';

  @override
  String get httpLogsShare => 'लॉग टीम के साथ साझा करें';

  @override
  String get httpLogsSharing =>
      'हर 30 सेकंड में लॉग टीम के साथ साझा हो रहे हैं…';

  @override
  String get httpLogsStopSharing => 'साझा करना बंद करें';

  @override
  String get httpLogsShareStopped =>
      'सर्वर ने लॉग साझा करना बंद कर दिया। आप कभी भी दोबारा साझा कर सकते हैं।';

  @override
  String get httpLogsShareNoParticipant =>
      'अभी कोई प्रतिभागी आईडी नहीं है — लॉग साझा करने के लिए ऑनबोर्डिंग पूरी करें';

  @override
  String get httpLogsFilterHint => 'URL से फ़िल्टर करें';

  @override
  String get httpLogsNoMatches => 'फ़िल्टर से कोई अनुरोध मेल नहीं खाता।';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$total में से $count';
  }

  @override
  String get widgetInstructionsTitle => 'Homeroom विजेट जोड़ें';

  @override
  String widgetInstructionsBody(String name) {
    return '$name आपके Homeroom dApps विजेट में जोड़ दिया गया है। इसे होम स्क्रीन पर देखने के लिए विजेट एक बार जोड़ें:';
  }

  @override
  String get widgetInstructionsStep1 =>
      'होम स्क्रीन के किसी खाली हिस्से को दबाकर रखें';

  @override
  String get widgetInstructionsStep2 =>
      'ऊपर कोने में बदलाव करें पर टैप करें, फिर विजेट जोड़ें';

  @override
  String get widgetInstructionsStep3 => 'Homeroom खोजें और dApps विजेट जोड़ें';

  @override
  String get widgetInstructionsDone => 'हो गया';

  @override
  String get svShellConnectingTitle => 'Homeroom से जुड़ रहे हैं…';

  @override
  String get svShellOfflineMessage =>
      'Homeroom तक नहीं पहुँच पा रहे। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get stakingManagerTitle => 'स्टेकिंग मोड';

  @override
  String get stakingDelegateIntro =>
      'अपना स्टेक सर्वर को सौंपें। आपका नोड चलता रहेगा, लेकिन सर्वर आपकी ओर से स्टेकिंग करेगा।';

  @override
  String get stakingServerName => 'सर्वर';

  @override
  String get stakingDelegateEffect =>
      'आपका नोड ब्लॉक बनाना बंद कर देगा। सौंपे जाने के दौरान, आपको उतने ब्लॉक-प्रोडक्शन पॉइंट का आधा मिलेगा जितना इसी फ़ोन पर सीधे ब्लॉक बनाकर मिलता।';

  @override
  String get stakingDelegateNote => 'आप कभी भी ख़ुद स्टेकिंग पर लौट सकते हैं।';

  @override
  String get stakingDelegateConfirm => 'डेलिगेशन की पुष्टि करें';

  @override
  String get stakingDelegating => 'डेलिगेट हो रहा है…';

  @override
  String get stakingDelegateError =>
      'डेलिगेशन भेजा नहीं जा सका। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get stakingDelegationActiveTitle => 'डेलिगेशन चालू है';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'आपका स्टेक $validator को सौंपा गया है। आपको उतने ब्लॉक-प्रोडक्शन पॉइंट का आधा मिलता है जितना इसी फ़ोन पर सीधे ब्लॉक बनाकर मिलता।';
  }

  @override
  String get stakingDone => 'हो गया';

  @override
  String get stakingUndelegateTitle => 'डेलिगेशन बंद करें?';

  @override
  String get stakingUndelegateBody =>
      'आपका स्टेक इस फ़ोन पर लौट आएगा। आपका नोड सीधे ब्लॉक बनाएगा और पूरे ब्लॉक-प्रोडक्शन पॉइंट कमाएगा।';

  @override
  String get stakingUndelegateConfirm => 'डेलिगेशन बंद करें';

  @override
  String get stakingUndelegateError =>
      'डेलिगेशन बंद नहीं हो सका। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get versionUpdateRequiredTitle => 'अपडेट ज़रूरी है';

  @override
  String get versionUpdateAvailableTitle => 'अपडेट उपलब्ध है';

  @override
  String get versionUpdateAction => 'अपडेट करें';

  @override
  String get versionUpdateLater => 'बाद में';

  @override
  String get versionUpdateFallbackMessage => 'ऐप का नया वर्शन उपलब्ध है।';

  @override
  String get commonBack => 'वापस';

  @override
  String get commonDeny => 'अस्वीकार करें';

  @override
  String get commonConfirm => 'पुष्टि करें';

  @override
  String get commonApprove => 'मंज़ूर करें';

  @override
  String get txConfirmTitle => 'लेन-देन की पुष्टि करें';

  @override
  String get txConfirmSubtitleDefault =>
      'एक dapp लेन-देन भेजने का अनुरोध कर रहा है।';

  @override
  String get txAmount => 'राशि';

  @override
  String get txDetails => 'ब्योरा';

  @override
  String get txFrom => 'भेजने वाला';

  @override
  String get txTo => 'पाने वाला';

  @override
  String get txFee => 'शुल्क';

  @override
  String get txMemo => 'मेमो';

  @override
  String get verifyIdentityTitle => 'पहचान सत्यापित करें';

  @override
  String verifyIdentityRequest(String name) {
    return '$name आपकी पहचान सत्यापित करने का अनुरोध कर रहा है';
  }

  @override
  String get verifyIdentityExplanation =>
      'यह साबित करने के लिए कि यह वॉलेट आपका है, यह आपकी प्राइवेट की से एक चैलेंज साइन करेगा। कोई लेन-देन नहीं भेजा जाएगा और कोई टोकन ख़र्च नहीं होगा।';

  @override
  String get zkChallengeBusy =>
      'zkPassport का एक प्रूफ़ अभी प्रोसेस हो रहा है। थोड़ी देर बाद फिर कोशिश करें।';

  @override
  String get zkChallengeResetDone => 'ZK प्रूफ़ की स्थिति रीसेट हो गई';
}
