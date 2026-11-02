// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline => 'AI 构建应用,\n现在支持多人协作。';

  @override
  String get initializingNode => '正在启动…';

  @override
  String get resumeSplashLoading => '加载中…';

  @override
  String get clockDriftWarningTitle => '系统时间不正确';

  @override
  String clockDriftWarningBody(String drift) {
    return '你设备的时钟与节点时钟相差 $drift。在系统时间校正之前,应用可能出现一些不一致的情况。';
  }

  @override
  String get clockDriftWarningInstruction => '请在设备上开启自动同步时间。';

  @override
  String get clockDriftRecommendationTitle => '建议';

  @override
  String get clockDriftRecommendationBody =>
      '为尽量减小时间偏差,请在设置中保持开启“自动设置日期和时间”和“自动设置时区”,设备会从网络获取时间。';

  @override
  String get clockDriftDismiss => '好';

  @override
  String clockDriftAhead(String seconds) {
    return '快 $seconds 秒';
  }

  @override
  String clockDriftBehind(String seconds) {
    return '慢 $seconds 秒';
  }

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsBuildInfo => '构建信息';

  @override
  String get settingsDiagnostics => '诊断';

  @override
  String get settingsDeviceBenchmark => '设备性能测试';

  @override
  String get settingsDeviceBenchmarkSubtitle => '在设备上运行性能测量';

  @override
  String get perfTitle => '设备性能测试';

  @override
  String get perfIntroTitle => '在此设备上运行性能测试';

  @override
  String get perfIntroDescription => '测量哈希、部分同步、区块生产和钱包转账等工作负载,了解此设备的表现。';

  @override
  String get perfIntroNote => '目前结果仅保存在此设备上。性能会受电量、温度和后台活动影响。';

  @override
  String get perfCatalogLoadError => '无法加载测试目录。';

  @override
  String get perfCatalogLoading => '正在加载测试目录…';

  @override
  String get perfProfileQuick => '快速检测';

  @override
  String get perfProfileStandard => '完整测试';

  @override
  String perfRunProfile(String profile) {
    return '运行$profile';
  }

  @override
  String perfStepCount(int count) {
    return '$count 个步骤';
  }

  @override
  String get perfCurrentRunTitle => '当前运行';

  @override
  String get perfRunInProgressTitle => '测试进行中';

  @override
  String perfRunInProgressDescription(String profile) {
    return '此设备上已有一项$profile正在运行。';
  }

  @override
  String get perfRunInProgressDescriptionUnknown => '此设备上已有一项测试正在运行。';

  @override
  String get perfOpenCurrentRun => '打开当前运行';

  @override
  String get perfLatestResultsTitle => '最新结果';

  @override
  String perfLatestResultsDescription(String profile) {
    return '$profile的结果已可查看。';
  }

  @override
  String get perfLatestResultsDescriptionUnknown => '测试结果已可查看。';

  @override
  String get perfViewLatestResults => '查看最新结果';

  @override
  String get perfNoRunAvailableTitle => '暂无测试';

  @override
  String get perfNoRunAvailableDescription => '在测试页面开始一项测试,即可在这里查看进度或结果。';

  @override
  String get perfBackToBenchmarks => '返回测试';

  @override
  String get perfRunPausedNodeNotice => '此测试运行期间,后台节点已暂停。';

  @override
  String get perfStateRunning => '运行中';

  @override
  String get perfStateStarting => '正在开始';

  @override
  String get perfStateCompleted => '已完成';

  @override
  String get perfStateFailed => '失败';

  @override
  String get perfStateCancelled => '已取消';

  @override
  String perfProgressValue(int completed, int total) {
    return '第 $completed 步,共 $total 步';
  }

  @override
  String perfPreparingProfile(String profile) {
    return '正在准备$profile';
  }

  @override
  String perfCurrentStep(String label) {
    return '当前步骤:$label';
  }

  @override
  String perfElapsed(String duration) {
    return '已用时:$duration';
  }

  @override
  String get perfResultsTitle => '结果';

  @override
  String get perfResultProfile => '配置';

  @override
  String get perfResultDevice => '设备';

  @override
  String get perfResultOperatingSystem => '系统';

  @override
  String get perfResultCpu => 'CPU';

  @override
  String get perfResultLogicalCores => '逻辑核心数';

  @override
  String get perfResultMeasurements => '测量值';

  @override
  String get perfSuitePrimitives => '基础运算';

  @override
  String get perfSuitePartialSync => '部分同步';

  @override
  String get perfSuitePartialBlockProduction => '区块生产';

  @override
  String get perfSuiteWalletSend => '钱包转账';

  @override
  String get perfScenarioDefault => '默认情形';

  @override
  String perfContextTxCount(int count) {
    return '$count 笔交易';
  }

  @override
  String perfContextBatchLayout(String value) {
    return '布局 $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return '形态 $value';
  }

  @override
  String get perfDetailScenario => '场景';

  @override
  String get perfDetailAverage => '平均值';

  @override
  String get perfDetailMinMax => '最小 / 最大';

  @override
  String get perfDetailRuns => '运行次数';

  @override
  String get perfDetailMetadataTitle => '场景详情';

  @override
  String get perfDetailImplementationTitle => '实现详情';

  @override
  String get perfDetailNotesTitle => '备注';

  @override
  String get perfDetailFlow => '流程';

  @override
  String get perfDetailTxCount => '交易数量';

  @override
  String get perfDetailBatchLayout => '批处理布局';

  @override
  String get perfDetailTransactionShape => '交易形态';

  @override
  String get perfDetailTouchedLeaves => '访问的叶节点';

  @override
  String get perfDetailProofNodes => '证明节点';

  @override
  String get perfDetailProofSize => '证明大小';

  @override
  String get perfCancelFailed => '无法取消当前测试。';

  @override
  String get perfRunUnavailable => '此测试已不可用。';

  @override
  String get commonOk => '好';

  @override
  String get buildInfoVersion => '版本';

  @override
  String get buildInfoCommit => '提交';

  @override
  String get buildInfoBranch => '分支';

  @override
  String get buildInfoCommitTime => '提交时间';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Cargo 目标';

  @override
  String get buildInfoFeatures => '功能';

  @override
  String get buildInfoOptLevel => '优化级别';

  @override
  String get buildInfoDebug => '调试';

  @override
  String get retry => '重试';

  @override
  String get zkIdentityAppNotFoundTitle => '请先安装 ZK Passport';

  @override
  String get zkIdentityAppNotFoundDetail => '它会生成你的证明,然后带你回到这里';

  @override
  String get zkIdentityInstallCta => '安装';

  @override
  String get zkIdentityStepLabelOpenApp => '正在打开 ZK Passport';

  @override
  String get zkIdentityStepDescOpenApp => '正在用你保存的护照准备证明请求';

  @override
  String get zkIdentityCheckAppCta => '继续';

  @override
  String get zkIdentityAccountPreparingTitle => '正在准备你的账号';

  @override
  String get zkIdentityAccountPreparingDescription =>
      '正在连接你已登录的 Social Vibecoding 账号';

  @override
  String get zkIdentityAccountUnavailable => '开始验证前,请先登录 Social Vibecoding。';

  @override
  String get zkIdentityStepLabelScan => '使用已保存的护照';

  @override
  String get zkIdentityStepDescScan => '使用 ZK Passport 中已存储的护照';

  @override
  String get zkIdentityConfirmScannedBody => '将使用你已保存的护照。';

  @override
  String get zkIdentityConfirmScannedYesCta => '继续';

  @override
  String get zkIdentityConfirmScannedNoCta => '暂不';

  @override
  String get zkIdentityStepLabelReady => '生成证明';

  @override
  String get zkIdentityStepDescReady => 'ZK Passport 会请你批准并生成证明';

  @override
  String get zkIdentityReadyBody => 'ZK Passport 会根据你已保存的护照在约一分钟内生成证明。';

  @override
  String get zkIdentityReadyBullet1 => '不会分享姓名、照片或证件';

  @override
  String get zkIdentityReadyBullet2 => '你只发送一份证明';

  @override
  String get zkIdentityReadyBullet3 => '链上不会存储任何个人信息';

  @override
  String get zkIdentityReadyCta => '打开 ZK Passport';

  @override
  String get zkIdentityStepLabelVerifying => '验证中';

  @override
  String get zkIdentityStepDescVerifying => '正在生成并检查你的证明';

  @override
  String get zkIdentityStepLabelResult => '结果';

  @override
  String get zkIdentityStepDescResult => '查看验证结果';

  @override
  String get zkIdentitySubTaskOpening => '正在打开 ZK Passport';

  @override
  String get zkIdentitySubTaskWaiting => '正在等待你的证明';

  @override
  String get zkIdentitySubTaskChecking => '正在检查你的证明';

  @override
  String get zkIdentitySubTaskWrapping => '正在封装你的证明';

  @override
  String get zkIdentitySubTaskFinal => '最终检查';

  @override
  String get zkIdentityResultSuccessTitle => '你是独一无二的真人!';

  @override
  String get zkIdentityResultSuccessSubtitle => '你在不分享姓名、照片或证件的前提下证明了自己的唯一性';

  @override
  String get zkIdentityStatusUniqueness => '唯一真人';

  @override
  String get zkIdentityStatusUniquenessValue => '已确认';

  @override
  String get zkIdentityStatusFaceMatchLabel => '人脸检查';

  @override
  String get zkIdentityStatusPrivacyValue => '未分享任何信息';

  @override
  String get zkIdentityCancelVerification => '取消';

  @override
  String get zkIdentityGoToZkPassport => '前往 ZK Passport';

  @override
  String get zkIdentityTryAgain => '重试';

  @override
  String get zkIdentityWalletClaimTitle => '连接你的活动钱包';

  @override
  String get zkIdentityWalletClaimDescription =>
      '这个 Social 账号与持有你现有钱包的账号不同。请验证一次你最初的活动邮箱来完成连接。';

  @override
  String get zkIdentityWalletClaimEmailLabel => '最初的活动邮箱';

  @override
  String get zkIdentityWalletClaimEmailHelper => '请使用你注册最初 Homeroom 活动时的邮箱。';

  @override
  String get zkIdentityWalletClaimSendCode => '发送验证码';

  @override
  String get zkIdentityWalletClaimSendingCode => '正在发送验证码…';

  @override
  String get zkIdentityWalletClaimCodeSent => '请输入发送到该邮箱的 6 位验证码。';

  @override
  String get zkIdentityWalletClaimCodeLabel => '验证码';

  @override
  String get zkIdentityWalletClaimConnect => '连接钱包并继续';

  @override
  String get zkIdentityWalletClaimConnecting => '正在连接钱包…';

  @override
  String get zkIdentityWalletClaimChangeEmail => '使用其他邮箱';

  @override
  String get zkIdentityWalletClaimEmailRequired => '请输入有效的邮箱地址。';

  @override
  String get zkIdentityWalletClaimCodeRequired => '请输入 6 位验证码。';

  @override
  String get zkIdentityWalletClaimRetryFailed => '你的钱包已连接,但应用未能完成准备。请重试。';

  @override
  String get zkIdentityDone => '完成';

  @override
  String get zkIdentityStatusFaceMatchVerified => '已验证';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => '已跳过';

  @override
  String get zkIdentityStatusPrivacyLabel => '隐私';

  @override
  String get zkIdentityStatusVerifiedDateLabel => '验证时间';

  @override
  String get zkIdentityStatusProofIdLabel => '证明 ID';

  @override
  String get zkIdentityStatusVerifyDurationLabel => '验证';

  @override
  String get zkIdentityStatusWrapDurationLabel => '封装';

  @override
  String get zkIdentityStatusFinalCheckLabel => '最终检查';

  @override
  String get zkIdentityResultFailureTitle => '无法验证';

  @override
  String get zkIdentityResultFailureSubtitle => '你没有分享姓名、照片或证件';

  @override
  String get commonCancel => '取消';

  @override
  String get commonRetry => '重试';

  @override
  String get commonCopied => '已复制';

  @override
  String get buildInfoAppVersion => '应用版本';

  @override
  String get buildInfoBuildNumber => '构建号';

  @override
  String get settingsDebugMode => '调试模式';

  @override
  String get settingsDebugModeEnabled => '正在将 HTTP 请求记录到内存';

  @override
  String get settingsDebugModeDisabled => '已关闭 · 不记录网络日志';

  @override
  String get settingsHttpLogs => 'HTTP 日志';

  @override
  String get settingsHttpLogsSubtitle => '查看已捕获的网络请求';

  @override
  String get httpLogsTitle => 'HTTP 日志';

  @override
  String get httpLogsEmpty => '尚未捕获任何请求。进行一些网络操作后,日志会显示在这里。';

  @override
  String get httpLogsCopy => '全部复制';

  @override
  String get httpLogsClear => '清除';

  @override
  String get httpLogsCopied => '日志已复制到剪贴板';

  @override
  String get httpLogsShare => '与团队分享日志';

  @override
  String get httpLogsSharing => '每 30 秒与团队分享一次日志…';

  @override
  String get httpLogsStopSharing => '停止分享';

  @override
  String get httpLogsShareStopped => '服务器已停止日志分享。你可以随时重新开始分享。';

  @override
  String get httpLogsShareNoParticipant => '还没有参与者 ID——完成引导后才能分享日志';

  @override
  String get httpLogsFilterHint => '按 URL 筛选';

  @override
  String get httpLogsNoMatches => '没有符合筛选条件的请求。';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$count / $total';
  }

  @override
  String get widgetInstructionsTitle => '添加 Homeroom 小组件';

  @override
  String widgetInstructionsBody(String name) {
    return '$name 已添加到你的 Homeroom dApps 小组件。要在主屏幕上看到它,请添加一次小组件:';
  }

  @override
  String get widgetInstructionsStep1 => '长按主屏幕上的空白区域';

  @override
  String get widgetInstructionsStep2 => '点按角落处的“编辑”,然后选择“添加小组件”';

  @override
  String get widgetInstructionsStep3 => '搜索 Homeroom 并添加 dApps 小组件';

  @override
  String get widgetInstructionsDone => '完成';

  @override
  String get svShellConnectingTitle => '正在连接 Homeroom…';

  @override
  String get svShellOfflineMessage => '无法连接 Homeroom。请检查网络后重试。';

  @override
  String get stakingManagerTitle => '质押模式';

  @override
  String get stakingDelegateIntro => '将你的质押委托给服务器。你的节点会继续运行,但由服务器代你进行质押。';

  @override
  String get stakingServerName => '服务器';

  @override
  String get stakingDelegateEffect =>
      '你的节点将停止生产区块。委托期间,你可获得的区块生产积分是在这部手机上直接生产区块所能获得的一半。';

  @override
  String get stakingDelegateNote => '你可以随时改回自己质押。';

  @override
  String get stakingDelegateConfirm => '确认委托';

  @override
  String get stakingDelegating => '正在委托…';

  @override
  String get stakingDelegateError => '无法提交委托。请检查网络后重试。';

  @override
  String get stakingDelegationActiveTitle => '委托已生效';

  @override
  String stakingDelegationActiveBody(String validator) {
    return '你的质押已委托给 $validator。你可获得的区块生产积分是在这部手机上直接生产区块所能获得的一半。';
  }

  @override
  String get stakingDone => '完成';

  @override
  String get stakingUndelegateTitle => '停止委托?';

  @override
  String get stakingUndelegateBody => '你的质押将回到这部手机。你的节点将直接生产区块,并获得全部区块生产积分。';

  @override
  String get stakingUndelegateConfirm => '停止委托';

  @override
  String get stakingUndelegateError => '无法停止委托。请检查网络后重试。';

  @override
  String get versionUpdateRequiredTitle => '需要更新';

  @override
  String get versionUpdateAvailableTitle => '有可用更新';

  @override
  String get versionUpdateAction => '更新';

  @override
  String get versionUpdateLater => '稍后';

  @override
  String get versionUpdateFallbackMessage => '应用有新版本可用。';

  @override
  String get commonBack => '返回';

  @override
  String get commonDeny => '拒绝';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonApprove => '批准';

  @override
  String get txConfirmTitle => '确认交易';

  @override
  String get txConfirmSubtitleDefault => '某个 dapp 请求发送一笔交易。';

  @override
  String get txAmount => '金额';

  @override
  String get txDetails => '详情';

  @override
  String get txFrom => '发送方';

  @override
  String get txTo => '接收方';

  @override
  String get txFee => '手续费';

  @override
  String get txMemo => '备注';

  @override
  String get verifyIdentityTitle => '验证身份';

  @override
  String verifyIdentityRequest(String name) {
    return '$name 请求验证你的身份';
  }

  @override
  String get verifyIdentityExplanation =>
      '这将使用你的私钥对一条挑战信息签名,以证明你拥有此钱包。不会发送任何交易,也不会花费任何代币。';

  @override
  String get zkChallengeBusy => '仍在处理 zkPassport 证明。请稍后再试。';

  @override
  String get zkChallengeResetDone => 'ZK 证明状态已重置';
}
