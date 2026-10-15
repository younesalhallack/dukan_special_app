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
    };
  }
  return '$error';
}
