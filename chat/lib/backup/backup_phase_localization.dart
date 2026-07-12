import 'package:chat/l10n/app_localizations.dart';

/// Maps backup progress phase keys to localized strings.
///
/// The [BackupManager] emits phase keys (e.g. `"backupConversations"`) so that
/// progress UI can be translated. Unknown phases are returned as-is.
String localizeBackupPhase(AppLocalizations l10n, String? phase) {
  switch (phase) {
    case 'backupConversations':
      return l10n.backupConversations;
    case 'creatingLocalBackup':
      return l10n.creatingLocalBackup;
    case 'uploadingToPC':
      return l10n.uploadingToPC;
    case 'restoringConversations':
      return l10n.restoringConversations;
    case 'downloadingFiles':
      return l10n.downloadingFiles;
    default:
      return phase ?? '';
  }
}
