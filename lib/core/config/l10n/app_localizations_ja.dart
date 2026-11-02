// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline => 'AIでアプリを作る、\nいよいよマルチプレイヤーに。';

  @override
  String get initializingNode => '起動中…';

  @override
  String get resumeSplashLoading => '読み込み中…';

  @override
  String get clockDriftWarningTitle => 'システム時刻が正しくありません';

  @override
  String clockDriftWarningBody(String drift) {
    return 'お使いのデバイスの時計がノードの時計と$driftずれています。システム時刻を修正するまで、アプリで不整合が起こることがあります。';
  }

  @override
  String get clockDriftWarningInstruction => 'デバイスで自動時刻同期をオンにしてください。';

  @override
  String get clockDriftRecommendationTitle => 'おすすめ';

  @override
  String get clockDriftRecommendationBody =>
      'ずれを最小限にするため、設定で「日付と時刻の自動設定」と「タイムゾーンの自動設定」をオンのままにしてください。デバイスがネットワークから時刻を取得します。';

  @override
  String get clockDriftDismiss => 'OK';

  @override
  String clockDriftAhead(String seconds) {
    return '$seconds秒進んでいます';
  }

  @override
  String clockDriftBehind(String seconds) {
    return '$seconds秒遅れています';
  }

  @override
  String get settingsAbout => 'このアプリについて';

  @override
  String get settingsBuildInfo => 'ビルド情報';

  @override
  String get settingsDiagnostics => '診断';

  @override
  String get settingsDeviceBenchmark => 'デバイスベンチマーク';

  @override
  String get settingsDeviceBenchmarkSubtitle => 'デバイス上で性能を測定します';

  @override
  String get perfTitle => 'デバイスベンチマーク';

  @override
  String get perfIntroTitle => 'このデバイスでベンチマークを実行';

  @override
  String get perfIntroDescription =>
      'ハッシュ、部分同期、ブロック生成、ウォレット送金の処理を測定して、このデバイスの性能を確認します。';

  @override
  String get perfIntroNote =>
      '結果は今のところこのデバイスにのみ保存されます。性能はバッテリー残量、温度、バックグラウンドの動作によって変わることがあります。';

  @override
  String get perfCatalogLoadError => 'ベンチマークの一覧を読み込めませんでした。';

  @override
  String get perfCatalogLoading => 'ベンチマークの一覧を読み込み中…';

  @override
  String get perfProfileQuick => 'クイックチェック';

  @override
  String get perfProfileStandard => 'フルベンチマーク';

  @override
  String perfRunProfile(String profile) {
    return '$profileを実行';
  }

  @override
  String perfStepCount(int count) {
    return '$countステップ';
  }

  @override
  String get perfCurrentRunTitle => '実行中のベンチマーク';

  @override
  String get perfRunInProgressTitle => 'ベンチマークを実行中';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'このデバイスでは$profileがすでに実行中です。';
  }

  @override
  String get perfRunInProgressDescriptionUnknown => 'このデバイスではベンチマークがすでに実行中です。';

  @override
  String get perfOpenCurrentRun => '実行中のベンチマークを開く';

  @override
  String get perfLatestResultsTitle => '最新の結果';

  @override
  String perfLatestResultsDescription(String profile) {
    return '$profileの結果を確認できます。';
  }

  @override
  String get perfLatestResultsDescriptionUnknown => 'ベンチマークの結果を確認できます。';

  @override
  String get perfViewLatestResults => '最新の結果を見る';

  @override
  String get perfNoRunAvailableTitle => 'ベンチマークがありません';

  @override
  String get perfNoRunAvailableDescription =>
      'ベンチマーク画面から開始すると、進行状況や結果がここに表示されます。';

  @override
  String get perfBackToBenchmarks => 'ベンチマークに戻る';

  @override
  String get perfRunPausedNodeNotice => 'このベンチマークの実行中は、バックグラウンドのノードを一時停止します。';

  @override
  String get perfStateRunning => '実行中';

  @override
  String get perfStateStarting => '開始中';

  @override
  String get perfStateCompleted => '完了';

  @override
  String get perfStateFailed => '失敗';

  @override
  String get perfStateCancelled => 'キャンセル済み';

  @override
  String perfProgressValue(int completed, int total) {
    return '$totalステップ中$completedステップ';
  }

  @override
  String perfPreparingProfile(String profile) {
    return '$profileを準備中';
  }

  @override
  String perfCurrentStep(String label) {
    return '現在のステップ:$label';
  }

  @override
  String perfElapsed(String duration) {
    return '経過時間:$duration';
  }

  @override
  String get perfResultsTitle => '結果';

  @override
  String get perfResultProfile => 'プロファイル';

  @override
  String get perfResultDevice => 'デバイス';

  @override
  String get perfResultOperatingSystem => 'OS';

  @override
  String get perfResultCpu => 'CPU';

  @override
  String get perfResultLogicalCores => '論理コア数';

  @override
  String get perfResultMeasurements => '測定値';

  @override
  String get perfSuitePrimitives => '基本演算';

  @override
  String get perfSuitePartialSync => '部分同期';

  @override
  String get perfSuitePartialBlockProduction => 'ブロック生成';

  @override
  String get perfSuiteWalletSend => 'ウォレット送金';

  @override
  String get perfScenarioDefault => 'デフォルトのケース';

  @override
  String perfContextTxCount(int count) {
    return '$count件のtx';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'レイアウト $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return '形状 $value';
  }

  @override
  String get perfDetailScenario => 'シナリオ';

  @override
  String get perfDetailAverage => '平均';

  @override
  String get perfDetailMinMax => '最小 / 最大';

  @override
  String get perfDetailRuns => '実行回数';

  @override
  String get perfDetailMetadataTitle => 'シナリオの詳細';

  @override
  String get perfDetailImplementationTitle => '実装の詳細';

  @override
  String get perfDetailNotesTitle => 'メモ';

  @override
  String get perfDetailFlow => 'フロー';

  @override
  String get perfDetailTxCount => 'トランザクション数';

  @override
  String get perfDetailBatchLayout => 'バッチのレイアウト';

  @override
  String get perfDetailTransactionShape => 'トランザクションの形状';

  @override
  String get perfDetailTouchedLeaves => 'アクセスしたリーフ';

  @override
  String get perfDetailProofNodes => '証明ノード';

  @override
  String get perfDetailProofSize => '証明のサイズ';

  @override
  String get perfCancelFailed => '実行中のベンチマークをキャンセルできませんでした。';

  @override
  String get perfRunUnavailable => 'このベンチマークは利用できなくなりました。';

  @override
  String get commonOk => 'OK';

  @override
  String get buildInfoVersion => 'バージョン';

  @override
  String get buildInfoCommit => 'コミット';

  @override
  String get buildInfoBranch => 'ブランチ';

  @override
  String get buildInfoCommitTime => 'コミット日時';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Cargoターゲット';

  @override
  String get buildInfoFeatures => '機能';

  @override
  String get buildInfoOptLevel => '最適化レベル';

  @override
  String get buildInfoDebug => 'デバッグ';

  @override
  String get retry => '再試行';

  @override
  String get zkIdentityAppNotFoundTitle => '先にZK Passportをインストールしてください';

  @override
  String get zkIdentityAppNotFoundDetail => '証明を作成し、そのあとこちらに戻ります';

  @override
  String get zkIdentityInstallCta => 'インストール';

  @override
  String get zkIdentityStepLabelOpenApp => 'ZK Passportを開いています';

  @override
  String get zkIdentityStepDescOpenApp => '保存済みのパスポートで証明リクエストを準備しています';

  @override
  String get zkIdentityCheckAppCta => '続ける';

  @override
  String get zkIdentityAccountPreparingTitle => 'アカウントを準備しています';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'サインイン中のSocial Vibecodingアカウントに接続しています';

  @override
  String get zkIdentityAccountUnavailable =>
      '認証を始める前に、Social Vibecodingにサインインしてください。';

  @override
  String get zkIdentityStepLabelScan => '保存済みのパスポートを使う';

  @override
  String get zkIdentityStepDescScan => 'ZK Passportにすでに保存されているパスポートを使います';

  @override
  String get zkIdentityConfirmScannedBody => '保存済みのパスポートを使用します。';

  @override
  String get zkIdentityConfirmScannedYesCta => '続ける';

  @override
  String get zkIdentityConfirmScannedNoCta => '今はしない';

  @override
  String get zkIdentityStepLabelReady => '証明を作成';

  @override
  String get zkIdentityStepDescReady => 'ZK Passportで承認すると、証明が作成されます';

  @override
  String get zkIdentityReadyBody => 'ZK Passportが、保存済みのパスポートから約1分で証明を作成します。';

  @override
  String get zkIdentityReadyBullet1 => '名前、写真、IDは共有されません';

  @override
  String get zkIdentityReadyBullet2 => '送信するのは証明だけです';

  @override
  String get zkIdentityReadyBullet3 => '個人情報はオンチェーンに保存されません';

  @override
  String get zkIdentityReadyCta => 'ZK Passportを開く';

  @override
  String get zkIdentityStepLabelVerifying => '認証中';

  @override
  String get zkIdentityStepDescVerifying => '証明を作成して確認しています';

  @override
  String get zkIdentityStepLabelResult => '結果';

  @override
  String get zkIdentityStepDescResult => '認証の結果を確認します';

  @override
  String get zkIdentitySubTaskOpening => 'ZK Passportを開いています';

  @override
  String get zkIdentitySubTaskWaiting => '証明を待っています';

  @override
  String get zkIdentitySubTaskChecking => '証明を確認しています';

  @override
  String get zkIdentitySubTaskWrapping => '証明をまとめています';

  @override
  String get zkIdentitySubTaskFinal => '最終チェック';

  @override
  String get zkIdentityResultSuccessTitle => 'あなたはユニークな人間です!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      '名前、写真、IDを共有せずに、ユニークであることを証明しました';

  @override
  String get zkIdentityStatusUniqueness => 'ユニークな人間';

  @override
  String get zkIdentityStatusUniquenessValue => '確認済み';

  @override
  String get zkIdentityStatusFaceMatchLabel => '顔チェック';

  @override
  String get zkIdentityStatusPrivacyValue => '共有なし';

  @override
  String get zkIdentityCancelVerification => 'キャンセル';

  @override
  String get zkIdentityGoToZkPassport => 'ZK Passportに切り替える';

  @override
  String get zkIdentityTryAgain => 'もう一度試す';

  @override
  String get zkIdentityWalletClaimTitle => 'プログラムのウォレットを接続';

  @override
  String get zkIdentityWalletClaimDescription =>
      'このSocialアカウントは、既存のウォレットを持つアカウントとは別です。接続するには、元のプログラムのメールアドレスを一度認証してください。';

  @override
  String get zkIdentityWalletClaimEmailLabel => '元のプログラムのメールアドレス';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      '元のHomeroomプログラムに登録したメールアドレスを使ってください。';

  @override
  String get zkIdentityWalletClaimSendCode => '認証コードを送信';

  @override
  String get zkIdentityWalletClaimSendingCode => 'コードを送信中…';

  @override
  String get zkIdentityWalletClaimCodeSent => 'そのメールアドレスに送信された6桁のコードを入力してください。';

  @override
  String get zkIdentityWalletClaimCodeLabel => '認証コード';

  @override
  String get zkIdentityWalletClaimConnect => 'ウォレットを接続して続ける';

  @override
  String get zkIdentityWalletClaimConnecting => 'ウォレットを接続中…';

  @override
  String get zkIdentityWalletClaimChangeEmail => '別のメールアドレスを使う';

  @override
  String get zkIdentityWalletClaimEmailRequired => '有効なメールアドレスを入力してください。';

  @override
  String get zkIdentityWalletClaimCodeRequired => '6桁のコードを入力してください。';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'ウォレットは接続されましたが、アプリで準備を完了できませんでした。もう一度お試しください。';

  @override
  String get zkIdentityDone => '完了';

  @override
  String get zkIdentityStatusFaceMatchVerified => '確認済み';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'スキップ';

  @override
  String get zkIdentityStatusPrivacyLabel => 'プライバシー';

  @override
  String get zkIdentityStatusVerifiedDateLabel => '認証日';

  @override
  String get zkIdentityStatusProofIdLabel => '証明ID';

  @override
  String get zkIdentityStatusVerifyDurationLabel => '認証';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'まとめ処理';

  @override
  String get zkIdentityStatusFinalCheckLabel => '最終チェック';

  @override
  String get zkIdentityResultFailureTitle => '認証できませんでした';

  @override
  String get zkIdentityResultFailureSubtitle => '名前、写真、IDは共有されていません';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonCopied => 'コピーしました';

  @override
  String get buildInfoAppVersion => 'アプリのバージョン';

  @override
  String get buildInfoBuildNumber => 'ビルド番号';

  @override
  String get settingsDebugMode => 'デバッグモード';

  @override
  String get settingsDebugModeEnabled => 'HTTPリクエストをメモリに記録中';

  @override
  String get settingsDebugModeDisabled => 'オフ · ネットワークログなし';

  @override
  String get settingsHttpLogs => 'HTTPログ';

  @override
  String get settingsHttpLogsSubtitle => '記録したネットワークリクエストを表示';

  @override
  String get httpLogsTitle => 'HTTPログ';

  @override
  String get httpLogsEmpty => 'まだリクエストが記録されていません。ネットワークを使う操作をすると、ここにログが表示されます。';

  @override
  String get httpLogsCopy => 'すべてコピー';

  @override
  String get httpLogsClear => 'クリア';

  @override
  String get httpLogsCopied => 'ログをクリップボードにコピーしました';

  @override
  String get httpLogsShare => 'ログをチームと共有';

  @override
  String get httpLogsSharing => '30秒ごとにログをチームと共有中…';

  @override
  String get httpLogsStopSharing => '共有を停止';

  @override
  String get httpLogsShareStopped => 'サーバーがログの共有を停止しました。いつでもまた共有できます。';

  @override
  String get httpLogsShareNoParticipant =>
      '参加者IDがまだありません。ログを共有するにはオンボーディングを完了してください';

  @override
  String get httpLogsFilterHint => 'URLで絞り込み';

  @override
  String get httpLogsNoMatches => '条件に一致するリクエストはありません。';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$total件中$count件';
  }

  @override
  String get widgetInstructionsTitle => 'Homeroomウィジェットを追加';

  @override
  String widgetInstructionsBody(String name) {
    return '$nameがHomeroomのdAppsウィジェットに追加されました。ホーム画面に表示するには、ウィジェットを一度追加してください。';
  }

  @override
  String get widgetInstructionsStep1 => 'ホーム画面の何もない場所を長押しします';

  @override
  String get widgetInstructionsStep2 => '画面の隅にある「編集」をタップし、「ウィジェットを追加」をタップします';

  @override
  String get widgetInstructionsStep3 => 'Homeroomを検索して、dAppsウィジェットを追加します';

  @override
  String get widgetInstructionsDone => '完了';

  @override
  String get svShellConnectingTitle => 'Homeroomに接続中…';

  @override
  String get svShellOfflineMessage => 'Homeroomに接続できません。通信状況を確認して、もう一度お試しください。';

  @override
  String get stakingManagerTitle => 'ステーキングモード';

  @override
  String get stakingDelegateIntro =>
      'ステークをサーバーに委任します。ノードは動き続けますが、ステーキングはサーバーがあなたに代わって行います。';

  @override
  String get stakingServerName => 'サーバー';

  @override
  String get stakingDelegateEffect =>
      'ノードはブロックの生成を停止します。委任中は、このスマートフォンで直接ブロックを生成した場合に得られるブロック生成ポイントの半分を受け取れます。';

  @override
  String get stakingDelegateNote => 'いつでも自分でのステーキングに戻せます。';

  @override
  String get stakingDelegateConfirm => '委任を確定';

  @override
  String get stakingDelegating => '委任中…';

  @override
  String get stakingDelegateError => '委任を送信できませんでした。通信状況を確認して、もう一度お試しください。';

  @override
  String get stakingDelegationActiveTitle => '委任中';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'ステークは$validatorに委任されています。このスマートフォンで直接ブロックを生成した場合に得られるブロック生成ポイントの半分を受け取れます。';
  }

  @override
  String get stakingDone => '完了';

  @override
  String get stakingUndelegateTitle => '委任を停止しますか?';

  @override
  String get stakingUndelegateBody =>
      'ステークはこのスマートフォンに戻ります。ノードが直接ブロックを生成し、ブロック生成ポイントをすべて獲得します。';

  @override
  String get stakingUndelegateConfirm => '委任を停止';

  @override
  String get stakingUndelegateError => '委任を停止できませんでした。通信状況を確認して、もう一度お試しください。';

  @override
  String get versionUpdateRequiredTitle => 'アップデートが必要です';

  @override
  String get versionUpdateAvailableTitle => 'アップデートがあります';

  @override
  String get versionUpdateAction => 'アップデート';

  @override
  String get versionUpdateLater => 'あとで';

  @override
  String get versionUpdateFallbackMessage => 'アプリの新しいバージョンがあります。';

  @override
  String get commonBack => '戻る';

  @override
  String get commonDeny => '拒否';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonApprove => '承認';

  @override
  String get txConfirmTitle => 'トランザクションの確認';

  @override
  String get txConfirmSubtitleDefault => 'dAppがトランザクションの送信を求めています。';

  @override
  String get txAmount => '金額';

  @override
  String get txDetails => '詳細';

  @override
  String get txFrom => '送信元';

  @override
  String get txTo => '送信先';

  @override
  String get txFee => '手数料';

  @override
  String get txMemo => 'メモ';

  @override
  String get verifyIdentityTitle => '本人確認';

  @override
  String verifyIdentityRequest(String name) {
    return '$nameがあなたの本人確認を求めています';
  }

  @override
  String get verifyIdentityExplanation =>
      'このウォレットの所有者であることを証明するため、秘密鍵でチャレンジに署名します。トランザクションは送信されず、トークンも消費されません。';

  @override
  String get zkChallengeBusy => 'zkPassportの証明をまだ処理中です。しばらくしてからもう一度お試しください。';

  @override
  String get zkChallengeResetDone => 'ZK証明の状態をリセットしました';
}
