// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline => 'Membuat Aplikasi dengan AI,\nKini Multipemain.';

  @override
  String get initializingNode => 'Memulai…';

  @override
  String get resumeSplashLoading => 'Memuat…';

  @override
  String get clockDriftWarningTitle => 'Waktu sistem tidak tepat';

  @override
  String clockDriftWarningBody(String drift) {
    return 'Jam perangkat Anda berbeda $drift dari jam node. Anda mungkin melihat beberapa ketidakkonsistenan di aplikasi sampai waktu sistem diperbaiki.';
  }

  @override
  String get clockDriftWarningInstruction =>
      'Aktifkan sinkronisasi waktu otomatis di perangkat Anda.';

  @override
  String get clockDriftRecommendationTitle => 'Rekomendasi';

  @override
  String get clockDriftRecommendationBody =>
      'Agar selisih waktu sekecil mungkin, biarkan \"Tanggal & waktu otomatis\" dan \"Zona waktu otomatis\" tetap aktif di pengaturan, sehingga perangkat mengambil waktu dari jaringan.';

  @override
  String get clockDriftDismiss => 'OK';

  @override
  String clockDriftAhead(String seconds) {
    return 'Lebih cepat $seconds dtk';
  }

  @override
  String clockDriftBehind(String seconds) {
    return 'Lebih lambat $seconds dtk';
  }

  @override
  String get settingsAbout => 'Tentang';

  @override
  String get settingsBuildInfo => 'Info Build';

  @override
  String get settingsDiagnostics => 'Diagnostik';

  @override
  String get settingsDeviceBenchmark => 'Benchmark Perangkat';

  @override
  String get settingsDeviceBenchmarkSubtitle =>
      'Jalankan pengukuran performa di perangkat';

  @override
  String get perfTitle => 'Benchmark Perangkat';

  @override
  String get perfIntroTitle => 'Jalankan benchmark di perangkat ini';

  @override
  String get perfIntroDescription =>
      'Ukur beban kerja hashing, sinkronisasi parsial, produksi blok, dan pengiriman dompet untuk melihat performa perangkat ini.';

  @override
  String get perfIntroNote =>
      'Untuk saat ini, hasil hanya tersimpan di perangkat ini. Performa dapat berubah tergantung level baterai, suhu, dan aktivitas latar belakang.';

  @override
  String get perfCatalogLoadError => 'Tidak dapat memuat katalog benchmark.';

  @override
  String get perfCatalogLoading => 'Memuat katalog benchmark…';

  @override
  String get perfProfileQuick => 'Cek Cepat';

  @override
  String get perfProfileStandard => 'Benchmark Lengkap';

  @override
  String perfRunProfile(String profile) {
    return 'Jalankan $profile';
  }

  @override
  String perfStepCount(int count) {
    return '$count langkah';
  }

  @override
  String get perfCurrentRunTitle => 'Proses Saat Ini';

  @override
  String get perfRunInProgressTitle => 'Benchmark Sedang Berjalan';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'Benchmark $profile sedang berjalan di perangkat ini.';
  }

  @override
  String get perfRunInProgressDescriptionUnknown =>
      'Sebuah benchmark sedang berjalan di perangkat ini.';

  @override
  String get perfOpenCurrentRun => 'Buka Proses Saat Ini';

  @override
  String get perfLatestResultsTitle => 'Hasil Terbaru';

  @override
  String perfLatestResultsDescription(String profile) {
    return 'Hasil $profile siap ditinjau.';
  }

  @override
  String get perfLatestResultsDescriptionUnknown =>
      'Hasil benchmark siap ditinjau.';

  @override
  String get perfViewLatestResults => 'Lihat Hasil Terbaru';

  @override
  String get perfNoRunAvailableTitle => 'Belum Ada Benchmark';

  @override
  String get perfNoRunAvailableDescription =>
      'Mulai benchmark dari layar benchmark untuk melihat progres atau hasilnya di sini.';

  @override
  String get perfBackToBenchmarks => 'Kembali ke Benchmark';

  @override
  String get perfRunPausedNodeNotice =>
      'Node latar belakang dijeda selama benchmark ini berjalan.';

  @override
  String get perfStateRunning => 'Berjalan';

  @override
  String get perfStateStarting => 'Memulai';

  @override
  String get perfStateCompleted => 'Selesai';

  @override
  String get perfStateFailed => 'Gagal';

  @override
  String get perfStateCancelled => 'Dibatalkan';

  @override
  String perfProgressValue(int completed, int total) {
    return '$completed dari $total langkah';
  }

  @override
  String perfPreparingProfile(String profile) {
    return 'Menyiapkan $profile';
  }

  @override
  String perfCurrentStep(String label) {
    return 'Langkah saat ini: $label';
  }

  @override
  String perfElapsed(String duration) {
    return 'Berlalu: $duration';
  }

  @override
  String get perfResultsTitle => 'Hasil';

  @override
  String get perfResultProfile => 'Profil';

  @override
  String get perfResultDevice => 'Perangkat';

  @override
  String get perfResultOperatingSystem => 'OS';

  @override
  String get perfResultCpu => 'CPU';

  @override
  String get perfResultLogicalCores => 'Core Logis';

  @override
  String get perfResultMeasurements => 'Pengukuran';

  @override
  String get perfSuitePrimitives => 'Primitif';

  @override
  String get perfSuitePartialSync => 'Sinkronisasi Parsial';

  @override
  String get perfSuitePartialBlockProduction => 'Produksi Blok';

  @override
  String get perfSuiteWalletSend => 'Kirim dari Dompet';

  @override
  String get perfScenarioDefault => 'Kasus default';

  @override
  String perfContextTxCount(int count) {
    return '$count tx';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'Tata letak $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return 'Bentuk $value';
  }

  @override
  String get perfDetailScenario => 'Skenario';

  @override
  String get perfDetailAverage => 'Rata-rata';

  @override
  String get perfDetailMinMax => 'Min / Maks';

  @override
  String get perfDetailRuns => 'Proses';

  @override
  String get perfDetailMetadataTitle => 'Detail Skenario';

  @override
  String get perfDetailImplementationTitle => 'Detail Implementasi';

  @override
  String get perfDetailNotesTitle => 'Catatan';

  @override
  String get perfDetailFlow => 'Alur';

  @override
  String get perfDetailTxCount => 'Jumlah Transaksi';

  @override
  String get perfDetailBatchLayout => 'Tata Letak Batch';

  @override
  String get perfDetailTransactionShape => 'Bentuk Transaksi';

  @override
  String get perfDetailTouchedLeaves => 'Leaf yang Disentuh';

  @override
  String get perfDetailProofNodes => 'Node Bukti';

  @override
  String get perfDetailProofSize => 'Ukuran Bukti';

  @override
  String get perfCancelFailed =>
      'Tidak dapat membatalkan benchmark yang sedang berjalan.';

  @override
  String get perfRunUnavailable => 'Benchmark ini sudah tidak tersedia.';

  @override
  String get commonOk => 'OK';

  @override
  String get buildInfoVersion => 'Versi';

  @override
  String get buildInfoCommit => 'Commit';

  @override
  String get buildInfoBranch => 'Branch';

  @override
  String get buildInfoCommitTime => 'Waktu commit';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Target Cargo';

  @override
  String get buildInfoFeatures => 'Fitur';

  @override
  String get buildInfoOptLevel => 'Level optimasi';

  @override
  String get buildInfoDebug => 'Debug';

  @override
  String get retry => 'Coba lagi';

  @override
  String get zkIdentityAppNotFoundTitle => 'Instal ZK Passport terlebih dahulu';

  @override
  String get zkIdentityAppNotFoundDetail =>
      'ZK Passport membuat bukti Anda, lalu mengembalikan Anda ke sini';

  @override
  String get zkIdentityInstallCta => 'Instal';

  @override
  String get zkIdentityStepLabelOpenApp => 'Membuka ZK Passport';

  @override
  String get zkIdentityStepDescOpenApp =>
      'Menyiapkan permintaan bukti dengan paspor tersimpan Anda';

  @override
  String get zkIdentityCheckAppCta => 'Lanjutkan';

  @override
  String get zkIdentityAccountPreparingTitle => 'Menyiapkan akun Anda';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'Menghubungkan akun Social Vibecoding Anda yang sedang masuk';

  @override
  String get zkIdentityAccountUnavailable =>
      'Masuk ke Social Vibecoding sebelum memulai verifikasi.';

  @override
  String get zkIdentityStepLabelScan => 'Gunakan paspor tersimpan';

  @override
  String get zkIdentityStepDescScan =>
      'Menggunakan paspor yang sudah tersimpan di ZK Passport';

  @override
  String get zkIdentityConfirmScannedBody =>
      'Paspor tersimpan Anda akan digunakan.';

  @override
  String get zkIdentityConfirmScannedYesCta => 'Lanjutkan';

  @override
  String get zkIdentityConfirmScannedNoCta => 'Belum';

  @override
  String get zkIdentityStepLabelReady => 'Buat bukti';

  @override
  String get zkIdentityStepDescReady =>
      'ZK Passport akan meminta Anda menyetujui dan membuat bukti';

  @override
  String get zkIdentityReadyBody =>
      'ZK Passport membuat bukti dari paspor tersimpan Anda dalam waktu sekitar satu menit.';

  @override
  String get zkIdentityReadyBullet1 =>
      'Tidak ada nama, foto, atau ID yang dibagikan';

  @override
  String get zkIdentityReadyBullet2 => 'Anda hanya mengirim bukti';

  @override
  String get zkIdentityReadyBullet3 =>
      'Tidak ada data pribadi yang disimpan di blockchain';

  @override
  String get zkIdentityReadyCta => 'Buka ZK Passport';

  @override
  String get zkIdentityStepLabelVerifying => 'Memverifikasi';

  @override
  String get zkIdentityStepDescVerifying => 'Membuat dan memeriksa bukti Anda';

  @override
  String get zkIdentityStepLabelResult => 'Hasil';

  @override
  String get zkIdentityStepDescResult => 'Lihat hasil verifikasi Anda';

  @override
  String get zkIdentitySubTaskOpening => 'Membuka ZK Passport';

  @override
  String get zkIdentitySubTaskWaiting => 'Menunggu bukti Anda';

  @override
  String get zkIdentitySubTaskChecking => 'Memeriksa bukti Anda';

  @override
  String get zkIdentitySubTaskWrapping => 'Membungkus bukti Anda';

  @override
  String get zkIdentitySubTaskFinal => 'Pemeriksaan akhir';

  @override
  String get zkIdentityResultSuccessTitle => 'Anda manusia yang unik!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      'Anda membuktikan keunikan Anda tanpa membagikan nama, foto, atau ID';

  @override
  String get zkIdentityStatusUniqueness => 'Manusia unik';

  @override
  String get zkIdentityStatusUniquenessValue => 'Terkonfirmasi';

  @override
  String get zkIdentityStatusFaceMatchLabel => 'Pemeriksaan wajah';

  @override
  String get zkIdentityStatusPrivacyValue => 'Tidak ada yang dibagikan';

  @override
  String get zkIdentityCancelVerification => 'Batal';

  @override
  String get zkIdentityGoToZkPassport => 'Beralih ke ZK Passport';

  @override
  String get zkIdentityTryAgain => 'Coba lagi';

  @override
  String get zkIdentityWalletClaimTitle => 'Hubungkan dompet program Anda';

  @override
  String get zkIdentityWalletClaimDescription =>
      'Akun Social ini berbeda dari akun yang memegang dompet Anda yang sudah ada. Verifikasi email program asli Anda satu kali untuk menghubungkannya.';

  @override
  String get zkIdentityWalletClaimEmailLabel => 'Email program asli';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      'Gunakan email dari pendaftaran program Homeroom asli Anda.';

  @override
  String get zkIdentityWalletClaimSendCode => 'Kirim kode verifikasi';

  @override
  String get zkIdentityWalletClaimSendingCode => 'Mengirim kode…';

  @override
  String get zkIdentityWalletClaimCodeSent =>
      'Masukkan kode 6 digit yang dikirim ke email tersebut.';

  @override
  String get zkIdentityWalletClaimCodeLabel => 'Kode verifikasi';

  @override
  String get zkIdentityWalletClaimConnect => 'Hubungkan dompet dan lanjutkan';

  @override
  String get zkIdentityWalletClaimConnecting => 'Menghubungkan dompet…';

  @override
  String get zkIdentityWalletClaimChangeEmail => 'Gunakan email lain';

  @override
  String get zkIdentityWalletClaimEmailRequired =>
      'Masukkan alamat email yang valid.';

  @override
  String get zkIdentityWalletClaimCodeRequired => 'Masukkan kode 6 digit.';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'Dompet Anda sudah terhubung, tetapi aplikasi tidak dapat menyelesaikan penyiapannya. Coba lagi.';

  @override
  String get zkIdentityDone => 'Selesai';

  @override
  String get zkIdentityStatusFaceMatchVerified => 'Terverifikasi';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'Dilewati';

  @override
  String get zkIdentityStatusPrivacyLabel => 'Privasi';

  @override
  String get zkIdentityStatusVerifiedDateLabel => 'Diverifikasi pada';

  @override
  String get zkIdentityStatusProofIdLabel => 'ID bukti';

  @override
  String get zkIdentityStatusVerifyDurationLabel => 'Verifikasi';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'Pembungkusan';

  @override
  String get zkIdentityStatusFinalCheckLabel => 'Pemeriksaan akhir';

  @override
  String get zkIdentityResultFailureTitle => 'Tidak dapat diverifikasi';

  @override
  String get zkIdentityResultFailureSubtitle =>
      'Anda tidak membagikan nama, foto, atau ID';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonRetry => 'Coba lagi';

  @override
  String get commonCopied => 'Disalin';

  @override
  String get buildInfoAppVersion => 'Versi Aplikasi';

  @override
  String get buildInfoBuildNumber => 'Nomor Build';

  @override
  String get settingsDebugMode => 'Mode Debug';

  @override
  String get settingsDebugModeEnabled => 'Merekam permintaan HTTP ke memori';

  @override
  String get settingsDebugModeDisabled => 'Nonaktif · tanpa log jaringan';

  @override
  String get settingsHttpLogs => 'Log HTTP';

  @override
  String get settingsHttpLogsSubtitle =>
      'Lihat permintaan jaringan yang direkam';

  @override
  String get httpLogsTitle => 'Log HTTP';

  @override
  String get httpLogsEmpty =>
      'Belum ada permintaan yang direkam. Lakukan aktivitas jaringan untuk melihat log di sini.';

  @override
  String get httpLogsCopy => 'Salin semua';

  @override
  String get httpLogsClear => 'Hapus';

  @override
  String get httpLogsCopied => 'Log disalin ke papan klip';

  @override
  String get httpLogsShare => 'Bagikan log ke tim';

  @override
  String get httpLogsSharing => 'Membagikan log ke tim setiap 30 dtk…';

  @override
  String get httpLogsStopSharing => 'Berhenti membagikan';

  @override
  String get httpLogsShareStopped =>
      'Server menghentikan pembagian log. Anda dapat membagikannya lagi kapan saja.';

  @override
  String get httpLogsShareNoParticipant =>
      'Belum ada ID peserta — selesaikan orientasi untuk membagikan log';

  @override
  String get httpLogsFilterHint => 'Filter berdasarkan URL';

  @override
  String get httpLogsNoMatches =>
      'Tidak ada permintaan yang cocok dengan filter.';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$count dari $total';
  }

  @override
  String get widgetInstructionsTitle => 'Tambahkan widget Homeroom';

  @override
  String widgetInstructionsBody(String name) {
    return '$name telah ditambahkan ke widget dApps Homeroom Anda. Agar tampil di layar utama, tambahkan widget satu kali:';
  }

  @override
  String get widgetInstructionsStep1 =>
      'Sentuh dan tahan area kosong di layar utama';

  @override
  String get widgetInstructionsStep2 =>
      'Ketuk Edit di pojok atas, lalu Tambah Widget';

  @override
  String get widgetInstructionsStep3 =>
      'Cari Homeroom dan tambahkan widget dApps';

  @override
  String get widgetInstructionsDone => 'Selesai';

  @override
  String get svShellConnectingTitle => 'Menghubungkan ke Homeroom…';

  @override
  String get svShellOfflineMessage =>
      'Tidak dapat menjangkau Homeroom. Periksa koneksi Anda dan coba lagi.';

  @override
  String get stakingManagerTitle => 'Mode staking';

  @override
  String get stakingDelegateIntro =>
      'Delegasikan stake Anda ke server. Node Anda tetap berjalan, tetapi server melakukan staking atas nama Anda.';

  @override
  String get stakingServerName => 'Server';

  @override
  String get stakingDelegateEffect =>
      'Node Anda berhenti memproduksi blok. Selama didelegasikan, Anda menerima setengah dari poin produksi blok yang akan Anda peroleh jika memproduksi blok langsung di ponsel ini.';

  @override
  String get stakingDelegateNote =>
      'Anda dapat kembali melakukan staking sendiri kapan saja.';

  @override
  String get stakingDelegateConfirm => 'Konfirmasi delegasi';

  @override
  String get stakingDelegating => 'Mendelegasikan…';

  @override
  String get stakingDelegateError =>
      'Tidak dapat mengirim delegasi. Periksa koneksi Anda dan coba lagi.';

  @override
  String get stakingDelegationActiveTitle => 'Delegasi aktif';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'Stake Anda didelegasikan ke $validator. Anda menerima setengah dari poin produksi blok yang akan Anda peroleh jika memproduksi blok langsung di ponsel ini.';
  }

  @override
  String get stakingDone => 'Selesai';

  @override
  String get stakingUndelegateTitle => 'Hentikan delegasi?';

  @override
  String get stakingUndelegateBody =>
      'Stake Anda kembali ke ponsel ini. Node Anda akan memproduksi blok secara langsung dan memperoleh poin produksi blok penuh.';

  @override
  String get stakingUndelegateConfirm => 'Hentikan delegasi';

  @override
  String get stakingUndelegateError =>
      'Tidak dapat menghentikan delegasi. Periksa koneksi Anda dan coba lagi.';

  @override
  String get versionUpdateRequiredTitle => 'Pembaruan Diperlukan';

  @override
  String get versionUpdateAvailableTitle => 'Pembaruan Tersedia';

  @override
  String get versionUpdateAction => 'Perbarui';

  @override
  String get versionUpdateLater => 'Nanti';

  @override
  String get versionUpdateFallbackMessage => 'Versi baru aplikasi tersedia.';

  @override
  String get commonBack => 'Kembali';

  @override
  String get commonDeny => 'Tolak';

  @override
  String get commonConfirm => 'Konfirmasi';

  @override
  String get commonApprove => 'Setujui';

  @override
  String get txConfirmTitle => 'Konfirmasi Transaksi';

  @override
  String get txConfirmSubtitleDefault =>
      'Sebuah dapp meminta untuk mengirim transaksi.';

  @override
  String get txAmount => 'Jumlah';

  @override
  String get txDetails => 'Detail';

  @override
  String get txFrom => 'Dari';

  @override
  String get txTo => 'Ke';

  @override
  String get txFee => 'Biaya';

  @override
  String get txMemo => 'Memo';

  @override
  String get verifyIdentityTitle => 'Verifikasi Identitas';

  @override
  String verifyIdentityRequest(String name) {
    return '$name meminta untuk memverifikasi identitas Anda';
  }

  @override
  String get verifyIdentityExplanation =>
      'Ini akan menandatangani sebuah tantangan dengan kunci privat Anda untuk membuktikan bahwa Anda pemilik dompet ini. Tidak ada transaksi yang dikirim dan tidak ada token yang digunakan.';

  @override
  String get zkChallengeBusy =>
      'Bukti zkPassport masih diproses. Coba lagi sebentar lagi.';

  @override
  String get zkChallengeResetDone => 'Status bukti ZK direset';

  @override
  String provingParametersDownloadProgress(int percent) {
    return 'Menyiapkan alat pembuktian: $percent%. Unduhan ini disimpan untuk digunakan lagi.';
  }

  @override
  String get provingParametersDownloadFailed =>
      'Alat pembuktian tidak dapat diunduh. Periksa koneksi Anda dan coba lagi.';
}
