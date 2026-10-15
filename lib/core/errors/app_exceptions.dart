/// Business-rule errors raised by repositories. The UI maps each code to a
/// localized message with `errorMessage` (see error_messages.dart).
enum AppError {
  invalidName,
  invalidPrice,
  invalidQuantity,
  duplicateBarcode,
  duplicateCategory,
  negativeStock,
  notFound,
  emptyCart,
  invalidAmount,
  insufficientStock,
  alreadyVoided,
  customerRequired,
  customerHasDebt,
  paymentExceedsDebt,
  noDebt,
}

class AppException implements Exception {
  const AppException(this.error);

  final AppError error;

  @override
  String toString() => 'AppException(${error.name})';
}
