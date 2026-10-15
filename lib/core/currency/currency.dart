/// Currencies supported by the app.
///
/// All money is stored as INTEGER minor units:
///  * USD: cents (1 USD = 100 minor units)
///  * SYP: whole units (1 SYP = 1 minor unit)
enum Currency {
  usd('USD', 100, 2, r'$'),
  syp('SYP', 1, 0, 'ل.س');

  const Currency(this.code, this.minorFactor, this.decimals, this.symbol);

  /// ISO-like code stored in the database.
  final String code;

  /// How many minor units make one whole unit.
  final int minorFactor;

  /// Decimal digits shown to the user.
  final int decimals;

  /// Short symbol used when formatting amounts.
  final String symbol;

  Currency get other => this == Currency.usd ? Currency.syp : Currency.usd;

  static Currency? tryFromCode(String? code) {
    for (final currency in values) {
      if (currency.code == code) return currency;
    }
    return null;
  }

  static Currency fromCode(String code) =>
      tryFromCode(code) ??
      (throw ArgumentError.value(code, 'code', 'Unknown currency'));
}
