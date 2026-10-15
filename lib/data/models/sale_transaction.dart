import '../../core/currency/currency.dart';
import 'transaction_item.dart';

enum PaymentType {
  cash('cash'),
  credit('credit');

  const PaymentType(this.code);
  final String code;

  static PaymentType fromCode(String code) =>
      values.firstWhere((type) => type.code == code);
}

enum InvoiceStatus {
  completed('completed'),
  voided('voided');

  const InvoiceStatus(this.code);
  final String code;

  static InvoiceStatus fromCode(String code) =>
      values.firstWhere((status) => status.code == code);
}

/// An invoice (row of the `transactions` table).
///
/// All amounts are minor units of [currency]. [exchangeRate] (SYP per 1 USD)
/// is the rate frozen when the invoice was created.
class SaleTransaction {
  const SaleTransaction({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.currency,
    required this.exchangeRate,
    required this.totalAmount,
    required this.discountAmount,
    required this.paidAmount,
    required this.totalCost,
    required this.paymentType,
    required this.status,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final String invoiceNumber;
  final int? customerId;
  final Currency currency;
  final double exchangeRate;

  /// Amount to pay, after the discount.
  final int totalAmount;
  final int discountAmount;
  final int paidAmount;
  final int totalCost;
  final PaymentType paymentType;
  final InvoiceStatus status;
  final String? note;
  final String createdAt;

  int get subtotal => totalAmount + discountAmount;
  int get profit => totalAmount - totalCost;

  /// What the customer still owes on this invoice (credit sales).
  int get debtAmount => totalAmount - paidAmount;

  bool get isVoided => status == InvoiceStatus.voided;
  DateTime get createdAtLocal => DateTime.parse(createdAt).toLocal();

  factory SaleTransaction.fromMap(Map<String, Object?> map) {
    return SaleTransaction(
      id: map['id'] as int,
      invoiceNumber: map['invoice_number'] as String,
      customerId: map['customer_id'] as int?,
      currency: Currency.fromCode(map['currency'] as String),
      exchangeRate: (map['exchange_rate'] as num).toDouble(),
      totalAmount: map['total_amount'] as int,
      discountAmount: (map['discount_amount'] as int?) ?? 0,
      paidAmount: map['paid_amount'] as int,
      totalCost: map['total_cost'] as int,
      paymentType: PaymentType.fromCode(map['payment_type'] as String),
      status: InvoiceStatus.fromCode(map['status'] as String),
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

/// An invoice together with its line items.
class InvoiceDetails {
  const InvoiceDetails({required this.transaction, required this.items});

  final SaleTransaction transaction;
  final List<TransactionItem> items;
}
