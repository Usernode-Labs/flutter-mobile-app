// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline => 'Criação de apps com IA,\nagora multijogador.';

  @override
  String get initializingNode => 'Iniciando…';

  @override
  String get resumeSplashLoading => 'Carregando…';

  @override
  String get clockDriftWarningTitle => 'Hora do sistema incorreta';

  @override
  String clockDriftWarningBody(String drift) {
    return 'O relógio do seu dispositivo difere do relógio do nó em $drift. Você pode notar algumas inconsistências no app até que a hora do sistema seja corrigida.';
  }

  @override
  String get clockDriftWarningInstruction =>
      'Ative a sincronização automática de hora no seu dispositivo.';

  @override
  String get clockDriftRecommendationTitle => 'Recomendação';

  @override
  String get clockDriftRecommendationBody =>
      'Para manter a diferença o menor possível, deixe \"Data e hora automáticas\" e \"Fuso horário automático\" ativados nos ajustes, o que faz o dispositivo consultar a hora da rede.';

  @override
  String get clockDriftDismiss => 'OK';

  @override
  String clockDriftAhead(String seconds) {
    return '$seconds s adiantado';
  }

  @override
  String clockDriftBehind(String seconds) {
    return '$seconds s atrasado';
  }

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get settingsBuildInfo => 'Informações da versão';

  @override
  String get settingsDiagnostics => 'Diagnóstico';

  @override
  String get settingsDeviceBenchmark => 'Teste de desempenho';

  @override
  String get settingsDeviceBenchmarkSubtitle =>
      'Execute medições de desempenho no dispositivo';

  @override
  String get perfTitle => 'Teste de desempenho';

  @override
  String get perfIntroTitle =>
      'Execute um teste de desempenho neste dispositivo';

  @override
  String get perfIntroDescription =>
      'Meça hash, sincronização parcial, produção de blocos e envios da carteira para ver como este dispositivo se comporta.';

  @override
  String get perfIntroNote =>
      'Por enquanto, os resultados ficam neste dispositivo. O desempenho pode variar com o nível da bateria, a temperatura e a atividade em segundo plano.';

  @override
  String get perfCatalogLoadError =>
      'Não foi possível carregar o catálogo de testes.';

  @override
  String get perfCatalogLoading => 'Carregando o catálogo de testes…';

  @override
  String get perfProfileQuick => 'Teste rápido';

  @override
  String get perfProfileStandard => 'Teste completo';

  @override
  String perfRunProfile(String profile) {
    return 'Executar: $profile';
  }

  @override
  String perfStepCount(int count) {
    return '$count etapas';
  }

  @override
  String get perfCurrentRunTitle => 'Execução atual';

  @override
  String get perfRunInProgressTitle => 'Teste em andamento';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'Um teste \"$profile\" já está em andamento neste dispositivo.';
  }

  @override
  String get perfRunInProgressDescriptionUnknown =>
      'Um teste já está em andamento neste dispositivo.';

  @override
  String get perfOpenCurrentRun => 'Abrir execução atual';

  @override
  String get perfLatestResultsTitle => 'Últimos resultados';

  @override
  String perfLatestResultsDescription(String profile) {
    return 'Os resultados de \"$profile\" estão prontos para revisão.';
  }

  @override
  String get perfLatestResultsDescriptionUnknown =>
      'Os resultados do teste estão prontos para revisão.';

  @override
  String get perfViewLatestResults => 'Ver últimos resultados';

  @override
  String get perfNoRunAvailableTitle => 'Nenhum teste';

  @override
  String get perfNoRunAvailableDescription =>
      'Inicie um teste na tela de testes para ver o progresso ou os resultados aqui.';

  @override
  String get perfBackToBenchmarks => 'Voltar aos testes';

  @override
  String get perfRunPausedNodeNotice =>
      'O nó em segundo plano fica pausado enquanto este teste é executado.';

  @override
  String get perfStateRunning => 'Em execução';

  @override
  String get perfStateStarting => 'Iniciando';

  @override
  String get perfStateCompleted => 'Concluído';

  @override
  String get perfStateFailed => 'Falhou';

  @override
  String get perfStateCancelled => 'Cancelado';

  @override
  String perfProgressValue(int completed, int total) {
    return '$completed de $total etapas';
  }

  @override
  String perfPreparingProfile(String profile) {
    return 'Preparando: $profile';
  }

  @override
  String perfCurrentStep(String label) {
    return 'Etapa atual: $label';
  }

  @override
  String perfElapsed(String duration) {
    return 'Decorrido: $duration';
  }

  @override
  String get perfResultsTitle => 'Resultados';

  @override
  String get perfResultProfile => 'Perfil';

  @override
  String get perfResultDevice => 'Dispositivo';

  @override
  String get perfResultOperatingSystem => 'SO';

  @override
  String get perfResultCpu => 'CPU';

  @override
  String get perfResultLogicalCores => 'Núcleos lógicos';

  @override
  String get perfResultMeasurements => 'Medições';

  @override
  String get perfSuitePrimitives => 'Primitivas';

  @override
  String get perfSuitePartialSync => 'Sincronização parcial';

  @override
  String get perfSuitePartialBlockProduction => 'Produção de blocos';

  @override
  String get perfSuiteWalletSend => 'Envio da carteira';

  @override
  String get perfScenarioDefault => 'Caso padrão';

  @override
  String perfContextTxCount(int count) {
    return '$count tx';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'Layout $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return 'Formato $value';
  }

  @override
  String get perfDetailScenario => 'Cenário';

  @override
  String get perfDetailAverage => 'Média';

  @override
  String get perfDetailMinMax => 'Mín. / Máx.';

  @override
  String get perfDetailRuns => 'Execuções';

  @override
  String get perfDetailMetadataTitle => 'Detalhes do cenário';

  @override
  String get perfDetailImplementationTitle => 'Detalhes da implementação';

  @override
  String get perfDetailNotesTitle => 'Notas';

  @override
  String get perfDetailFlow => 'Fluxo';

  @override
  String get perfDetailTxCount => 'Número de transações';

  @override
  String get perfDetailBatchLayout => 'Layout do lote';

  @override
  String get perfDetailTransactionShape => 'Formato da transação';

  @override
  String get perfDetailTouchedLeaves => 'Folhas acessadas';

  @override
  String get perfDetailProofNodes => 'Nós da prova';

  @override
  String get perfDetailProofSize => 'Tamanho da prova';

  @override
  String get perfCancelFailed =>
      'Não foi possível cancelar o teste em andamento.';

  @override
  String get perfRunUnavailable => 'Este teste não está mais disponível.';

  @override
  String get commonOk => 'OK';

  @override
  String get buildInfoVersion => 'Versão';

  @override
  String get buildInfoCommit => 'Commit';

  @override
  String get buildInfoBranch => 'Branch';

  @override
  String get buildInfoCommitTime => 'Hora do commit';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Alvo do Cargo';

  @override
  String get buildInfoFeatures => 'Recursos';

  @override
  String get buildInfoOptLevel => 'Nível de otimização';

  @override
  String get buildInfoDebug => 'Debug';

  @override
  String get retry => 'Tentar de novo';

  @override
  String get zkIdentityAppNotFoundTitle => 'Instale o ZK Passport primeiro';

  @override
  String get zkIdentityAppNotFoundDetail =>
      'Ele cria sua prova e depois traz você de volta aqui';

  @override
  String get zkIdentityInstallCta => 'Instalar';

  @override
  String get zkIdentityStepLabelOpenApp => 'Abrindo o ZK Passport';

  @override
  String get zkIdentityStepDescOpenApp =>
      'Preparando um pedido de prova com seu passaporte salvo';

  @override
  String get zkIdentityCheckAppCta => 'Continuar';

  @override
  String get zkIdentityAccountPreparingTitle => 'Preparando sua conta';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'Conectando sua conta do Social Vibecoding';

  @override
  String get zkIdentityAccountUnavailable =>
      'Entre no Social Vibecoding antes de iniciar a verificação.';

  @override
  String get zkIdentityStepLabelScan => 'Usar passaporte salvo';

  @override
  String get zkIdentityStepDescScan =>
      'Usa o passaporte que já está guardado no ZK Passport';

  @override
  String get zkIdentityConfirmScannedBody => 'Seu passaporte salvo será usado.';

  @override
  String get zkIdentityConfirmScannedYesCta => 'Continuar';

  @override
  String get zkIdentityConfirmScannedNoCta => 'Agora não';

  @override
  String get zkIdentityStepLabelReady => 'Criar prova';

  @override
  String get zkIdentityStepDescReady =>
      'O ZK Passport vai pedir que você aprove e crie a prova';

  @override
  String get zkIdentityReadyBody =>
      'O ZK Passport gera a prova a partir do seu passaporte salvo em cerca de um minuto.';

  @override
  String get zkIdentityReadyBullet1 =>
      'Nenhum nome, foto ou documento é compartilhado';

  @override
  String get zkIdentityReadyBullet2 => 'Você envia apenas uma prova';

  @override
  String get zkIdentityReadyBullet3 =>
      'Nada de pessoal é armazenado na blockchain';

  @override
  String get zkIdentityReadyCta => 'Abrir o ZK Passport';

  @override
  String get zkIdentityStepLabelVerifying => 'Verificando';

  @override
  String get zkIdentityStepDescVerifying => 'Gerando e conferindo sua prova';

  @override
  String get zkIdentityStepLabelResult => 'Resultado';

  @override
  String get zkIdentityStepDescResult => 'Veja o resultado da sua verificação';

  @override
  String get zkIdentitySubTaskOpening => 'Abrindo o ZK Passport';

  @override
  String get zkIdentitySubTaskWaiting => 'Aguardando sua prova';

  @override
  String get zkIdentitySubTaskChecking => 'Conferindo sua prova';

  @override
  String get zkIdentitySubTaskWrapping => 'Empacotando sua prova';

  @override
  String get zkIdentitySubTaskFinal => 'Conferência final';

  @override
  String get zkIdentityResultSuccessTitle => 'Você é um humano único!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      'Você provou que é único sem compartilhar seu nome, foto ou documento';

  @override
  String get zkIdentityStatusUniqueness => 'Humano único';

  @override
  String get zkIdentityStatusUniquenessValue => 'Confirmado';

  @override
  String get zkIdentityStatusFaceMatchLabel => 'Verificação facial';

  @override
  String get zkIdentityStatusPrivacyValue => 'Nada compartilhado';

  @override
  String get zkIdentityCancelVerification => 'Cancelar';

  @override
  String get zkIdentityGoToZkPassport => 'Ir para o ZK Passport';

  @override
  String get zkIdentityTryAgain => 'Tentar de novo';

  @override
  String get zkIdentityWalletClaimTitle => 'Conecte sua carteira do programa';

  @override
  String get zkIdentityWalletClaimDescription =>
      'Esta conta do Social é diferente da conta que tem a sua carteira atual. Verifique uma vez o e-mail do seu programa original para conectá-la.';

  @override
  String get zkIdentityWalletClaimEmailLabel => 'E-mail do programa original';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      'Use o e-mail do seu cadastro no programa original do Homeroom.';

  @override
  String get zkIdentityWalletClaimSendCode => 'Enviar código de verificação';

  @override
  String get zkIdentityWalletClaimSendingCode => 'Enviando código…';

  @override
  String get zkIdentityWalletClaimCodeSent =>
      'Digite o código de 6 dígitos enviado para esse e-mail.';

  @override
  String get zkIdentityWalletClaimCodeLabel => 'Código de verificação';

  @override
  String get zkIdentityWalletClaimConnect => 'Conectar carteira e continuar';

  @override
  String get zkIdentityWalletClaimConnecting => 'Conectando carteira…';

  @override
  String get zkIdentityWalletClaimChangeEmail => 'Usar outro e-mail';

  @override
  String get zkIdentityWalletClaimEmailRequired =>
      'Digite um endereço de e-mail válido.';

  @override
  String get zkIdentityWalletClaimCodeRequired =>
      'Digite o código de 6 dígitos.';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'Sua carteira foi conectada, mas o app não conseguiu terminar de prepará-la. Tente de novo.';

  @override
  String get zkIdentityDone => 'Concluir';

  @override
  String get zkIdentityStatusFaceMatchVerified => 'Verificada';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'Ignorada';

  @override
  String get zkIdentityStatusPrivacyLabel => 'Privacidade';

  @override
  String get zkIdentityStatusVerifiedDateLabel => 'Verificado em';

  @override
  String get zkIdentityStatusProofIdLabel => 'ID da prova';

  @override
  String get zkIdentityStatusVerifyDurationLabel => 'Verificação';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'Empacotamento';

  @override
  String get zkIdentityStatusFinalCheckLabel => 'Conferência final';

  @override
  String get zkIdentityResultFailureTitle => 'Não foi possível verificar';

  @override
  String get zkIdentityResultFailureSubtitle =>
      'Você não compartilhou seu nome, foto ou documento';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonRetry => 'Tentar de novo';

  @override
  String get commonCopied => 'Copiado';

  @override
  String get buildInfoAppVersion => 'Versão do app';

  @override
  String get buildInfoBuildNumber => 'Número da versão';

  @override
  String get settingsDebugMode => 'Modo de depuração';

  @override
  String get settingsDebugModeEnabled =>
      'Capturando requisições HTTP na memória';

  @override
  String get settingsDebugModeDisabled => 'Desativado · sem registro de rede';

  @override
  String get settingsHttpLogs => 'Logs HTTP';

  @override
  String get settingsHttpLogsSubtitle =>
      'Ver as requisições de rede capturadas';

  @override
  String get httpLogsTitle => 'Logs HTTP';

  @override
  String get httpLogsEmpty =>
      'Nenhuma requisição capturada ainda. Gere alguma atividade de rede para ver os logs aqui.';

  @override
  String get httpLogsCopy => 'Copiar tudo';

  @override
  String get httpLogsClear => 'Limpar';

  @override
  String get httpLogsCopied => 'Logs copiados para a área de transferência';

  @override
  String get httpLogsShare => 'Compartilhar os logs com a equipe';

  @override
  String get httpLogsSharing =>
      'Compartilhando os logs com a equipe a cada 30 s…';

  @override
  String get httpLogsStopSharing => 'Parar de compartilhar';

  @override
  String get httpLogsShareStopped =>
      'O servidor interrompeu o compartilhamento de logs. Você pode compartilhar de novo quando quiser.';

  @override
  String get httpLogsShareNoParticipant =>
      'Ainda não há ID de participante — conclua a integração para compartilhar os logs';

  @override
  String get httpLogsFilterHint => 'Filtrar por URL';

  @override
  String get httpLogsNoMatches => 'Nenhuma requisição corresponde ao filtro.';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$count de $total';
  }

  @override
  String get widgetInstructionsTitle => 'Adicione o widget do Homeroom';

  @override
  String widgetInstructionsBody(String name) {
    return '$name foi adicionado ao seu widget de dApps do Homeroom. Para vê-lo na tela inicial, adicione o widget uma vez:';
  }

  @override
  String get widgetInstructionsStep1 =>
      'Toque e segure uma área vazia da tela inicial';

  @override
  String get widgetInstructionsStep2 =>
      'Toque em Editar no canto superior e depois em Adicionar widget';

  @override
  String get widgetInstructionsStep3 =>
      'Procure por Homeroom e adicione o widget de dApps';

  @override
  String get widgetInstructionsDone => 'Concluir';

  @override
  String get svShellConnectingTitle => 'Conectando ao Homeroom…';

  @override
  String get svShellOfflineMessage =>
      'Não foi possível acessar o Homeroom. Verifique sua conexão e tente de novo.';

  @override
  String get stakingManagerTitle => 'Modo de staking';

  @override
  String get stakingDelegateIntro =>
      'Delegue seu stake ao servidor. Seu nó continua funcionando, mas o servidor faz o staking em seu nome.';

  @override
  String get stakingServerName => 'Servidor';

  @override
  String get stakingDelegateEffect =>
      'Seu nó para de produzir blocos. Enquanto delega, você recebe metade dos pontos de produção de blocos que ganharia produzindo blocos diretamente neste celular.';

  @override
  String get stakingDelegateNote =>
      'Você pode voltar a fazer staking por conta própria a qualquer momento.';

  @override
  String get stakingDelegateConfirm => 'Confirmar delegação';

  @override
  String get stakingDelegating => 'Delegando…';

  @override
  String get stakingDelegateError =>
      'Não foi possível enviar a delegação. Verifique sua conexão e tente de novo.';

  @override
  String get stakingDelegationActiveTitle => 'Delegação ativa';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'Seu stake está delegado a $validator. Você recebe metade dos pontos de produção de blocos que ganharia produzindo blocos diretamente neste celular.';
  }

  @override
  String get stakingDone => 'Concluir';

  @override
  String get stakingUndelegateTitle => 'Parar de delegar?';

  @override
  String get stakingUndelegateBody =>
      'Seu stake volta para este celular. Seu nó vai produzir blocos diretamente e ganhar todos os pontos de produção de blocos.';

  @override
  String get stakingUndelegateConfirm => 'Parar de delegar';

  @override
  String get stakingUndelegateError =>
      'Não foi possível parar a delegação. Verifique sua conexão e tente de novo.';

  @override
  String get versionUpdateRequiredTitle => 'Atualização necessária';

  @override
  String get versionUpdateAvailableTitle => 'Atualização disponível';

  @override
  String get versionUpdateAction => 'Atualizar';

  @override
  String get versionUpdateLater => 'Depois';

  @override
  String get versionUpdateFallbackMessage =>
      'Há uma nova versão do app disponível.';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonDeny => 'Negar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonApprove => 'Aprovar';

  @override
  String get txConfirmTitle => 'Confirmar transação';

  @override
  String get txConfirmSubtitleDefault =>
      'Um dapp está pedindo para enviar uma transação.';

  @override
  String get txAmount => 'Valor';

  @override
  String get txDetails => 'Detalhes';

  @override
  String get txFrom => 'De';

  @override
  String get txTo => 'Para';

  @override
  String get txFee => 'Taxa';

  @override
  String get txMemo => 'Memo';

  @override
  String get verifyIdentityTitle => 'Verificar identidade';

  @override
  String verifyIdentityRequest(String name) {
    return '$name está pedindo para verificar sua identidade';
  }

  @override
  String get verifyIdentityExplanation =>
      'Isso vai assinar um desafio com sua chave privada para provar que você é o dono desta carteira. Nenhuma transação será enviada e nenhum token será gasto.';

  @override
  String get zkChallengeBusy =>
      'Uma prova do zkPassport ainda está sendo processada. Tente novamente em instantes.';

  @override
  String get zkChallengeResetDone => 'Estado da prova ZK redefinido';
}
