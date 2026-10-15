import '../../core/currency/currency.dart';

/// A debt payment (row of `customer_payments`).
///
/// [amount] / [currency] is what the customer actually handed over;
/// [appliedAmount] / [appliedCurrency] is what was deducted from the debt,
/// converted at [exchangeRate] when the payment was made.
class CustomerPayment {
  const CustomerPayment({
    required this.id,
    required this.customerId,
    required this.transactionId,
    required this.amount,
    required this.currency,
    required this.exchangeRate,
    required this.appliedAmount,
    required this.appliedCurrency,
    required this.note,
    required this.createdAt,
    required this.isVoided,
  });

  final int id;
  final int customerId;
  final int? transactionId;
  final int amount;
  final Currency currency;
  final double exchangeRate;
  final int appliedAmount;
  final Currency appliedCurrency;
  final String? note;
  final String createdAt;
  final bool isVoided;

  DateTime get createdAtLocal => DateTime.parse(createdAt).toLocal();

  factory CustomerPayment.fromMap(Map<String, Object?> map) {
    return CustomerPayment(
      id: map['id'] as int,
      customerId: map['customer_id'] as int,
      transactionId: map['transaction_id'] as int?,
      amount: map['amount'] as int,
      currency: Currency.fromCode(map['currency'] as String),
      exchangeRate: (map['exchange_rate'] as num).toDouble(),
      appliedAmount: map['applied_amount'] as int,
      appliedCurrency: Currency.fromCode(map['applied_currency'] as String),
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
      isVoided: ((map['is_voided'] as int?) ?? 0) == 1,
    );
  }
}
