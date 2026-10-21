import '../../l10n/l10n.dart';
import 'app_exceptions.dart';

/// Turns any error into a message the user can read.
String errorMessage(AppLocalizations l10n, Object error) {
  if (error is AppException) {
    return switch (error.error) {
      AppError.invalidName => l10n.errInvalidName,
      AppError.invalidPrice => l10n.errInvalidPrice,
      AppError.invalidQuantity => l10n.errInvalidQuantity,
      AppError.duplicateBarcode => l10n.errDuplicateBarcode,
      AppError.duplicateCategory => l10n.errDuplicateCategory,
      AppError.negativeStock => l10n.errNegativeStock,
      AppError.notFound => l10n.errNotFound,
      AppError.emptyCart => l10n.errEmptyCart,
      AppError.invalidAmount => l10n.errInvalidAmount,
      AppError.insufficientStock => l10n.errInsufficientStock,
      AppError.alreadyVoided => l10n.errAlreadyVoided,
      AppError.customerRequired => l10n.errCustomerRequired,
      AppError.customerHasDebt => l10n.errCustomerHasDebt,
      AppError.paymentExceedsDebt => l10n.errPaymentExceedsDebt,
      AppError.noDebt => l10n.errNoDebt,
      AppError.supplierRequired => l10n.errSupplierRequired,
      AppError.supplierHasDebt => l10n.errSupplierHasDebt,
      AppError.noPayable => l10n.errNoPayable,
      AppError.emptyPurchase => l10n.errEmptyPurchase,
    };
  }
  if (error is BackupException) {
    return switch (error.error) {
      BackupError.notSqlite => l10n.errBackupNotSqlite,
      BackupError.corrupt => l10n.errBackupCorrupt,
      BackupError.notOurDatabase => l10n.errBackupNotOurs,
      BackupError.newerVersion => l10n.errBackupNewerVersion,
      BackupError.readFailed => l10n.errBackupReadFailed,
      BackupError.restoreFailed => l10n.errRestoreFailed,
    };
  }
  return '$error';
}
