// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline =>
      'Xây dựng ứng dụng bằng AI,\nGiờ đây nhiều người cùng chơi.';

  @override
  String get initializingNode => 'Đang khởi động…';

  @override
  String get resumeSplashLoading => 'Đang tải…';

  @override
  String get clockDriftWarningTitle => 'Giờ hệ thống không chính xác';

  @override
  String clockDriftWarningBody(String drift) {
    return 'Đồng hồ thiết bị của bạn lệch $drift so với đồng hồ của nút. Bạn có thể thấy một số điểm không nhất quán trong ứng dụng cho đến khi giờ hệ thống được chỉnh lại.';
  }

  @override
  String get clockDriftWarningInstruction =>
      'Hãy bật đồng bộ giờ tự động trên thiết bị.';

  @override
  String get clockDriftRecommendationTitle => 'Khuyến nghị';

  @override
  String get clockDriftRecommendationBody =>
      'Để độ lệch thấp nhất, hãy luôn bật \"Ngày và giờ tự động\" và \"Múi giờ tự động\" trong phần cài đặt, để thiết bị lấy giờ từ mạng.';

  @override
  String get clockDriftDismiss => 'OK';

  @override
  String clockDriftAhead(String seconds) {
    return 'Nhanh $seconds giây';
  }

  @override
  String clockDriftBehind(String seconds) {
    return 'Chậm $seconds giây';
  }

  @override
  String get settingsAbout => 'Giới thiệu';

  @override
  String get settingsBuildInfo => 'Thông tin bản dựng';

  @override
  String get settingsDiagnostics => 'Chẩn đoán';

  @override
  String get settingsDeviceBenchmark => 'Kiểm tra hiệu năng thiết bị';

  @override
  String get settingsDeviceBenchmarkSubtitle =>
      'Chạy các phép đo hiệu năng trên thiết bị';

  @override
  String get perfTitle => 'Kiểm tra hiệu năng thiết bị';

  @override
  String get perfIntroTitle => 'Chạy kiểm tra hiệu năng trên thiết bị này';

  @override
  String get perfIntroDescription =>
      'Đo các tác vụ băm, đồng bộ một phần, tạo khối và gửi từ ví để xem thiết bị này hoạt động ra sao.';

  @override
  String get perfIntroNote =>
      'Hiện tại, kết quả chỉ được lưu trên thiết bị này. Hiệu năng có thể thay đổi theo mức pin, nhiệt độ và hoạt động nền.';

  @override
  String get perfCatalogLoadError => 'Không thể tải danh mục kiểm tra.';

  @override
  String get perfCatalogLoading => 'Đang tải danh mục kiểm tra…';

  @override
  String get perfProfileQuick => 'Kiểm tra nhanh';

  @override
  String get perfProfileStandard => 'Kiểm tra đầy đủ';

  @override
  String perfRunProfile(String profile) {
    return 'Chạy $profile';
  }

  @override
  String perfStepCount(int count) {
    return '$count bước';
  }

  @override
  String get perfCurrentRunTitle => 'Lần chạy hiện tại';

  @override
  String get perfRunInProgressTitle => 'Đang chạy kiểm tra';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'Một lần kiểm tra $profile đang chạy trên thiết bị này.';
  }

  @override
  String get perfRunInProgressDescriptionUnknown =>
      'Một lần kiểm tra đang chạy trên thiết bị này.';

  @override
  String get perfOpenCurrentRun => 'Mở lần chạy hiện tại';

  @override
  String get perfLatestResultsTitle => 'Kết quả mới nhất';

  @override
  String perfLatestResultsDescription(String profile) {
    return 'Kết quả $profile đã sẵn sàng để xem.';
  }

  @override
  String get perfLatestResultsDescriptionUnknown =>
      'Kết quả kiểm tra đã sẵn sàng để xem.';

  @override
  String get perfViewLatestResults => 'Xem kết quả mới nhất';

  @override
  String get perfNoRunAvailableTitle => 'Chưa có lần kiểm tra nào';

  @override
  String get perfNoRunAvailableDescription =>
      'Hãy bắt đầu kiểm tra từ màn hình kiểm tra để xem tiến độ hoặc kết quả tại đây.';

  @override
  String get perfBackToBenchmarks => 'Quay lại màn hình kiểm tra';

  @override
  String get perfRunPausedNodeNotice =>
      'Nút chạy nền được tạm dừng trong khi kiểm tra này chạy.';

  @override
  String get perfStateRunning => 'Đang chạy';

  @override
  String get perfStateStarting => 'Đang bắt đầu';

  @override
  String get perfStateCompleted => 'Đã hoàn tất';

  @override
  String get perfStateFailed => 'Thất bại';

  @override
  String get perfStateCancelled => 'Đã hủy';

  @override
  String perfProgressValue(int completed, int total) {
    return '$completed/$total bước';
  }

  @override
  String perfPreparingProfile(String profile) {
    return 'Đang chuẩn bị $profile';
  }

  @override
  String perfCurrentStep(String label) {
    return 'Bước hiện tại: $label';
  }

  @override
  String perfElapsed(String duration) {
    return 'Đã trôi qua: $duration';
  }

  @override
  String get perfResultsTitle => 'Kết quả';

  @override
  String get perfResultProfile => 'Cấu hình';

  @override
  String get perfResultDevice => 'Thiết bị';

  @override
  String get perfResultOperatingSystem => 'Hệ điều hành';

  @override
  String get perfResultCpu => 'CPU';

  @override
  String get perfResultLogicalCores => 'Nhân logic';

  @override
  String get perfResultMeasurements => 'Số đo';

  @override
  String get perfSuitePrimitives => 'Tác vụ cơ bản';

  @override
  String get perfSuitePartialSync => 'Đồng bộ một phần';

  @override
  String get perfSuitePartialBlockProduction => 'Tạo khối';

  @override
  String get perfSuiteWalletSend => 'Gửi từ ví';

  @override
  String get perfScenarioDefault => 'Trường hợp mặc định';

  @override
  String perfContextTxCount(int count) {
    return '$count giao dịch';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'Bố cục $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return 'Dạng $value';
  }

  @override
  String get perfDetailScenario => 'Kịch bản';

  @override
  String get perfDetailAverage => 'Trung bình';

  @override
  String get perfDetailMinMax => 'Nhỏ nhất / Lớn nhất';

  @override
  String get perfDetailRuns => 'Số lần chạy';

  @override
  String get perfDetailMetadataTitle => 'Chi tiết kịch bản';

  @override
  String get perfDetailImplementationTitle => 'Chi tiết triển khai';

  @override
  String get perfDetailNotesTitle => 'Ghi chú';

  @override
  String get perfDetailFlow => 'Luồng';

  @override
  String get perfDetailTxCount => 'Số giao dịch';

  @override
  String get perfDetailBatchLayout => 'Bố cục lô';

  @override
  String get perfDetailTransactionShape => 'Dạng giao dịch';

  @override
  String get perfDetailTouchedLeaves => 'Lá được truy cập';

  @override
  String get perfDetailProofNodes => 'Nút bằng chứng';

  @override
  String get perfDetailProofSize => 'Kích thước bằng chứng';

  @override
  String get perfCancelFailed => 'Không thể hủy lần kiểm tra đang chạy.';

  @override
  String get perfRunUnavailable => 'Lần kiểm tra này không còn nữa.';

  @override
  String get commonOk => 'OK';

  @override
  String get buildInfoVersion => 'Phiên bản';

  @override
  String get buildInfoCommit => 'Commit';

  @override
  String get buildInfoBranch => 'Nhánh';

  @override
  String get buildInfoCommitTime => 'Thời gian commit';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Mục tiêu Cargo';

  @override
  String get buildInfoFeatures => 'Tính năng';

  @override
  String get buildInfoOptLevel => 'Mức tối ưu hóa';

  @override
  String get buildInfoDebug => 'Debug';

  @override
  String get retry => 'Thử lại';

  @override
  String get zkIdentityAppNotFoundTitle => 'Hãy cài ZK Passport trước';

  @override
  String get zkIdentityAppNotFoundDetail =>
      'Ứng dụng này tạo bằng chứng của bạn rồi đưa bạn quay lại đây';

  @override
  String get zkIdentityInstallCta => 'Cài đặt';

  @override
  String get zkIdentityStepLabelOpenApp => 'Đang mở ZK Passport';

  @override
  String get zkIdentityStepDescOpenApp =>
      'Đang chuẩn bị yêu cầu bằng chứng với hộ chiếu đã lưu của bạn';

  @override
  String get zkIdentityCheckAppCta => 'Tiếp tục';

  @override
  String get zkIdentityAccountPreparingTitle =>
      'Đang chuẩn bị tài khoản của bạn';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'Đang kết nối tài khoản Social Vibecoding bạn đã đăng nhập';

  @override
  String get zkIdentityAccountUnavailable =>
      'Hãy đăng nhập Social Vibecoding trước khi bắt đầu xác minh.';

  @override
  String get zkIdentityStepLabelScan => 'Dùng hộ chiếu đã lưu';

  @override
  String get zkIdentityStepDescScan =>
      'Dùng hộ chiếu đã lưu sẵn trong ZK Passport';

  @override
  String get zkIdentityConfirmScannedBody =>
      'Hộ chiếu đã lưu của bạn sẽ được sử dụng.';

  @override
  String get zkIdentityConfirmScannedYesCta => 'Tiếp tục';

  @override
  String get zkIdentityConfirmScannedNoCta => 'Chưa phải lúc';

  @override
  String get zkIdentityStepLabelReady => 'Tạo bằng chứng';

  @override
  String get zkIdentityStepDescReady =>
      'ZK Passport sẽ yêu cầu bạn chấp thuận và tạo bằng chứng';

  @override
  String get zkIdentityReadyBody =>
      'ZK Passport tạo bằng chứng từ hộ chiếu đã lưu của bạn trong khoảng một phút.';

  @override
  String get zkIdentityReadyBullet1 =>
      'Không chia sẻ tên, ảnh hay giấy tờ tùy thân';

  @override
  String get zkIdentityReadyBullet2 => 'Bạn chỉ gửi một bằng chứng';

  @override
  String get zkIdentityReadyBullet3 =>
      'Không có thông tin cá nhân nào được lưu trên chuỗi';

  @override
  String get zkIdentityReadyCta => 'Mở ZK Passport';

  @override
  String get zkIdentityStepLabelVerifying => 'Đang xác minh';

  @override
  String get zkIdentityStepDescVerifying =>
      'Đang tạo và kiểm tra bằng chứng của bạn';

  @override
  String get zkIdentityStepLabelResult => 'Kết quả';

  @override
  String get zkIdentityStepDescResult => 'Xem kết quả xác minh của bạn';

  @override
  String get zkIdentitySubTaskOpening => 'Đang mở ZK Passport';

  @override
  String get zkIdentitySubTaskWaiting => 'Đang chờ bằng chứng của bạn';

  @override
  String get zkIdentitySubTaskChecking => 'Đang kiểm tra bằng chứng của bạn';

  @override
  String get zkIdentitySubTaskWrapping => 'Đang đóng gói bằng chứng của bạn';

  @override
  String get zkIdentitySubTaskFinal => 'Kiểm tra cuối cùng';

  @override
  String get zkIdentityResultSuccessTitle => 'Bạn là một con người duy nhất!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      'Bạn đã chứng minh mình là duy nhất mà không chia sẻ tên, ảnh hay giấy tờ tùy thân';

  @override
  String get zkIdentityStatusUniqueness => 'Con người duy nhất';

  @override
  String get zkIdentityStatusUniquenessValue => 'Đã xác nhận';

  @override
  String get zkIdentityStatusFaceMatchLabel => 'Kiểm tra khuôn mặt';

  @override
  String get zkIdentityStatusPrivacyValue => 'Không chia sẻ gì';

  @override
  String get zkIdentityCancelVerification => 'Hủy';

  @override
  String get zkIdentityGoToZkPassport => 'Chuyển sang ZK Passport';

  @override
  String get zkIdentityTryAgain => 'Thử lại';

  @override
  String get zkIdentityWalletClaimTitle => 'Kết nối ví chương trình của bạn';

  @override
  String get zkIdentityWalletClaimDescription =>
      'Tài khoản Social này khác với tài khoản đang giữ ví hiện có của bạn. Hãy xác minh email chương trình ban đầu một lần để kết nối.';

  @override
  String get zkIdentityWalletClaimEmailLabel => 'Email chương trình ban đầu';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      'Dùng email bạn đã đăng ký chương trình Homeroom ban đầu.';

  @override
  String get zkIdentityWalletClaimSendCode => 'Gửi mã xác minh';

  @override
  String get zkIdentityWalletClaimSendingCode => 'Đang gửi mã…';

  @override
  String get zkIdentityWalletClaimCodeSent =>
      'Nhập mã gồm 6 chữ số đã gửi đến email đó.';

  @override
  String get zkIdentityWalletClaimCodeLabel => 'Mã xác minh';

  @override
  String get zkIdentityWalletClaimConnect => 'Kết nối ví và tiếp tục';

  @override
  String get zkIdentityWalletClaimConnecting => 'Đang kết nối ví…';

  @override
  String get zkIdentityWalletClaimChangeEmail => 'Dùng email khác';

  @override
  String get zkIdentityWalletClaimEmailRequired => 'Nhập địa chỉ email hợp lệ.';

  @override
  String get zkIdentityWalletClaimCodeRequired => 'Nhập mã gồm 6 chữ số.';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'Ví của bạn đã được kết nối, nhưng ứng dụng không thể hoàn tất việc chuẩn bị. Hãy thử lại.';

  @override
  String get zkIdentityDone => 'Xong';

  @override
  String get zkIdentityStatusFaceMatchVerified => 'Đã xác minh';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'Đã bỏ qua';

  @override
  String get zkIdentityStatusPrivacyLabel => 'Quyền riêng tư';

  @override
  String get zkIdentityStatusVerifiedDateLabel => 'Xác minh vào';

  @override
  String get zkIdentityStatusProofIdLabel => 'ID bằng chứng';

  @override
  String get zkIdentityStatusVerifyDurationLabel => 'Xác minh';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'Đóng gói';

  @override
  String get zkIdentityStatusFinalCheckLabel => 'Kiểm tra cuối cùng';

  @override
  String get zkIdentityResultFailureTitle => 'Không thể xác minh';

  @override
  String get zkIdentityResultFailureSubtitle =>
      'Bạn đã không chia sẻ tên, ảnh hay giấy tờ tùy thân';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonRetry => 'Thử lại';

  @override
  String get commonCopied => 'Đã sao chép';

  @override
  String get buildInfoAppVersion => 'Phiên bản ứng dụng';

  @override
  String get buildInfoBuildNumber => 'Số bản dựng';

  @override
  String get settingsDebugMode => 'Chế độ gỡ lỗi';

  @override
  String get settingsDebugModeEnabled => 'Đang ghi các yêu cầu HTTP vào bộ nhớ';

  @override
  String get settingsDebugModeDisabled => 'Tắt · không ghi nhật ký mạng';

  @override
  String get settingsHttpLogs => 'Nhật ký HTTP';

  @override
  String get settingsHttpLogsSubtitle => 'Xem các yêu cầu mạng đã ghi';

  @override
  String get httpLogsTitle => 'Nhật ký HTTP';

  @override
  String get httpLogsEmpty =>
      'Chưa ghi được yêu cầu nào. Hãy tạo một số hoạt động mạng để xem nhật ký tại đây.';

  @override
  String get httpLogsCopy => 'Sao chép tất cả';

  @override
  String get httpLogsClear => 'Xóa';

  @override
  String get httpLogsCopied => 'Đã sao chép nhật ký vào bộ nhớ tạm';

  @override
  String get httpLogsShare => 'Chia sẻ nhật ký với nhóm';

  @override
  String get httpLogsSharing => 'Đang chia sẻ nhật ký với nhóm mỗi 30 giây…';

  @override
  String get httpLogsStopSharing => 'Dừng chia sẻ';

  @override
  String get httpLogsShareStopped =>
      'Máy chủ đã dừng chia sẻ nhật ký. Bạn có thể chia sẻ lại bất cứ lúc nào.';

  @override
  String get httpLogsShareNoParticipant =>
      'Chưa có ID người tham gia — hãy hoàn tất bước làm quen để chia sẻ nhật ký';

  @override
  String get httpLogsFilterHint => 'Lọc theo URL';

  @override
  String get httpLogsNoMatches => 'Không có yêu cầu nào khớp với bộ lọc.';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$count/$total';
  }

  @override
  String get widgetInstructionsTitle => 'Thêm tiện ích Homeroom';

  @override
  String widgetInstructionsBody(String name) {
    return '$name đã được thêm vào tiện ích dApps Homeroom của bạn. Để thấy nó trên màn hình chính, hãy thêm tiện ích một lần:';
  }

  @override
  String get widgetInstructionsStep1 =>
      'Chạm và giữ một vùng trống trên màn hình chính';

  @override
  String get widgetInstructionsStep2 =>
      'Chạm Sửa ở góc trên, rồi chọn Thêm tiện ích';

  @override
  String get widgetInstructionsStep3 => 'Tìm Homeroom và thêm tiện ích dApps';

  @override
  String get widgetInstructionsDone => 'Xong';

  @override
  String get svShellConnectingTitle => 'Đang kết nối với Homeroom…';

  @override
  String get svShellOfflineMessage =>
      'Không thể kết nối với Homeroom. Hãy kiểm tra kết nối và thử lại.';

  @override
  String get stakingManagerTitle => 'Chế độ staking';

  @override
  String get stakingDelegateIntro =>
      'Ủy quyền stake của bạn cho máy chủ. Nút của bạn vẫn chạy, nhưng máy chủ staking thay bạn.';

  @override
  String get stakingServerName => 'Máy chủ';

  @override
  String get stakingDelegateEffect =>
      'Nút của bạn ngừng tạo khối. Trong thời gian ủy quyền, bạn nhận được một nửa số điểm tạo khối mà bạn sẽ kiếm được khi tạo khối trực tiếp trên điện thoại này.';

  @override
  String get stakingDelegateNote =>
      'Bạn có thể tự staking trở lại bất cứ lúc nào.';

  @override
  String get stakingDelegateConfirm => 'Xác nhận ủy quyền';

  @override
  String get stakingDelegating => 'Đang ủy quyền…';

  @override
  String get stakingDelegateError =>
      'Không thể gửi ủy quyền. Hãy kiểm tra kết nối và thử lại.';

  @override
  String get stakingDelegationActiveTitle => 'Đang ủy quyền';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'Stake của bạn được ủy quyền cho $validator. Bạn nhận được một nửa số điểm tạo khối mà bạn sẽ kiếm được khi tạo khối trực tiếp trên điện thoại này.';
  }

  @override
  String get stakingDone => 'Xong';

  @override
  String get stakingUndelegateTitle => 'Dừng ủy quyền?';

  @override
  String get stakingUndelegateBody =>
      'Stake của bạn quay lại điện thoại này. Nút của bạn sẽ tự tạo khối và nhận đủ điểm tạo khối.';

  @override
  String get stakingUndelegateConfirm => 'Dừng ủy quyền';

  @override
  String get stakingUndelegateError =>
      'Không thể dừng ủy quyền. Hãy kiểm tra kết nối và thử lại.';

  @override
  String get versionUpdateRequiredTitle => 'Cần cập nhật';

  @override
  String get versionUpdateAvailableTitle => 'Có bản cập nhật';

  @override
  String get versionUpdateAction => 'Cập nhật';

  @override
  String get versionUpdateLater => 'Để sau';

  @override
  String get versionUpdateFallbackMessage =>
      'Đã có phiên bản mới của ứng dụng.';

  @override
  String get commonBack => 'Quay lại';

  @override
  String get commonDeny => 'Từ chối';

  @override
  String get commonConfirm => 'Xác nhận';

  @override
  String get commonApprove => 'Chấp thuận';

  @override
  String get txConfirmTitle => 'Xác nhận giao dịch';

  @override
  String get txConfirmSubtitleDefault => 'Một dapp đang yêu cầu gửi giao dịch.';

  @override
  String get txAmount => 'Số tiền';

  @override
  String get txDetails => 'Chi tiết';

  @override
  String get txFrom => 'Từ';

  @override
  String get txTo => 'Đến';

  @override
  String get txFee => 'Phí';

  @override
  String get txMemo => 'Ghi chú';

  @override
  String get verifyIdentityTitle => 'Xác minh danh tính';

  @override
  String verifyIdentityRequest(String name) {
    return '$name yêu cầu xác minh danh tính của bạn';
  }

  @override
  String get verifyIdentityExplanation =>
      'Thao tác này sẽ ký một thử thách bằng khóa riêng của bạn để chứng minh bạn sở hữu ví này. Sẽ không có giao dịch nào được gửi và không có token nào bị tiêu.';

  @override
  String get zkChallengeBusy =>
      'Một bằng chứng zkPassport vẫn đang được xử lý. Hãy thử lại sau ít phút.';

  @override
  String get zkChallengeResetDone => 'Đã đặt lại trạng thái bằng chứng ZK';

  @override
  String provingParametersDownloadProgress(int percent) {
    return 'Đang chuẩn bị công cụ tạo bằng chứng: $percent%. Dữ liệu tải xuống được lưu lại để dùng về sau.';
  }

  @override
  String get provingParametersDownloadFailed =>
      'Không thể tải xuống công cụ tạo bằng chứng. Hãy kiểm tra kết nối và thử lại.';
}
