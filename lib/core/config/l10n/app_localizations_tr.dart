// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline =>
      'Yapay Zekâyla Uygulama Geliştirme,\nArtık Çok Oyunculu.';

  @override
  String get initializingNode => 'Başlatılıyor…';

  @override
  String get resumeSplashLoading => 'Yükleniyor…';

  @override
  String get clockDriftWarningTitle => 'Sistem saati yanlış';

  @override
  String clockDriftWarningBody(String drift) {
    return 'Cihazınızın saati düğüm saatinden $drift farklı. Sistem saatiniz düzeltilene kadar uygulamada bazı tutarsızlıklar görebilirsiniz.';
  }

  @override
  String get clockDriftWarningInstruction =>
      'Cihazınızda otomatik saat eşitlemeyi açın.';

  @override
  String get clockDriftRecommendationTitle => 'Öneri';

  @override
  String get clockDriftRecommendationBody =>
      'Sapmayı en aza indirmek için ayarlarda \"Otomatik tarih ve saat\" ile \"Otomatik saat dilimi\" seçeneklerini açık tutun; böylece cihaz ağ saatini sorgular.';

  @override
  String get clockDriftDismiss => 'Tamam';

  @override
  String clockDriftAhead(String seconds) {
    return '$seconds sn ileride';
  }

  @override
  String clockDriftBehind(String seconds) {
    return '$seconds sn geride';
  }

  @override
  String get settingsAbout => 'Hakkında';

  @override
  String get settingsBuildInfo => 'Derleme Bilgisi';

  @override
  String get settingsDiagnostics => 'Tanılama';

  @override
  String get settingsDeviceBenchmark => 'Cihaz Performans Testi';

  @override
  String get settingsDeviceBenchmarkSubtitle =>
      'Cihaz üzerinde performans ölçümleri çalıştır';

  @override
  String get perfTitle => 'Cihaz Performans Testi';

  @override
  String get perfIntroTitle => 'Bu cihazda performans testi çalıştırın';

  @override
  String get perfIntroDescription =>
      'Bu cihazın nasıl performans gösterdiğini görmek için karma, kısmi senkronizasyon, blok üretimi ve cüzdan gönderimi iş yüklerini ölçün.';

  @override
  String get perfIntroNote =>
      'Şimdilik sonuçlar bu cihazda kalır. Performans; pil seviyesine, ısıya ve arka plan etkinliğine göre değişebilir.';

  @override
  String get perfCatalogLoadError => 'Test kataloğu yüklenemedi.';

  @override
  String get perfCatalogLoading => 'Test kataloğu yükleniyor…';

  @override
  String get perfProfileQuick => 'Hızlı Kontrol';

  @override
  String get perfProfileStandard => 'Tam Test';

  @override
  String perfRunProfile(String profile) {
    return 'Çalıştır: $profile';
  }

  @override
  String perfStepCount(int count) {
    return '$count adım';
  }

  @override
  String get perfCurrentRunTitle => 'Mevcut Çalıştırma';

  @override
  String get perfRunInProgressTitle => 'Test Sürüyor';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'Bu cihazda zaten bir $profile testi çalışıyor.';
  }

  @override
  String get perfRunInProgressDescriptionUnknown =>
      'Bu cihazda zaten bir test çalışıyor.';

  @override
  String get perfOpenCurrentRun => 'Mevcut Çalıştırmayı Aç';

  @override
  String get perfLatestResultsTitle => 'Son Sonuçlar';

  @override
  String perfLatestResultsDescription(String profile) {
    return '$profile sonuçları incelemeye hazır.';
  }

  @override
  String get perfLatestResultsDescriptionUnknown =>
      'Test sonuçları incelemeye hazır.';

  @override
  String get perfViewLatestResults => 'Son Sonuçları Gör';

  @override
  String get perfNoRunAvailableTitle => 'Test Yok';

  @override
  String get perfNoRunAvailableDescription =>
      'İlerlemeyi veya sonuçları burada görmek için test ekranından bir test başlatın.';

  @override
  String get perfBackToBenchmarks => 'Testlere Dön';

  @override
  String get perfRunPausedNodeNotice =>
      'Bu test çalışırken arka plandaki düğüm duraklatılır.';

  @override
  String get perfStateRunning => 'Çalışıyor';

  @override
  String get perfStateStarting => 'Başlıyor';

  @override
  String get perfStateCompleted => 'Tamamlandı';

  @override
  String get perfStateFailed => 'Başarısız';

  @override
  String get perfStateCancelled => 'İptal edildi';

  @override
  String perfProgressValue(int completed, int total) {
    return '$completed / $total adım';
  }

  @override
  String perfPreparingProfile(String profile) {
    return 'Hazırlanıyor: $profile';
  }

  @override
  String perfCurrentStep(String label) {
    return 'Geçerli adım: $label';
  }

  @override
  String perfElapsed(String duration) {
    return 'Geçen süre: $duration';
  }

  @override
  String get perfResultsTitle => 'Sonuçlar';

  @override
  String get perfResultProfile => 'Profil';

  @override
  String get perfResultDevice => 'Cihaz';

  @override
  String get perfResultOperatingSystem => 'İS';

  @override
  String get perfResultCpu => 'CPU';

  @override
  String get perfResultLogicalCores => 'Mantıksal Çekirdekler';

  @override
  String get perfResultMeasurements => 'Ölçümler';

  @override
  String get perfSuitePrimitives => 'Temel İşlemler';

  @override
  String get perfSuitePartialSync => 'Kısmi Senkronizasyon';

  @override
  String get perfSuitePartialBlockProduction => 'Blok Üretimi';

  @override
  String get perfSuiteWalletSend => 'Cüzdan Gönderimi';

  @override
  String get perfScenarioDefault => 'Varsayılan durum';

  @override
  String perfContextTxCount(int count) {
    return '$count işlem';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'Yerleşim $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return 'Biçim $value';
  }

  @override
  String get perfDetailScenario => 'Senaryo';

  @override
  String get perfDetailAverage => 'Ortalama';

  @override
  String get perfDetailMinMax => 'Min / Maks';

  @override
  String get perfDetailRuns => 'Çalıştırmalar';

  @override
  String get perfDetailMetadataTitle => 'Senaryo Ayrıntıları';

  @override
  String get perfDetailImplementationTitle => 'Uygulama Ayrıntıları';

  @override
  String get perfDetailNotesTitle => 'Notlar';

  @override
  String get perfDetailFlow => 'Akış';

  @override
  String get perfDetailTxCount => 'İşlem Sayısı';

  @override
  String get perfDetailBatchLayout => 'Toplu İş Yerleşimi';

  @override
  String get perfDetailTransactionShape => 'İşlem Biçimi';

  @override
  String get perfDetailTouchedLeaves => 'Erişilen Yapraklar';

  @override
  String get perfDetailProofNodes => 'Kanıt Düğümleri';

  @override
  String get perfDetailProofSize => 'Kanıt Boyutu';

  @override
  String get perfCancelFailed => 'Çalışan test iptal edilemedi.';

  @override
  String get perfRunUnavailable => 'Bu test artık kullanılamıyor.';

  @override
  String get commonOk => 'Tamam';

  @override
  String get buildInfoVersion => 'Sürüm';

  @override
  String get buildInfoCommit => 'Commit';

  @override
  String get buildInfoBranch => 'Dal';

  @override
  String get buildInfoCommitTime => 'Commit zamanı';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Cargo hedefi';

  @override
  String get buildInfoFeatures => 'Özellikler';

  @override
  String get buildInfoOptLevel => 'Optimizasyon düzeyi';

  @override
  String get buildInfoDebug => 'Debug';

  @override
  String get retry => 'Yeniden dene';

  @override
  String get zkIdentityAppNotFoundTitle => 'Önce ZK Passport\'u yükleyin';

  @override
  String get zkIdentityAppNotFoundDetail =>
      'Kanıtınızı oluşturur, sonra sizi buraya geri getirir';

  @override
  String get zkIdentityInstallCta => 'Yükle';

  @override
  String get zkIdentityStepLabelOpenApp => 'ZK Passport açılıyor';

  @override
  String get zkIdentityStepDescOpenApp =>
      'Kayıtlı pasaportunuzla bir kanıt isteği hazırlanıyor';

  @override
  String get zkIdentityCheckAppCta => 'Devam';

  @override
  String get zkIdentityAccountPreparingTitle => 'Hesabınız hazırlanıyor';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'Oturum açık Social Vibecoding hesabınız bağlanıyor';

  @override
  String get zkIdentityAccountUnavailable =>
      'Doğrulamaya başlamadan önce Social Vibecoding\'de oturum açın.';

  @override
  String get zkIdentityStepLabelScan => 'Kayıtlı pasaportu kullan';

  @override
  String get zkIdentityStepDescScan =>
      'ZK Passport\'ta zaten kayıtlı olan pasaportu kullanır';

  @override
  String get zkIdentityConfirmScannedBody =>
      'Kayıtlı pasaportunuz kullanılacak.';

  @override
  String get zkIdentityConfirmScannedYesCta => 'Devam';

  @override
  String get zkIdentityConfirmScannedNoCta => 'Şimdi değil';

  @override
  String get zkIdentityStepLabelReady => 'Kanıt oluştur';

  @override
  String get zkIdentityStepDescReady =>
      'ZK Passport, kanıtı onaylamanızı ve oluşturmanızı isteyecek';

  @override
  String get zkIdentityReadyBody =>
      'ZK Passport, kanıtı kayıtlı pasaportunuzdan yaklaşık bir dakikada oluşturur.';

  @override
  String get zkIdentityReadyBullet1 => 'Ad, fotoğraf veya kimlik paylaşılmaz';

  @override
  String get zkIdentityReadyBullet2 => 'Yalnızca bir kanıt gönderirsiniz';

  @override
  String get zkIdentityReadyBullet3 => 'Zincirde kişisel hiçbir şey saklanmaz';

  @override
  String get zkIdentityReadyCta => 'ZK Passport\'u aç';

  @override
  String get zkIdentityStepLabelVerifying => 'Doğrulanıyor';

  @override
  String get zkIdentityStepDescVerifying =>
      'Kanıtınız oluşturuluyor ve kontrol ediliyor';

  @override
  String get zkIdentityStepLabelResult => 'Sonuç';

  @override
  String get zkIdentityStepDescResult => 'Doğrulamanızın sonucunu görün';

  @override
  String get zkIdentitySubTaskOpening => 'ZK Passport açılıyor';

  @override
  String get zkIdentitySubTaskWaiting => 'Kanıtınız bekleniyor';

  @override
  String get zkIdentitySubTaskChecking => 'Kanıtınız kontrol ediliyor';

  @override
  String get zkIdentitySubTaskWrapping => 'Kanıtınız paketleniyor';

  @override
  String get zkIdentitySubTaskFinal => 'Son kontrol';

  @override
  String get zkIdentityResultSuccessTitle => 'Eşsiz bir insansınız!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      'Adınızı, fotoğrafınızı veya kimliğinizi paylaşmadan eşsiz olduğunuzu kanıtladınız';

  @override
  String get zkIdentityStatusUniqueness => 'Eşsiz insan';

  @override
  String get zkIdentityStatusUniquenessValue => 'Onaylandı';

  @override
  String get zkIdentityStatusFaceMatchLabel => 'Yüz kontrolü';

  @override
  String get zkIdentityStatusPrivacyValue => 'Hiçbir şey paylaşılmadı';

  @override
  String get zkIdentityCancelVerification => 'İptal';

  @override
  String get zkIdentityGoToZkPassport => 'ZK Passport\'a geç';

  @override
  String get zkIdentityTryAgain => 'Tekrar dene';

  @override
  String get zkIdentityWalletClaimTitle => 'Program cüzdanınızı bağlayın';

  @override
  String get zkIdentityWalletClaimDescription =>
      'Bu Social hesabı, mevcut cüzdanınızı tutan hesaptan farklı. Bağlamak için özgün program e-postanızı bir kez doğrulayın.';

  @override
  String get zkIdentityWalletClaimEmailLabel => 'Özgün program e-postası';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      'Özgün Homeroom programı kaydınızdaki e-postayı kullanın.';

  @override
  String get zkIdentityWalletClaimSendCode => 'Doğrulama kodu gönder';

  @override
  String get zkIdentityWalletClaimSendingCode => 'Kod gönderiliyor…';

  @override
  String get zkIdentityWalletClaimCodeSent =>
      'Bu e-postaya gönderilen 6 haneli kodu girin.';

  @override
  String get zkIdentityWalletClaimCodeLabel => 'Doğrulama kodu';

  @override
  String get zkIdentityWalletClaimConnect => 'Cüzdanı bağla ve devam et';

  @override
  String get zkIdentityWalletClaimConnecting => 'Cüzdan bağlanıyor…';

  @override
  String get zkIdentityWalletClaimChangeEmail => 'Başka bir e-posta kullan';

  @override
  String get zkIdentityWalletClaimEmailRequired =>
      'Geçerli bir e-posta adresi girin.';

  @override
  String get zkIdentityWalletClaimCodeRequired => '6 haneli kodu girin.';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'Cüzdanınız bağlandı, ancak uygulama hazırlamayı tamamlayamadı. Tekrar deneyin.';

  @override
  String get zkIdentityDone => 'Bitti';

  @override
  String get zkIdentityStatusFaceMatchVerified => 'Doğrulandı';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'Atlandı';

  @override
  String get zkIdentityStatusPrivacyLabel => 'Gizlilik';

  @override
  String get zkIdentityStatusVerifiedDateLabel => 'Doğrulama tarihi';

  @override
  String get zkIdentityStatusProofIdLabel => 'Kanıt kimliği';

  @override
  String get zkIdentityStatusVerifyDurationLabel => 'Doğrulama';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'Paketleme';

  @override
  String get zkIdentityStatusFinalCheckLabel => 'Son kontrol';

  @override
  String get zkIdentityResultFailureTitle => 'Doğrulanamadı';

  @override
  String get zkIdentityResultFailureSubtitle =>
      'Adınızı, fotoğrafınızı veya kimliğinizi paylaşmadınız';

  @override
  String get commonCancel => 'İptal';

  @override
  String get commonRetry => 'Yeniden dene';

  @override
  String get commonCopied => 'Kopyalandı';

  @override
  String get buildInfoAppVersion => 'Uygulama Sürümü';

  @override
  String get buildInfoBuildNumber => 'Derleme Numarası';

  @override
  String get settingsDebugMode => 'Hata Ayıklama Modu';

  @override
  String get settingsDebugModeEnabled => 'HTTP istekleri belleğe kaydediliyor';

  @override
  String get settingsDebugModeDisabled => 'Kapalı · ağ günlüğü yok';

  @override
  String get settingsHttpLogs => 'HTTP Günlükleri';

  @override
  String get settingsHttpLogsSubtitle => 'Kaydedilen ağ isteklerini görüntüle';

  @override
  String get httpLogsTitle => 'HTTP Günlükleri';

  @override
  String get httpLogsEmpty =>
      'Henüz kaydedilmiş istek yok. Günlükleri burada görmek için biraz ağ etkinliği oluşturun.';

  @override
  String get httpLogsCopy => 'Tümünü kopyala';

  @override
  String get httpLogsClear => 'Temizle';

  @override
  String get httpLogsCopied => 'Günlükler panoya kopyalandı';

  @override
  String get httpLogsShare => 'Günlükleri ekiple paylaş';

  @override
  String get httpLogsSharing =>
      'Günlükler her 30 sn\'de bir ekiple paylaşılıyor…';

  @override
  String get httpLogsStopSharing => 'Paylaşımı durdur';

  @override
  String get httpLogsShareStopped =>
      'Sunucu günlük paylaşımını durdurdu. İstediğiniz zaman yeniden paylaşabilirsiniz.';

  @override
  String get httpLogsShareNoParticipant =>
      'Henüz katılımcı kimliği yok — günlük paylaşmak için tanışma adımlarını tamamlayın';

  @override
  String get httpLogsFilterHint => 'URL\'ye göre filtrele';

  @override
  String get httpLogsNoMatches => 'Filtreyle eşleşen istek yok.';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$count / $total';
  }

  @override
  String get widgetInstructionsTitle => 'Homeroom widget\'ını ekleyin';

  @override
  String widgetInstructionsBody(String name) {
    return '$name, Homeroom dApps widget\'ınıza eklendi. Ana ekranınızda görmek için widget\'ı bir kez ekleyin:';
  }

  @override
  String get widgetInstructionsStep1 =>
      'Ana ekranınızda boş bir alana dokunup basılı tutun';

  @override
  String get widgetInstructionsStep2 =>
      'Üst köşedeki Düzenle\'ye, ardından Widget Ekle\'ye dokunun';

  @override
  String get widgetInstructionsStep3 =>
      'Homeroom\'u arayın ve dApps widget\'ını ekleyin';

  @override
  String get widgetInstructionsDone => 'Bitti';

  @override
  String get svShellConnectingTitle => 'Homeroom\'a bağlanılıyor…';

  @override
  String get svShellOfflineMessage =>
      'Homeroom\'a ulaşılamıyor. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get stakingManagerTitle => 'Staking modu';

  @override
  String get stakingDelegateIntro =>
      'Stake\'inizi sunucuya devredin. Düğümünüz çalışmaya devam eder, ancak sunucu sizin adınıza staking yapar.';

  @override
  String get stakingServerName => 'Sunucu';

  @override
  String get stakingDelegateEffect =>
      'Düğümünüz blok üretmeyi bırakır. Devir süresince, doğrudan bu telefonda blok üreterek kazanacağınız blok üretim puanlarının yarısını alırsınız.';

  @override
  String get stakingDelegateNote =>
      'İstediğiniz zaman kendi başınıza staking yapmaya geri dönebilirsiniz.';

  @override
  String get stakingDelegateConfirm => 'Devri onayla';

  @override
  String get stakingDelegating => 'Devrediliyor…';

  @override
  String get stakingDelegateError =>
      'Devir gönderilemedi. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get stakingDelegationActiveTitle => 'Devir etkin';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'Stake\'iniz $validator adlı doğrulayıcıya devredildi. Doğrudan bu telefonda blok üreterek kazanacağınız blok üretim puanlarının yarısını alırsınız.';
  }

  @override
  String get stakingDone => 'Bitti';

  @override
  String get stakingUndelegateTitle => 'Devir durdurulsun mu?';

  @override
  String get stakingUndelegateBody =>
      'Stake\'iniz bu telefona geri döner. Düğümünüz doğrudan blok üretir ve blok üretim puanlarının tamamını kazanır.';

  @override
  String get stakingUndelegateConfirm => 'Devri durdur';

  @override
  String get stakingUndelegateError =>
      'Devir durdurulamadı. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get versionUpdateRequiredTitle => 'Güncelleme Gerekli';

  @override
  String get versionUpdateAvailableTitle => 'Güncelleme Mevcut';

  @override
  String get versionUpdateAction => 'Güncelle';

  @override
  String get versionUpdateLater => 'Sonra';

  @override
  String get versionUpdateFallbackMessage =>
      'Uygulamanın yeni bir sürümü mevcut.';

  @override
  String get commonBack => 'Geri';

  @override
  String get commonDeny => 'Reddet';

  @override
  String get commonConfirm => 'Onayla';

  @override
  String get commonApprove => 'Onay ver';

  @override
  String get txConfirmTitle => 'İşlemi Onayla';

  @override
  String get txConfirmSubtitleDefault => 'Bir dapp işlem göndermek istiyor.';

  @override
  String get txAmount => 'Tutar';

  @override
  String get txDetails => 'Ayrıntılar';

  @override
  String get txFrom => 'Gönderen';

  @override
  String get txTo => 'Alıcı';

  @override
  String get txFee => 'Ücret';

  @override
  String get txMemo => 'Not';

  @override
  String get verifyIdentityTitle => 'Kimliği Doğrula';

  @override
  String verifyIdentityRequest(String name) {
    return '$name kimliğinizi doğrulamak istiyor';
  }

  @override
  String get verifyIdentityExplanation =>
      'Bu işlem, bu cüzdanın sahibi olduğunuzu kanıtlamak için özel anahtarınızla bir sınama imzalar. Hiçbir işlem gönderilmez ve hiçbir token harcanmaz.';

  @override
  String get zkChallengeBusy =>
      'Bir zkPassport kanıtı hâlâ işleniyor. Birazdan tekrar deneyin.';

  @override
  String get zkChallengeResetDone => 'ZK kanıt durumu sıfırlandı';

  @override
  String provingParametersDownloadProgress(int percent) {
    return 'Kanıt araçları hazırlanıyor: %$percent. İndirilen veriler daha sonra kullanılmak üzere kaydedilir.';
  }

  @override
  String get provingParametersDownloadFailed =>
      'Kanıt araçları indirilemedi. Bağlantınızı kontrol edip tekrar deneyin.';
}
