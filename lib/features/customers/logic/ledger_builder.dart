import '../../../core/currency/currency.dart';
import '../../../data/models/customer_payment.dart';
import '../../../data/models/sale_transaction.dart';

enum LedgerEntryKind { invoice, payment }

/// One line of a customer's statement.
class LedgerEntry {
  const LedgerEntry({
    required this.kind,
    required this.date,
    required this.currency,
    required this.delta,
    required this.isVoided,
    required this.balanceAfter,
    this.invoice,
    this.payment,
  });

  final LedgerEntryKind kind;
  final DateTime date;

  /// The currency of the debt this entry affects.
  final Currency currency;

  /// Change of the debt: positive for a credit invoice (what was left unpaid),
  /// negative for a payment (what was deducted).
  final int delta;

  /// Voided invoices and payments are listed but do not count.
  final bool isVoided;

  /// Running balance in [currency] after this entry; null when voided.
  final int? balanceAfter;

  final SaleTransaction? invoice;
  final CustomerPayment? payment;
}

/// Merges credit invoices and payments into a statement with running
/// balances per currency. Pure function.
abstract final class LedgerBuilder {
  /// Entries in chronological order (oldest first).
  static List<LedgerEntry> build({
    required List<SaleTransaction> invoices,
    required List<CustomerPayment> payments,
  }) {
    final items = <_Item>[
      for (final invoice in invoices)
        if (invoice.paymentType == PaymentType.credit)
          _Item(
            kind: LedgerEntryKind.invoice,
            date: invoice.createdAtLocal,
            id: invoice.id,
            currency: invoice.currency,
            delta: invoice.debtAmount,
            voided: invoice.isVoided,
            invoice: invoice,
          ),
      for (final payment in payments)
        _Item(
          kind: LedgerEntryKind.payment,
          date: payment.createdAtLocal,
          id: payment.id,
          currency: payment.appliedCurrency,
          delta: -payment.appliedAmount,
          voided: payment.isVoided,
          payment: payment,
        ),
    ];

    // Oldest first; at the same instant an invoice comes before a payment.
    items.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      return a.id.compareTo(b.id);
    });

    final running = <Currency, int>{};
    final entries = <LedgerEntry>[];
    for (final item in items) {
      int? balanceAfter;
      if (!item.voided) {
        balanceAfter = (running[item.currency] ?? 0) + item.delta;
        running[item.currency] = balanceAfter;
      }
      entries.add(LedgerEntry(
        kind: item.kind,
        date: item.date,
        currency: item.currency,
        delta: item.delta,
        isVoided: item.voided,
        balanceAfter: balanceAfter,
        invoice: item.invoice,
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
    this.invoice,
    this.payment,
  });

  final LedgerEntryKind kind;
  final DateTime date;
  final int id;
  final Currency currency;
  final int delta;
  final bool voided;
  final SaleTransaction? invoice;
  final CustomerPayment? payment;
}
