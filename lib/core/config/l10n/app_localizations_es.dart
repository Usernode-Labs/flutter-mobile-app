// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline => 'Creación de apps con IA,\nahora multijugador.';

  @override
  String get initializingNode => 'Iniciando…';

  @override
  String get resumeSplashLoading => 'Cargando…';

  @override
  String get clockDriftWarningTitle => 'La hora del sistema es incorrecta';

  @override
  String clockDriftWarningBody(String drift) {
    return 'El reloj de tu dispositivo difiere del reloj del nodo en $drift. Es posible que veas algunas incoherencias en la app hasta que corrijas la hora del sistema.';
  }

  @override
  String get clockDriftWarningInstruction =>
      'Activa la sincronización automática de hora en tu dispositivo.';

  @override
  String get clockDriftRecommendationTitle => 'Recomendación';

  @override
  String get clockDriftRecommendationBody =>
      'Para minimizar el desfase, mantén activadas la «Fecha y hora automáticas» y la «Zona horaria automática» en los ajustes, así el dispositivo consulta la hora de la red.';

  @override
  String get clockDriftDismiss => 'OK';

  @override
  String clockDriftAhead(String seconds) {
    return '$seconds s adelantado';
  }

  @override
  String clockDriftBehind(String seconds) {
    return '$seconds s atrasado';
  }

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsBuildInfo => 'Información de la compilación';

  @override
  String get settingsDiagnostics => 'Diagnóstico';

  @override
  String get settingsDeviceBenchmark => 'Prueba de rendimiento';

  @override
  String get settingsDeviceBenchmarkSubtitle =>
      'Ejecuta mediciones de rendimiento en el dispositivo';

  @override
  String get perfTitle => 'Prueba de rendimiento';

  @override
  String get perfIntroTitle =>
      'Ejecuta una prueba de rendimiento en este dispositivo';

  @override
  String get perfIntroDescription =>
      'Mide el hash, la sincronización parcial, la producción de bloques y los envíos de la cartera para ver cómo rinde este dispositivo.';

  @override
  String get perfIntroNote =>
      'Por ahora, los resultados se quedan en este dispositivo. El rendimiento puede variar según el nivel de batería, la temperatura y la actividad en segundo plano.';

  @override
  String get perfCatalogLoadError =>
      'No se pudo cargar el catálogo de pruebas.';

  @override
  String get perfCatalogLoading => 'Cargando el catálogo de pruebas…';

  @override
  String get perfProfileQuick => 'Prueba rápida';

  @override
  String get perfProfileStandard => 'Prueba completa';

  @override
  String perfRunProfile(String profile) {
    return 'Ejecutar: $profile';
  }

  @override
  String perfStepCount(int count) {
    return '$count pasos';
  }

  @override
  String get perfCurrentRunTitle => 'Ejecución actual';

  @override
  String get perfRunInProgressTitle => 'Prueba en curso';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'Ya hay una prueba «$profile» en curso en este dispositivo.';
  }

  @override
  String get perfRunInProgressDescriptionUnknown =>
      'Ya hay una prueba en curso en este dispositivo.';

  @override
  String get perfOpenCurrentRun => 'Abrir la ejecución actual';

  @override
  String get perfLatestResultsTitle => 'Últimos resultados';

  @override
  String perfLatestResultsDescription(String profile) {
    return 'Los resultados de «$profile» están listos para revisar.';
  }

  @override
  String get perfLatestResultsDescriptionUnknown =>
      'Los resultados de la prueba están listos para revisar.';

  @override
  String get perfViewLatestResults => 'Ver últimos resultados';

  @override
  String get perfNoRunAvailableTitle => 'Sin pruebas';

  @override
  String get perfNoRunAvailableDescription =>
      'Inicia una prueba desde la pantalla de pruebas para ver aquí el progreso o los resultados.';

  @override
  String get perfBackToBenchmarks => 'Volver a las pruebas';

  @override
  String get perfRunPausedNodeNotice =>
      'El nodo en segundo plano está en pausa mientras se ejecuta esta prueba.';

  @override
  String get perfStateRunning => 'En curso';

  @override
  String get perfStateStarting => 'Iniciando';

  @override
  String get perfStateCompleted => 'Completada';

  @override
  String get perfStateFailed => 'Fallida';

  @override
  String get perfStateCancelled => 'Cancelada';

  @override
  String perfProgressValue(int completed, int total) {
    return '$completed de $total pasos';
  }

  @override
  String perfPreparingProfile(String profile) {
    return 'Preparando: $profile';
  }

  @override
  String perfCurrentStep(String label) {
    return 'Paso actual: $label';
  }

  @override
  String perfElapsed(String duration) {
    return 'Transcurrido: $duration';
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
  String get perfResultMeasurements => 'Mediciones';

  @override
  String get perfSuitePrimitives => 'Primitivas';

  @override
  String get perfSuitePartialSync => 'Sincronización parcial';

  @override
  String get perfSuitePartialBlockProduction => 'Producción de bloques';

  @override
  String get perfSuiteWalletSend => 'Envío desde la cartera';

  @override
  String get perfScenarioDefault => 'Caso predeterminado';

  @override
  String perfContextTxCount(int count) {
    return '$count tx';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'Disposición $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return 'Forma $value';
  }

  @override
  String get perfDetailScenario => 'Escenario';

  @override
  String get perfDetailAverage => 'Promedio';

  @override
  String get perfDetailMinMax => 'Mín. / Máx.';

  @override
  String get perfDetailRuns => 'Ejecuciones';

  @override
  String get perfDetailMetadataTitle => 'Detalles del escenario';

  @override
  String get perfDetailImplementationTitle => 'Detalles de implementación';

  @override
  String get perfDetailNotesTitle => 'Notas';

  @override
  String get perfDetailFlow => 'Flujo';

  @override
  String get perfDetailTxCount => 'Número de transacciones';

  @override
  String get perfDetailBatchLayout => 'Disposición del lote';

  @override
  String get perfDetailTransactionShape => 'Forma de la transacción';

  @override
  String get perfDetailTouchedLeaves => 'Hojas tocadas';

  @override
  String get perfDetailProofNodes => 'Nodos de la prueba';

  @override
  String get perfDetailProofSize => 'Tamaño de la prueba';

  @override
  String get perfCancelFailed => 'No se pudo cancelar la prueba en curso.';

  @override
  String get perfRunUnavailable => 'Esta prueba ya no está disponible.';

  @override
  String get commonOk => 'OK';

  @override
  String get buildInfoVersion => 'Versión';

  @override
  String get buildInfoCommit => 'Commit';

  @override
  String get buildInfoBranch => 'Rama';

  @override
  String get buildInfoCommitTime => 'Hora del commit';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Destino de Cargo';

  @override
  String get buildInfoFeatures => 'Funciones';

  @override
  String get buildInfoOptLevel => 'Nivel de optimización';

  @override
  String get buildInfoDebug => 'Depuración';

  @override
  String get retry => 'Reintentar';

  @override
  String get zkIdentityAppNotFoundTitle => 'Primero instala ZK Passport';

  @override
  String get zkIdentityAppNotFoundDetail =>
      'Crea tu prueba y luego te devuelve aquí';

  @override
  String get zkIdentityInstallCta => 'Instalar';

  @override
  String get zkIdentityStepLabelOpenApp => 'Abriendo ZK Passport';

  @override
  String get zkIdentityStepDescOpenApp =>
      'Preparando una solicitud de prueba con tu pasaporte guardado';

  @override
  String get zkIdentityCheckAppCta => 'Continuar';

  @override
  String get zkIdentityAccountPreparingTitle => 'Preparando tu cuenta';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'Conectando tu cuenta de Social Vibecoding con sesión iniciada';

  @override
  String get zkIdentityAccountUnavailable =>
      'Inicia sesión en Social Vibecoding antes de empezar la verificación.';

  @override
  String get zkIdentityStepLabelScan => 'Usar pasaporte guardado';

  @override
  String get zkIdentityStepDescScan =>
      'Usa el pasaporte que ya está guardado en ZK Passport';

  @override
  String get zkIdentityConfirmScannedBody => 'Se usará tu pasaporte guardado.';

  @override
  String get zkIdentityConfirmScannedYesCta => 'Continuar';

  @override
  String get zkIdentityConfirmScannedNoCta => 'Ahora no';

  @override
  String get zkIdentityStepLabelReady => 'Crear prueba';

  @override
  String get zkIdentityStepDescReady =>
      'ZK Passport te pedirá que apruebes y crees la prueba';

  @override
  String get zkIdentityReadyBody =>
      'ZK Passport genera la prueba a partir de tu pasaporte guardado en aproximadamente un minuto.';

  @override
  String get zkIdentityReadyBullet1 =>
      'No se comparte nombre, foto ni documento de identidad';

  @override
  String get zkIdentityReadyBullet2 => 'Solo envías una prueba';

  @override
  String get zkIdentityReadyBullet3 =>
      'No se guarda nada personal en la cadena';

  @override
  String get zkIdentityReadyCta => 'Abrir ZK Passport';

  @override
  String get zkIdentityStepLabelVerifying => 'Verificando';

  @override
  String get zkIdentityStepDescVerifying => 'Generando y comprobando tu prueba';

  @override
  String get zkIdentityStepLabelResult => 'Resultado';

  @override
  String get zkIdentityStepDescResult =>
      'Consulta el resultado de tu verificación';

  @override
  String get zkIdentitySubTaskOpening => 'Abriendo ZK Passport';

  @override
  String get zkIdentitySubTaskWaiting => 'Esperando tu prueba';

  @override
  String get zkIdentitySubTaskChecking => 'Comprobando tu prueba';

  @override
  String get zkIdentitySubTaskWrapping => 'Empaquetando tu prueba';

  @override
  String get zkIdentitySubTaskFinal => 'Comprobación final';

  @override
  String get zkIdentityResultSuccessTitle => '¡Eres una persona única!';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      'Demostraste que eres único sin compartir tu nombre, foto ni documento de identidad';

  @override
  String get zkIdentityStatusUniqueness => 'Persona única';

  @override
  String get zkIdentityStatusUniquenessValue => 'Confirmado';

  @override
  String get zkIdentityStatusFaceMatchLabel => 'Verificación facial';

  @override
  String get zkIdentityStatusPrivacyValue => 'No se compartió nada';

  @override
  String get zkIdentityCancelVerification => 'Cancelar';

  @override
  String get zkIdentityGoToZkPassport => 'Ir a ZK Passport';

  @override
  String get zkIdentityTryAgain => 'Intentar de nuevo';

  @override
  String get zkIdentityWalletClaimTitle => 'Conecta tu cartera del programa';

  @override
  String get zkIdentityWalletClaimDescription =>
      'Esta cuenta de Social es distinta de la cuenta que tiene tu cartera actual. Verifica una vez el correo de tu programa original para conectarla.';

  @override
  String get zkIdentityWalletClaimEmailLabel => 'Correo del programa original';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      'Usa el correo con el que te registraste en el programa original de Homeroom.';

  @override
  String get zkIdentityWalletClaimSendCode => 'Enviar código de verificación';

  @override
  String get zkIdentityWalletClaimSendingCode => 'Enviando código…';

  @override
  String get zkIdentityWalletClaimCodeSent =>
      'Introduce el código de 6 dígitos enviado a ese correo.';

  @override
  String get zkIdentityWalletClaimCodeLabel => 'Código de verificación';

  @override
  String get zkIdentityWalletClaimConnect => 'Conectar cartera y continuar';

  @override
  String get zkIdentityWalletClaimConnecting => 'Conectando cartera…';

  @override
  String get zkIdentityWalletClaimChangeEmail => 'Usar otro correo';

  @override
  String get zkIdentityWalletClaimEmailRequired =>
      'Introduce un correo electrónico válido.';

  @override
  String get zkIdentityWalletClaimCodeRequired =>
      'Introduce el código de 6 dígitos.';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'Tu cartera se conectó, pero la app no pudo terminar de prepararla. Inténtalo de nuevo.';

  @override
  String get zkIdentityDone => 'Listo';

  @override
  String get zkIdentityStatusFaceMatchVerified => 'Verificada';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'Omitida';

  @override
  String get zkIdentityStatusPrivacyLabel => 'Privacidad';

  @override
  String get zkIdentityStatusVerifiedDateLabel => 'Verificado el';

  @override
  String get zkIdentityStatusProofIdLabel => 'ID de la prueba';

  @override
  String get zkIdentityStatusVerifyDurationLabel => 'Verificación';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'Empaquetado';

  @override
  String get zkIdentityStatusFinalCheckLabel => 'Comprobación final';

  @override
  String get zkIdentityResultFailureTitle => 'No se pudo verificar';

  @override
  String get zkIdentityResultFailureSubtitle =>
      'No compartiste tu nombre, foto ni documento de identidad';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonCopied => 'Copiado';

  @override
  String get buildInfoAppVersion => 'Versión de la app';

  @override
  String get buildInfoBuildNumber => 'Número de compilación';

  @override
  String get settingsDebugMode => 'Modo de depuración';

  @override
  String get settingsDebugModeEnabled =>
      'Guardando las solicitudes HTTP en memoria';

  @override
  String get settingsDebugModeDisabled => 'Desactivado · sin registro de red';

  @override
  String get settingsHttpLogs => 'Registros HTTP';

  @override
  String get settingsHttpLogsSubtitle =>
      'Ver las solicitudes de red capturadas';

  @override
  String get httpLogsTitle => 'Registros HTTP';

  @override
  String get httpLogsEmpty =>
      'Aún no se ha capturado ninguna solicitud. Genera algo de actividad de red para ver los registros aquí.';

  @override
  String get httpLogsCopy => 'Copiar todo';

  @override
  String get httpLogsClear => 'Borrar';

  @override
  String get httpLogsCopied => 'Registros copiados al portapapeles';

  @override
  String get httpLogsShare => 'Compartir los registros con el equipo';

  @override
  String get httpLogsSharing =>
      'Compartiendo los registros con el equipo cada 30 s…';

  @override
  String get httpLogsStopSharing => 'Dejar de compartir';

  @override
  String get httpLogsShareStopped =>
      'El servidor detuvo el uso compartido de registros. Puedes volver a compartirlos cuando quieras.';

  @override
  String get httpLogsShareNoParticipant =>
      'Aún no tienes ID de participante: termina la incorporación para compartir registros';

  @override
  String get httpLogsFilterHint => 'Filtrar por URL';

  @override
  String get httpLogsNoMatches => 'Ninguna solicitud coincide con el filtro.';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$count de $total';
  }

  @override
  String get widgetInstructionsTitle => 'Añade el widget de Homeroom';

  @override
  String widgetInstructionsBody(String name) {
    return '$name se añadió a tu widget de dApps de Homeroom. Para verlo en la pantalla de inicio, añade el widget una vez:';
  }

  @override
  String get widgetInstructionsStep1 =>
      'Mantén pulsada una zona vacía de la pantalla de inicio';

  @override
  String get widgetInstructionsStep2 =>
      'Toca Editar en la esquina superior y luego Añadir widget';

  @override
  String get widgetInstructionsStep3 =>
      'Busca Homeroom y añade el widget de dApps';

  @override
  String get widgetInstructionsDone => 'Listo';

  @override
  String get svShellConnectingTitle => 'Conectando con Homeroom…';

  @override
  String get svShellOfflineMessage =>
      'No se puede conectar con Homeroom. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get stakingManagerTitle => 'Modo de staking';

  @override
  String get stakingDelegateIntro =>
      'Delega tu stake en el servidor. Tu nodo sigue funcionando, pero el servidor hace el staking en tu nombre.';

  @override
  String get stakingServerName => 'Servidor';

  @override
  String get stakingDelegateEffect =>
      'Tu nodo deja de producir bloques. Mientras delegas, recibes la mitad de los puntos de producción de bloques que ganarías produciendo bloques directamente en este teléfono.';

  @override
  String get stakingDelegateNote =>
      'Puedes volver a hacer staking por tu cuenta en cualquier momento.';

  @override
  String get stakingDelegateConfirm => 'Confirmar delegación';

  @override
  String get stakingDelegating => 'Delegando…';

  @override
  String get stakingDelegateError =>
      'No se pudo enviar la delegación. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get stakingDelegationActiveTitle => 'Delegación activa';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'Tu stake está delegado en $validator. Recibes la mitad de los puntos de producción de bloques que ganarías produciendo bloques directamente en este teléfono.';
  }

  @override
  String get stakingDone => 'Listo';

  @override
  String get stakingUndelegateTitle => '¿Dejar de delegar?';

  @override
  String get stakingUndelegateBody =>
      'Tu stake vuelve a este teléfono. Tu nodo producirá bloques directamente y ganará todos los puntos de producción de bloques.';

  @override
  String get stakingUndelegateConfirm => 'Dejar de delegar';

  @override
  String get stakingUndelegateError =>
      'No se pudo dejar de delegar. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get versionUpdateRequiredTitle => 'Actualización necesaria';

  @override
  String get versionUpdateAvailableTitle => 'Actualización disponible';

  @override
  String get versionUpdateAction => 'Actualizar';

  @override
  String get versionUpdateLater => 'Más tarde';

  @override
  String get versionUpdateFallbackMessage =>
      'Hay una nueva versión de la app disponible.';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonDeny => 'Rechazar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonApprove => 'Aprobar';

  @override
  String get txConfirmTitle => 'Confirmar transacción';

  @override
  String get txConfirmSubtitleDefault =>
      'Una dapp solicita enviar una transacción.';

  @override
  String get txAmount => 'Importe';

  @override
  String get txDetails => 'Detalles';

  @override
  String get txFrom => 'De';

  @override
  String get txTo => 'Para';

  @override
  String get txFee => 'Comisión';

  @override
  String get txMemo => 'Memo';

  @override
  String get verifyIdentityTitle => 'Verificar identidad';

  @override
  String verifyIdentityRequest(String name) {
    return '$name solicita verificar tu identidad';
  }

  @override
  String get verifyIdentityExplanation =>
      'Esto firmará un desafío con tu clave privada para demostrar que eres el dueño de esta cartera. No se enviará ninguna transacción ni se gastará ningún token.';

  @override
  String get zkChallengeBusy =>
      'Aún se está procesando una prueba de zkPassport. Inténtalo de nuevo en un momento.';

  @override
  String get zkChallengeResetDone => 'Estado de la prueba ZK restablecido';
}
