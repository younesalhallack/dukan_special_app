import '../../../core/currency/currency.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/sale_transaction.dart';
import '../../../data/models/supplier_payment.dart';

enum SupplierLedgerEntryKind { purchase, payment }

/// One line of a supplier's statement.
class SupplierLedgerEntry {
  const SupplierLedgerEntry({
    required this.kind,
    required this.date,
    required this.currency,
    required this.delta,
    required this.isVoided,
    required this.balanceAfter,
    this.purchase,
    this.payment,
  });

  final SupplierLedgerEntryKind kind;
  final DateTime date;

  /// The currency of the debt this entry affects.
  final Currency currency;

  /// Change of what the shop owes: positive for a credit purchase (what was
  /// left unpaid), negative for a payment (what was deducted).
  final int delta;

  /// Voided purchases and payments are listed but do not count.
  final bool isVoided;

  /// Running balance in [currency] after this entry; null when voided.
  final int? balanceAfter;

  final Purchase? purchase;
  final SupplierPayment? payment;
}

/// Merges credit purchases and payments into a statement with running
/// balances per currency. Pure function.
abstract final class SupplierLedgerBuilder {
  /// Entries in chronological order (oldest first).
  static List<SupplierLedgerEntry> build({
    required List<Purchase> purchases,
    required List<SupplierPayment> payments,
  }) {
    final items = <_Item>[
      for (final purchase in purchases)
        if (purchase.paymentType == PaymentType.credit)
          _Item(
            kind: SupplierLedgerEntryKind.purchase,
            date: purchase.purchaseDateLocal,
            id: purchase.id,
            currency: purchase.currency,
            delta: purchase.debtAmount,
            voided: purchase.isVoided,
            purchase: purchase,
          ),
      for (final payment in payments)
        _Item(
          kind: SupplierLedgerEntryKind.payment,
          date: payment.createdAtLocal,
          id: payment.id,
          currency: payment.appliedCurrency,
          delta: -payment.appliedAmount,
          voided: payment.isVoided,
          payment: payment,
        ),
    ];

    // Oldest first; at the same instant a purchase comes before a payment.
    items.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      return a.id.compareTo(b.id);
    });

    final running = <Currency, int>{};
    final entries = <SupplierLedgerEntry>[];
    for (final item in items) {
      int? balanceAfter;
      if (!item.voided) {
        balanceAfter = (running[item.currency] ?? 0) + item.delta;
        running[item.currency] = balanceAfter;
      }
      entries.add(SupplierLedgerEntry(
        kind: item.kind,
        date: item.date,
        currency: item.currency,
        delta: item.delta,
        isVoided: item.voided,
        balanceAfter: balanceAfter,
        purchase: item.purchase,
        payment: item.payment,
      ));
    }
    return entries;
  }
}

class _Item {
  const _Item({
    required this.kind,
    required this.date,
    required this.id,
    required this.currency,
    required this.delta,
    required this.voided,
    this.purchase,
    this.payment,
  });

  final SupplierLedgerEntryKind kind;
  final DateTime date;
  final int id;
  final Currency currency;
  final int delta;
  final bool voided;
  final Purchase? purchase;
  final SupplierPayment? payment;
}
