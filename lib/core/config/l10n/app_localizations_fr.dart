// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Homeroom';

  @override
  String get appTagline =>
      'Création d’apps avec l’IA,\ndésormais en multijoueur.';

  @override
  String get initializingNode => 'Démarrage…';

  @override
  String get resumeSplashLoading => 'Chargement…';

  @override
  String get clockDriftWarningTitle => 'Heure système incorrecte';

  @override
  String clockDriftWarningBody(String drift) {
    return 'L’horloge de votre appareil diffère de celle du nœud de $drift. Vous pourriez constater des incohérences dans l’app tant que l’heure système n’est pas corrigée.';
  }

  @override
  String get clockDriftWarningInstruction =>
      'Activez la synchronisation automatique de l’heure sur votre appareil.';

  @override
  String get clockDriftRecommendationTitle => 'Recommandation';

  @override
  String get clockDriftRecommendationBody =>
      'Pour limiter au maximum le décalage, laissez activés « Date et heure automatiques » et « Fuseau horaire automatique » dans les réglages : l’appareil interroge alors l’heure du réseau.';

  @override
  String get clockDriftDismiss => 'OK';

  @override
  String clockDriftAhead(String seconds) {
    return '$seconds s d’avance';
  }

  @override
  String clockDriftBehind(String seconds) {
    return '$seconds s de retard';
  }

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsBuildInfo => 'Infos de build';

  @override
  String get settingsDiagnostics => 'Diagnostics';

  @override
  String get settingsDeviceBenchmark => 'Test de performance';

  @override
  String get settingsDeviceBenchmarkSubtitle =>
      'Lancer des mesures de performance sur l’appareil';

  @override
  String get perfTitle => 'Test de performance';

  @override
  String get perfIntroTitle => 'Lancer un test de performance sur cet appareil';

  @override
  String get perfIntroDescription =>
      'Mesurez le hachage, la synchronisation partielle, la production de blocs et l’envoi depuis le portefeuille pour voir comment cet appareil se comporte.';

  @override
  String get perfIntroNote =>
      'Pour l’instant, les résultats restent sur cet appareil. Les performances peuvent varier selon le niveau de batterie, la température et l’activité en arrière-plan.';

  @override
  String get perfCatalogLoadError =>
      'Impossible de charger le catalogue de tests.';

  @override
  String get perfCatalogLoading => 'Chargement du catalogue de tests…';

  @override
  String get perfProfileQuick => 'Test rapide';

  @override
  String get perfProfileStandard => 'Test complet';

  @override
  String perfRunProfile(String profile) {
    return 'Lancer : $profile';
  }

  @override
  String perfStepCount(int count) {
    return '$count étapes';
  }

  @override
  String get perfCurrentRunTitle => 'Test en cours';

  @override
  String get perfRunInProgressTitle => 'Test en cours';

  @override
  String perfRunInProgressDescription(String profile) {
    return 'Un test « $profile » est déjà en cours sur cet appareil.';
  }

  @override
  String get perfRunInProgressDescriptionUnknown =>
      'Un test est déjà en cours sur cet appareil.';

  @override
  String get perfOpenCurrentRun => 'Ouvrir le test en cours';

  @override
  String get perfLatestResultsTitle => 'Derniers résultats';

  @override
  String perfLatestResultsDescription(String profile) {
    return 'Les résultats de « $profile » sont prêts à être consultés.';
  }

  @override
  String get perfLatestResultsDescriptionUnknown =>
      'Les résultats du test sont prêts à être consultés.';

  @override
  String get perfViewLatestResults => 'Voir les derniers résultats';

  @override
  String get perfNoRunAvailableTitle => 'Aucun test';

  @override
  String get perfNoRunAvailableDescription =>
      'Lancez un test depuis l’écran des tests pour voir ici sa progression ou ses résultats.';

  @override
  String get perfBackToBenchmarks => 'Retour aux tests';

  @override
  String get perfRunPausedNodeNotice =>
      'Le nœud en arrière-plan est en pause pendant ce test.';

  @override
  String get perfStateRunning => 'En cours';

  @override
  String get perfStateStarting => 'Démarrage';

  @override
  String get perfStateCompleted => 'Terminé';

  @override
  String get perfStateFailed => 'Échec';

  @override
  String get perfStateCancelled => 'Annulé';

  @override
  String perfProgressValue(int completed, int total) {
    return '$completed sur $total étapes';
  }

  @override
  String perfPreparingProfile(String profile) {
    return 'Préparation : $profile';
  }

  @override
  String perfCurrentStep(String label) {
    return 'Étape en cours : $label';
  }

  @override
  String perfElapsed(String duration) {
    return 'Écoulé : $duration';
  }

  @override
  String get perfResultsTitle => 'Résultats';

  @override
  String get perfResultProfile => 'Profil';

  @override
  String get perfResultDevice => 'Appareil';

  @override
  String get perfResultOperatingSystem => 'OS';

  @override
  String get perfResultCpu => 'CPU';

  @override
  String get perfResultLogicalCores => 'Cœurs logiques';

  @override
  String get perfResultMeasurements => 'Mesures';

  @override
  String get perfSuitePrimitives => 'Primitives';

  @override
  String get perfSuitePartialSync => 'Synchronisation partielle';

  @override
  String get perfSuitePartialBlockProduction => 'Production de blocs';

  @override
  String get perfSuiteWalletSend => 'Envoi depuis le portefeuille';

  @override
  String get perfScenarioDefault => 'Cas par défaut';

  @override
  String perfContextTxCount(int count) {
    return '$count tx';
  }

  @override
  String perfContextBatchLayout(String value) {
    return 'Disposition $value';
  }

  @override
  String perfContextTransactionShape(String value) {
    return 'Forme $value';
  }

  @override
  String get perfDetailScenario => 'Scénario';

  @override
  String get perfDetailAverage => 'Moyenne';

  @override
  String get perfDetailMinMax => 'Min / Max';

  @override
  String get perfDetailRuns => 'Exécutions';

  @override
  String get perfDetailMetadataTitle => 'Détails du scénario';

  @override
  String get perfDetailImplementationTitle => 'Détails d’implémentation';

  @override
  String get perfDetailNotesTitle => 'Notes';

  @override
  String get perfDetailFlow => 'Flux';

  @override
  String get perfDetailTxCount => 'Nombre de transactions';

  @override
  String get perfDetailBatchLayout => 'Disposition du lot';

  @override
  String get perfDetailTransactionShape => 'Forme de la transaction';

  @override
  String get perfDetailTouchedLeaves => 'Feuilles touchées';

  @override
  String get perfDetailProofNodes => 'Nœuds de preuve';

  @override
  String get perfDetailProofSize => 'Taille de la preuve';

  @override
  String get perfCancelFailed => 'Impossible d’annuler le test en cours.';

  @override
  String get perfRunUnavailable => 'Ce test n’est plus disponible.';

  @override
  String get commonOk => 'OK';

  @override
  String get buildInfoVersion => 'Version';

  @override
  String get buildInfoCommit => 'Commit';

  @override
  String get buildInfoBranch => 'Branche';

  @override
  String get buildInfoCommitTime => 'Heure du commit';

  @override
  String get buildInfoRustc => 'Rustc';

  @override
  String get buildInfoLlvm => 'LLVM';

  @override
  String get buildInfoCargoTarget => 'Cible Cargo';

  @override
  String get buildInfoFeatures => 'Fonctionnalités';

  @override
  String get buildInfoOptLevel => 'Niveau d’optimisation';

  @override
  String get buildInfoDebug => 'Debug';

  @override
  String get retry => 'Réessayer';

  @override
  String get zkIdentityAppNotFoundTitle => 'Installez d’abord ZK Passport';

  @override
  String get zkIdentityAppNotFoundDetail =>
      'Il crée votre preuve, puis vous ramène ici';

  @override
  String get zkIdentityInstallCta => 'Installer';

  @override
  String get zkIdentityStepLabelOpenApp => 'Ouverture de ZK Passport';

  @override
  String get zkIdentityStepDescOpenApp =>
      'Préparation d’une demande de preuve avec votre passeport enregistré';

  @override
  String get zkIdentityCheckAppCta => 'Continuer';

  @override
  String get zkIdentityAccountPreparingTitle => 'Préparation de votre compte';

  @override
  String get zkIdentityAccountPreparingDescription =>
      'Connexion de votre compte Social Vibecoding';

  @override
  String get zkIdentityAccountUnavailable =>
      'Connectez-vous à Social Vibecoding avant de lancer la vérification.';

  @override
  String get zkIdentityStepLabelScan => 'Utiliser le passeport enregistré';

  @override
  String get zkIdentityStepDescScan =>
      'Utilise le passeport déjà stocké dans ZK Passport';

  @override
  String get zkIdentityConfirmScannedBody =>
      'Votre passeport enregistré sera utilisé.';

  @override
  String get zkIdentityConfirmScannedYesCta => 'Continuer';

  @override
  String get zkIdentityConfirmScannedNoCta => 'Pas maintenant';

  @override
  String get zkIdentityStepLabelReady => 'Créer la preuve';

  @override
  String get zkIdentityStepDescReady =>
      'ZK Passport vous demandera d’approuver et de créer la preuve';

  @override
  String get zkIdentityReadyBody =>
      'ZK Passport génère la preuve à partir de votre passeport enregistré en une minute environ.';

  @override
  String get zkIdentityReadyBullet1 =>
      'Aucun nom, photo ni pièce d’identité n’est partagé';

  @override
  String get zkIdentityReadyBullet2 => 'Vous n’envoyez qu’une preuve';

  @override
  String get zkIdentityReadyBullet3 =>
      'Aucune donnée personnelle n’est stockée sur la blockchain';

  @override
  String get zkIdentityReadyCta => 'Ouvrir ZK Passport';

  @override
  String get zkIdentityStepLabelVerifying => 'Vérification';

  @override
  String get zkIdentityStepDescVerifying =>
      'Création et contrôle de votre preuve';

  @override
  String get zkIdentityStepLabelResult => 'Résultat';

  @override
  String get zkIdentityStepDescResult =>
      'Consultez le résultat de votre vérification';

  @override
  String get zkIdentitySubTaskOpening => 'Ouverture de ZK Passport';

  @override
  String get zkIdentitySubTaskWaiting => 'En attente de votre preuve';

  @override
  String get zkIdentitySubTaskChecking => 'Contrôle de votre preuve';

  @override
  String get zkIdentitySubTaskWrapping => 'Emballage de votre preuve';

  @override
  String get zkIdentitySubTaskFinal => 'Contrôle final';

  @override
  String get zkIdentityResultSuccessTitle => 'Vous êtes un humain unique !';

  @override
  String get zkIdentityResultSuccessSubtitle =>
      'Vous avez prouvé que vous êtes unique sans partager votre nom, votre photo ni votre pièce d’identité';

  @override
  String get zkIdentityStatusUniqueness => 'Humain unique';

  @override
  String get zkIdentityStatusUniquenessValue => 'Confirmé';

  @override
  String get zkIdentityStatusFaceMatchLabel => 'Contrôle du visage';

  @override
  String get zkIdentityStatusPrivacyValue => 'Rien de partagé';

  @override
  String get zkIdentityCancelVerification => 'Annuler';

  @override
  String get zkIdentityGoToZkPassport => 'Passer à ZK Passport';

  @override
  String get zkIdentityTryAgain => 'Réessayer';

  @override
  String get zkIdentityWalletClaimTitle =>
      'Connectez votre portefeuille du programme';

  @override
  String get zkIdentityWalletClaimDescription =>
      'Ce compte Social est différent du compte qui détient votre portefeuille existant. Vérifiez une fois l’e-mail de votre programme d’origine pour le connecter.';

  @override
  String get zkIdentityWalletClaimEmailLabel => 'E-mail du programme d’origine';

  @override
  String get zkIdentityWalletClaimEmailHelper =>
      'Utilisez l’e-mail de votre inscription au programme Homeroom d’origine.';

  @override
  String get zkIdentityWalletClaimSendCode => 'Envoyer le code de vérification';

  @override
  String get zkIdentityWalletClaimSendingCode => 'Envoi du code…';

  @override
  String get zkIdentityWalletClaimCodeSent =>
      'Saisissez le code à 6 chiffres envoyé à cet e-mail.';

  @override
  String get zkIdentityWalletClaimCodeLabel => 'Code de vérification';

  @override
  String get zkIdentityWalletClaimConnect =>
      'Connecter le portefeuille et continuer';

  @override
  String get zkIdentityWalletClaimConnecting => 'Connexion du portefeuille…';

  @override
  String get zkIdentityWalletClaimChangeEmail => 'Utiliser un autre e-mail';

  @override
  String get zkIdentityWalletClaimEmailRequired =>
      'Saisissez une adresse e-mail valide.';

  @override
  String get zkIdentityWalletClaimCodeRequired =>
      'Saisissez le code à 6 chiffres.';

  @override
  String get zkIdentityWalletClaimRetryFailed =>
      'Votre portefeuille est connecté, mais l’app n’a pas pu finir de le préparer. Réessayez.';

  @override
  String get zkIdentityDone => 'Terminé';

  @override
  String get zkIdentityStatusFaceMatchVerified => 'Vérifié';

  @override
  String get zkIdentityStatusFaceMatchNotRequested => 'Ignoré';

  @override
  String get zkIdentityStatusPrivacyLabel => 'Confidentialité';

  @override
  String get zkIdentityStatusVerifiedDateLabel => 'Vérifié le';

  @override
  String get zkIdentityStatusProofIdLabel => 'ID de la preuve';

  @override
  String get zkIdentityStatusVerifyDurationLabel => 'Vérification';

  @override
  String get zkIdentityStatusWrapDurationLabel => 'Emballage';

  @override
  String get zkIdentityStatusFinalCheckLabel => 'Contrôle final';

  @override
  String get zkIdentityResultFailureTitle => 'Vérification impossible';

  @override
  String get zkIdentityResultFailureSubtitle =>
      'Vous n’avez partagé ni votre nom, ni votre photo, ni votre pièce d’identité';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonCopied => 'Copié';

  @override
  String get buildInfoAppVersion => 'Version de l’app';

  @override
  String get buildInfoBuildNumber => 'Numéro de build';

  @override
  String get settingsDebugMode => 'Mode débogage';

  @override
  String get settingsDebugModeEnabled => 'Capture des requêtes HTTP en mémoire';

  @override
  String get settingsDebugModeDisabled => 'Désactivé · aucun journal réseau';

  @override
  String get settingsHttpLogs => 'Journaux HTTP';

  @override
  String get settingsHttpLogsSubtitle => 'Voir les requêtes réseau capturées';

  @override
  String get httpLogsTitle => 'Journaux HTTP';

  @override
  String get httpLogsEmpty =>
      'Aucune requête capturée pour l’instant. Générez de l’activité réseau pour voir les journaux ici.';

  @override
  String get httpLogsCopy => 'Tout copier';

  @override
  String get httpLogsClear => 'Effacer';

  @override
  String get httpLogsCopied => 'Journaux copiés dans le presse-papiers';

  @override
  String get httpLogsShare => 'Partager les journaux avec l’équipe';

  @override
  String get httpLogsSharing =>
      'Partage des journaux avec l’équipe toutes les 30 s…';

  @override
  String get httpLogsStopSharing => 'Arrêter le partage';

  @override
  String get httpLogsShareStopped =>
      'Le serveur a arrêté le partage des journaux. Vous pouvez le relancer à tout moment.';

  @override
  String get httpLogsShareNoParticipant =>
      'Pas encore d’ID de participant : terminez l’intégration pour partager les journaux';

  @override
  String get httpLogsFilterHint => 'Filtrer par URL';

  @override
  String get httpLogsNoMatches => 'Aucune requête ne correspond au filtre.';

  @override
  String httpLogsFilterCount(int count, int total) {
    return '$count sur $total';
  }

  @override
  String get widgetInstructionsTitle => 'Ajoutez le widget Homeroom';

  @override
  String widgetInstructionsBody(String name) {
    return '$name a été ajouté à votre widget dApps Homeroom. Pour le voir sur l’écran d’accueil, ajoutez le widget une fois :';
  }

  @override
  String get widgetInstructionsStep1 =>
      'Maintenez le doigt sur une zone vide de l’écran d’accueil';

  @override
  String get widgetInstructionsStep2 =>
      'Touchez Modifier dans le coin supérieur, puis Ajouter un widget';

  @override
  String get widgetInstructionsStep3 =>
      'Cherchez Homeroom et ajoutez le widget dApps';

  @override
  String get widgetInstructionsDone => 'Terminé';

  @override
  String get svShellConnectingTitle => 'Connexion à Homeroom…';

  @override
  String get svShellOfflineMessage =>
      'Impossible de joindre Homeroom. Vérifiez votre connexion et réessayez.';

  @override
  String get stakingManagerTitle => 'Mode de staking';

  @override
  String get stakingDelegateIntro =>
      'Déléguez votre stake au serveur. Votre nœud continue de tourner, mais le serveur fait le staking à votre place.';

  @override
  String get stakingServerName => 'Serveur';

  @override
  String get stakingDelegateEffect =>
      'Votre nœud cesse de produire des blocs. Pendant la délégation, vous recevez la moitié des points de production de blocs que vous gagneriez en produisant des blocs directement sur ce téléphone.';

  @override
  String get stakingDelegateNote =>
      'Vous pouvez reprendre le staking vous-même à tout moment.';

  @override
  String get stakingDelegateConfirm => 'Confirmer la délégation';

  @override
  String get stakingDelegating => 'Délégation…';

  @override
  String get stakingDelegateError =>
      'Impossible d’envoyer la délégation. Vérifiez votre connexion et réessayez.';

  @override
  String get stakingDelegationActiveTitle => 'Délégation active';

  @override
  String stakingDelegationActiveBody(String validator) {
    return 'Votre stake est délégué à $validator. Vous recevez la moitié des points de production de blocs que vous gagneriez en produisant des blocs directement sur ce téléphone.';
  }

  @override
  String get stakingDone => 'Terminé';

  @override
  String get stakingUndelegateTitle => 'Arrêter la délégation ?';

  @override
  String get stakingUndelegateBody =>
      'Votre stake revient sur ce téléphone. Votre nœud produira directement des blocs et gagnera la totalité des points de production de blocs.';

  @override
  String get stakingUndelegateConfirm => 'Arrêter la délégation';

  @override
  String get stakingUndelegateError =>
      'Impossible d’arrêter la délégation. Vérifiez votre connexion et réessayez.';

  @override
  String get versionUpdateRequiredTitle => 'Mise à jour requise';

  @override
  String get versionUpdateAvailableTitle => 'Mise à jour disponible';

  @override
  String get versionUpdateAction => 'Mettre à jour';

  @override
  String get versionUpdateLater => 'Plus tard';

  @override
  String get versionUpdateFallbackMessage =>
      'Une nouvelle version de l’app est disponible.';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonDeny => 'Refuser';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonApprove => 'Approuver';

  @override
  String get txConfirmTitle => 'Confirmer la transaction';

  @override
  String get txConfirmSubtitleDefault =>
      'Une dapp demande l’envoi d’une transaction.';

  @override
  String get txAmount => 'Montant';

  @override
  String get txDetails => 'Détails';

  @override
  String get txFrom => 'De';

  @override
  String get txTo => 'À';

  @override
  String get txFee => 'Frais';

  @override
  String get txMemo => 'Mémo';

  @override
  String get verifyIdentityTitle => 'Vérifier l’identité';

  @override
  String verifyIdentityRequest(String name) {
    return '$name demande à vérifier votre identité';
  }

  @override
  String get verifyIdentityExplanation =>
      'Cela signera un défi avec votre clé privée pour prouver que ce portefeuille est le vôtre. Aucune transaction ne sera envoyée et aucun jeton ne sera dépensé.';

  @override
  String get zkChallengeBusy =>
      'Une preuve zkPassport est encore en cours de traitement. Réessayez dans un instant.';

  @override
  String get zkChallengeResetDone => 'État de la preuve ZK réinitialisé';
}
