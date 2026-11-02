// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline => 'AI로 앱 만들기,\n이제 멀티플레이어로.';

  @override
  String get initializingNode => '시작하는 중…';

  @override
  String get resumeSplashLoading => '로드 중…';

  @override
  String get clockDriftWarningTitle => '시스템 시간이 올바르지 않음';

  @override
  String clockDriftWarningBody(String drift) {
    return '기기 시계가 노드 시계와 $drift 차이가 납니다. 시스템 시간을 바로잡을 때까지 앱에서 일부 불일치가 나타날 수 있습니다.';
  }

  @override
  String get clockDriftWarningInstruction => '기기에서 자동 시간 동기화를 켜세요.';

  @override
  String get clockDriftRecommendationTitle => '권장 사항';

  @override
  String get clockDriftRecommendationBody =>
      '시간 차이를 최소화하려면 설정에서 \'날짜 및 시간 자동 설정\'과 \'시간대 자동 설정\'을 켜 두세요. 기기가 네트워크 시간을 가져옵니다.';

  @override
  String get clockDriftDismiss => '확인';

  @override
  String clockDriftAhead(String seconds) {
    return '$seconds초 빠름';
  }

  @override
  String clockDriftBehind(String seconds) {
    return '$seconds초 느림';
  }

  @override
  String get settingsAbout => '정보';

  @override
  String get settingsBuildInfo => '빌드 정보';

  @override
  String get settingsDiagnostics => '진단';

  @override
  String get settingsDeviceBenchmark => '기기 벤치마크';

  @override
  String get settingsDeviceBenchmarkSubtitle => '기기에서 성능 측정 실행';

  @override
  String get perfTitle => '기기 벤치마크';

  @override
  String get perfIntroTitle => '이 기기에서 벤치마크 실행';

  @override
  String get perfIntroDescription =>
      '해싱, 부분 동기화, 블록 생성, 지갑 전송 작업을 측정해 이 기기의 성능을 확인하세요.';

  @override
  String get perfIntroNote =>
      '현재 결과는 이 기기에만 저장됩니다. 배터리 잔량, 온도, 백그라운드 활동에 따라 성능이 달라질 수 있습니다.';

  @override
  String get perfCatalogLoadError => '벤치마크 목록을 불러올 수 없습니다.';

  @override
  String get perfCatalogLoading => '벤치마크 목록을 불러오는 중…';

  @override
  String get perfProfileQuick => '빠른 점검';

  @override
  String get perfProfileStandard => '전체 벤치마크';

  @override
  String perfRunProfile(String profile) {
    return '$profile 실행';
  }

  @override
  String perfStepCount(int count) {
    return '$count단계';
  }

  @override
  String get perfCurrentRunTitle => '현재 실행';

  @override
  String get perfRunInProgressTitle => '벤치마크 진행 중';

  @override
  String perfRunInProgressDescription(String profile) {
    return '이 기기에서 $profile 벤치마크가 이미 실행 중입니다.';
  }

  @override
  String get perfRunInProgressDescriptionUnknown => '이 기기에서 벤치마크가 이미 실행 중입니다.';

  @override
  String get perfOpenCurrentRun => '현재 실행 열기';

  @override
  String get perfLatestResultsTitle => '최근 결과';

  @override
  String perfLatestResultsDescription(String profile) {
    return '$profile 결과를 확인할 수 있습니다.';
  }

  @override
  String get perfLatestResultsDescriptionUnknown => '벤치마크 결과를 확인할 수 있습니다.';

  @override
  String get perfViewLatestResults => '최근 결과 보기';

  @override
  String get perfNoRunAvailableTitle => '벤치마크 없음';

  @override
  String get perfNoRunAvailableDescription =>
      '벤치마크 화면에서 벤치마크를 시작하면 진행 상황이나 결과가 여기에 표시됩니다.';

  @override
  String get perfBackToBenchmarks => '벤치마크로 돌아가기';

  @override
  String get perfRunPausedNodeNotice => '이 벤치마크가 실행되는 동안 백그라운드 노드가 일시 중지됩니다.';

  @override
  String get perfStateRunning => '실행 중';

  @override
  String get perfStateStarting => '시작하는 중';

  @override
  String get perfStateCompleted => '완료됨';

  @override
  String get perfStateFailed => '실패';

  @override
  String get perfStateCancelled => '취소됨';

  @override
  String perfProgressValue(int completed, int total) {
    return '$total단계 중 $completed단계';
  }

  @override
  String perfPreparingProfile(String profile) {
    return '$profile 준비 중';
  }

  @override
  String perfCurrentStep(String label) {
    return '현재 단계: $label';
  }

  @override
  String perfElapsed(String duration) {
    return '경과 시간: $duration';
  }

  @override
  String get perfResultsTitle => '결과';

  @override
  String get perfResultProfile => '프로필';

  @override
  String get perfResultDevice => '기기';

  @override
  String get perfResultOperatingSystem => 'OS';

  @override
  String get perfResultCpu => 'CPU';

  @override
  String get perfResultLogicalCores => '논리 코어';

  @override
  String get perfResultMeasurements => '측정값';

  @override
  String get perfSuitePrimitives => '기본 연산';

  @override
  String get perfSuitePartialSync => '부분 동기화';

  @override
  String get perfSuitePartialBlockProduction => '블록 생성';

  @override
  String get perfSuiteWalletSend => '지갑 전송';

  @override
  String get perfScenarioDefault => '기본 케이스';

  @override
  String perfContextTxCount(int count) {
    return '트랜잭션 $count건';
  }

  @override
  String perfContextBatchLayout(String value) {
    return '레이아웃 $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return '형태 $value';
  }

  @override
  String get perfDetailScenario => '시나리오';

  @override
  String get perfDetailAverage => '평균';

  @override
  String get perfDetailMinMax => '최소 / 최대';

  @override
  String get perfDetailRuns => '실행 횟수';

  @override
  String get perfDetailMetadataTitle => '시나리오 세부 정보';

  @override
  String get perfDetailImplementationTitle => '구현 세부 정보';

  @override
  String get perfDetailNotesTitle => '참고';

  @override
  String get perfDetailFlow => '흐름';

  @override
  String get perfDetailTxCount => '트랜잭션 수';

  @override
  String get perfDetailBatchLayout => '배치 레이아웃';

  @override
  String get perfDetailTransactionShape => '트랜잭션 형태';

  @override
  String get perfDetailTouchedLeaves => '접근한 리프';

  @override
  String get perfDetailProofNodes => '증명 노드';

  @override
  String get perfDetailProofSize => '증명 크기';

  @override
  String get perfCancelFailed => '진행 중인 벤치마크를 취소할 수 없습니다.';

  @override
  String get perfRunUnavailable => '이 벤치마크는 더 이상 사용할 수 없습니다.';

  @override
  String get commonOk => '확인';

  @override
  String get buildInfoVersion => '버전';

  @override
  String get buildInfoCommit => '커밋';

  @override
  String get buildInfoBranch => '브랜치';

  @override
  String get buildInfoCommitTime => '커밋 시각';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Cargo 타깃';

  @override
  String get buildInfoFeatures => '기능';

  @override
  String get buildInfoOptLevel => '최적화 수준';

  @override
  String get buildInfoDebug => '디버그';

  @override
  String get retry => '다시 시도';

  @override
  String get zkIdentityAppNotFoundTitle => '먼저 ZK Passport를 설치하세요';

  @override
  String get zkIdentityAppNotFoundDetail => '증명을 만든 뒤 이곳으로 돌아옵니다';

  @override
  String get zkIdentityInstallCta => '설치';

  @override
  String get zkIdentityStepLabelOpenApp => 'ZK Passport 여는 중';

  @override
  String get zkIdentityStepDescOpenApp => '저장된 여권으로 증명 요청을 준비하는 중';

  @override
  String get zkIdentityCheckAppCta => '계속';

  @override
  String get zkIdentityAccountPreparingTitle => '계정을 준비하는 중';

  @override
  String get zkIdentityAccountPreparingDescription =>
      '로그인된 Social Vibecoding 계정을 연결하는 중';

  @override
  String get zkIdentityAccountUnavailable =>
      '인증을 시작하기 전에 Social Vibecoding에 로그인하세요.';

  @override
  String get zkIdentityStepLabelScan => '저장된 여권 사용';

  @override
  String get zkIdentityStepDescScan => 'ZK Passport에 이미 저장된 여권을 사용합니다';

  @override
  String get zkIdentityConfirmScannedBody => '저장된 여권을 사용합니다.';

  @override
  String get zkIdentityConfirmScannedYesCta => '계속';

  @override
  String get zkIdentityConfirmScannedNoCta => '나중에';

  @override
  String get zkIdentityStepLabelReady => '증명 만들기';

  @override
  String get zkIdentityStepDescReady => 'ZK Passport에서 승인하면 증명이 만들어집니다';

  @override
  String get zkIdentityReadyBody => 'ZK Passport가 저장된 여권으로 약 1분 안에 증명을 만듭니다.';

  @override
  String get zkIdentityReadyBullet1 => '이름, 사진, 신분증은 공유되지 않습니다';

  @override
  String get zkIdentityReadyBullet2 => '증명만 전송합니다';

  @override
  String get zkIdentityReadyBullet3 => '개인 정보는 온체인에 저장되지 않습니다';

  @override
  String get zkIdentityReadyCta => 'ZK Passport 열기';

  @override
  String get zkIdentityStepLabelVerifying => '인증 중';

  @override
  String get zkIdentityStepDescVerifying => '증명을 만들고 확인하는 중';

  @override
  String get zkIdentityStepLabelResult => '결과';

  @override
  String get zkIdentityStepDescResult => '인증 결과를 확인하세요';

  @override
  String get zkIdentitySubTaskOpening => 'ZK Passport 여는 중';

  @override
  String get zkIdentitySubTaskWaiting => '증명을 기다리는 중';

  @override
  String get zkIdentitySubTaskChecking => '증명을 확인하는 중';

  @override
  String get zkIdentitySubTaskWrapping => '증명을 포장하는 중';

  @override
  String get zkIdentitySubTaskFinal => '최종 확인';

  @override
  String get zkIdentityResultSuccessTitle => '고유한 사람임이 확인되었어요!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      '이름, 사진, 신분증을 공유하지 않고 고유한 사람임을 증명했습니다';

  @override
  String get zkIdentityStatusUniqueness => '고유한 사람';

  @override
  String get zkIdentityStatusUniquenessValue => '확인됨';

  @override
  String get zkIdentityStatusFaceMatchLabel => '얼굴 확인';

  @override
  String get zkIdentityStatusPrivacyValue => '공유된 정보 없음';

  @override
  String get zkIdentityCancelVerification => '취소';

  @override
  String get zkIdentityGoToZkPassport => 'ZK Passport로 이동';

  @override
  String get zkIdentityTryAgain => '다시 시도';

  @override
  String get zkIdentityWalletClaimTitle => '프로그램 지갑 연결';

  @override
  String get zkIdentityWalletClaimDescription =>
      '이 Social 계정은 기존 지갑이 있는 계정과 다릅니다. 연결하려면 처음 가입한 프로그램의 이메일을 한 번 인증하세요.';

  @override
  String get zkIdentityWalletClaimEmailLabel => '처음 가입한 프로그램의 이메일';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      '처음 Homeroom 프로그램에 등록할 때 사용한 이메일을 입력하세요.';

  @override
  String get zkIdentityWalletClaimSendCode => '인증 코드 보내기';

  @override
  String get zkIdentityWalletClaimSendingCode => '코드를 보내는 중…';

  @override
  String get zkIdentityWalletClaimCodeSent => '해당 이메일로 보낸 6자리 코드를 입력하세요.';

  @override
  String get zkIdentityWalletClaimCodeLabel => '인증 코드';

  @override
  String get zkIdentityWalletClaimConnect => '지갑 연결하고 계속';

  @override
  String get zkIdentityWalletClaimConnecting => '지갑을 연결하는 중…';

  @override
  String get zkIdentityWalletClaimChangeEmail => '다른 이메일 사용';

  @override
  String get zkIdentityWalletClaimEmailRequired => '올바른 이메일 주소를 입력하세요.';

  @override
  String get zkIdentityWalletClaimCodeRequired => '6자리 코드를 입력하세요.';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      '지갑은 연결되었지만 앱에서 준비를 마치지 못했습니다. 다시 시도하세요.';

  @override
  String get zkIdentityDone => '완료';

  @override
  String get zkIdentityStatusFaceMatchVerified => '확인됨';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => '건너뜀';

  @override
  String get zkIdentityStatusPrivacyLabel => '개인정보';

  @override
  String get zkIdentityStatusVerifiedDateLabel => '인증 일시';

  @override
  String get zkIdentityStatusProofIdLabel => '증명 ID';

  @override
  String get zkIdentityStatusVerifyDurationLabel => '인증';

  @override
  String get zkIdentityStatusWrapDurationLabel => '포장';

  @override
  String get zkIdentityStatusFinalCheckLabel => '최종 확인';

  @override
  String get zkIdentityResultFailureTitle => '인증할 수 없습니다';

  @override
  String get zkIdentityResultFailureSubtitle => '이름, 사진, 신분증은 공유되지 않았습니다';

  @override
  String get commonCancel => '취소';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonCopied => '복사됨';

  @override
  String get buildInfoAppVersion => '앱 버전';

  @override
  String get buildInfoBuildNumber => '빌드 번호';

  @override
  String get settingsDebugMode => '디버그 모드';

  @override
  String get settingsDebugModeEnabled => 'HTTP 요청을 메모리에 기록하는 중';

  @override
  String get settingsDebugModeDisabled => '꺼짐 · 네트워크 로그 없음';

  @override
  String get settingsHttpLogs => 'HTTP 로그';

  @override
  String get settingsHttpLogsSubtitle => '기록된 네트워크 요청 보기';

  @override
  String get httpLogsTitle => 'HTTP 로그';

  @override
  String get httpLogsEmpty =>
      '아직 기록된 요청이 없습니다. 네트워크를 사용하는 동작을 하면 로그가 여기에 표시됩니다.';

  @override
  String get httpLogsCopy => '모두 복사';

  @override
  String get httpLogsClear => '지우기';

  @override
  String get httpLogsCopied => '로그를 클립보드에 복사했습니다';

  @override
  String get httpLogsShare => '팀과 로그 공유';

  @override
  String get httpLogsSharing => '30초마다 팀과 로그를 공유하는 중…';

  @override
  String get httpLogsStopSharing => '공유 중지';

  @override
  String get httpLogsShareStopped => '서버가 로그 공유를 중지했습니다. 언제든 다시 공유할 수 있습니다.';

  @override
  String get httpLogsShareNoParticipant =>
      '아직 참가자 ID가 없습니다. 로그를 공유하려면 온보딩을 완료하세요';

  @override
  String get httpLogsFilterHint => 'URL로 필터링';

  @override
  String get httpLogsNoMatches => '필터와 일치하는 요청이 없습니다.';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$total개 중 $count개';
  }

  @override
  String get widgetInstructionsTitle => 'Homeroom 위젯 추가';

  @override
  String widgetInstructionsBody(String name) {
    return '$name이(가) Homeroom dApps 위젯에 추가되었습니다. 홈 화면에서 보려면 위젯을 한 번 추가하세요.';
  }

  @override
  String get widgetInstructionsStep1 => '홈 화면의 빈 곳을 길게 누릅니다';

  @override
  String get widgetInstructionsStep2 => '모서리의 편집을 탭한 다음 위젯 추가를 탭합니다';

  @override
  String get widgetInstructionsStep3 => 'Homeroom을 검색해 dApps 위젯을 추가합니다';

  @override
  String get widgetInstructionsDone => '완료';

  @override
  String get svShellConnectingTitle => 'Homeroom에 연결하는 중…';

  @override
  String get svShellOfflineMessage =>
      'Homeroom에 연결할 수 없습니다. 네트워크 연결을 확인하고 다시 시도하세요.';

  @override
  String get stakingManagerTitle => '스테이킹 모드';

  @override
  String get stakingDelegateIntro =>
      '스테이크를 서버에 위임하세요. 노드는 계속 실행되지만, 스테이킹은 서버가 대신 합니다.';

  @override
  String get stakingServerName => '서버';

  @override
  String get stakingDelegateEffect =>
      '노드가 블록 생성을 멈춥니다. 위임하는 동안에는 이 휴대폰에서 직접 블록을 생성할 때 얻는 블록 생성 포인트의 절반을 받습니다.';

  @override
  String get stakingDelegateNote => '언제든 직접 스테이킹으로 돌아올 수 있습니다.';

  @override
  String get stakingDelegateConfirm => '위임 확인';

  @override
  String get stakingDelegating => '위임하는 중…';

  @override
  String get stakingDelegateError => '위임을 제출할 수 없습니다. 네트워크 연결을 확인하고 다시 시도하세요.';

  @override
  String get stakingDelegationActiveTitle => '위임 중';

  @override
  String stakingDelegationActiveBody(String validator) {
    return '스테이크가 $validator에게 위임되어 있습니다. 이 휴대폰에서 직접 블록을 생성할 때 얻는 블록 생성 포인트의 절반을 받습니다.';
  }

  @override
  String get stakingDone => '완료';

  @override
  String get stakingUndelegateTitle => '위임을 중지할까요?';

  @override
  String get stakingUndelegateBody =>
      '스테이크가 이 휴대폰으로 돌아옵니다. 노드가 직접 블록을 생성하고 블록 생성 포인트를 전부 받습니다.';

  @override
  String get stakingUndelegateConfirm => '위임 중지';

  @override
  String get stakingUndelegateError =>
      '위임을 중지할 수 없습니다. 네트워크 연결을 확인하고 다시 시도하세요.';

  @override
  String get versionUpdateRequiredTitle => '업데이트 필요';

  @override
  String get versionUpdateAvailableTitle => '업데이트 가능';

  @override
  String get versionUpdateAction => '업데이트';

  @override
  String get versionUpdateLater => '나중에';

  @override
  String get versionUpdateFallbackMessage => '앱의 새 버전이 있습니다.';

  @override
  String get commonBack => '뒤로';

  @override
  String get commonDeny => '거부';

  @override
  String get commonConfirm => '확인';

  @override
  String get commonApprove => '승인';

  @override
  String get txConfirmTitle => '트랜잭션 확인';

  @override
  String get txConfirmSubtitleDefault => 'dApp이 트랜잭션 전송을 요청하고 있습니다.';

  @override
  String get txAmount => '금액';

  @override
  String get txDetails => '세부 정보';

  @override
  String get txFrom => '보내는 주소';

  @override
  String get txTo => '받는 주소';

  @override
  String get txFee => '수수료';

  @override
  String get txMemo => '메모';

  @override
  String get verifyIdentityTitle => '본인 확인';

  @override
  String verifyIdentityRequest(String name) {
    return '$name이(가) 본인 확인을 요청하고 있습니다';
  }

  @override
  String get verifyIdentityExplanation =>
      '이 지갑의 소유자임을 증명하기 위해 개인 키로 챌린지에 서명합니다. 트랜잭션은 전송되지 않으며 토큰도 사용되지 않습니다.';

  @override
  String get zkChallengeBusy => 'zkPassport 증명을 아직 처리하는 중입니다. 잠시 후 다시 시도하세요.';

  @override
  String get zkChallengeResetDone => 'ZK 증명 상태를 초기화했습니다';

  @override
  String provingParametersDownloadProgress(int percent) {
    return '증명 도구 준비 중: $percent%. 다운로드한 데이터는 나중에 사용할 수 있도록 저장됩니다.';
  }

  @override
  String get provingParametersDownloadFailed =>
      '증명 도구를 다운로드하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.';
}
