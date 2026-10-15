import '../utils/digits.dart';
import 'currency.dart';

/// Pure money helpers: conversion, rounding, formatting and parsing.
///
/// Amounts are INTEGER minor units. The exchange [rate] is always
/// "SYP per 1 USD".
abstract final class Money {
  /// Converts [minor] from one currency to the other at [rate].
  /// No step rounding is applied (use this for debts, payments and profit).
  static int convert(
    int minor, {
    required Currency from,
    required Currency to,
    required double rate,
  }) {
    if (from == to) return minor;
    final major = minor / from.minorFactor;
    final target = from == Currency.usd ? major * rate : major / rate;
    return (target * to.minorFactor).round();
  }

  /// Rounds [minor] UP to the next multiple of [step]. Steps of 1 or less
  /// leave the value unchanged.
  static int roundUpToStep(int minor, int step) {
    if (step <= 1 || minor <= 0) return minor;
    final remainder = minor % step;
    return remainder == 0 ? minor : minor + (step - remainder);
  }

  /// Price shown or charged in [to], derived from a price in [from].
  ///
  /// A price converted into SYP is rounded up to [sypStep] to protect the
  /// margin when the rate moves. A price already in the target currency is
  /// returned untouched.
  static int salePriceIn({
    required int amountMinor,
    required Currency from,
    required Currency to,
    required double rate,
    required int sypStep,
  }) {
    if (from == to) return amountMinor;
    final converted = convert(amountMinor, from: from, to: to, rate: rate);
    return to == Currency.syp ? roundUpToStep(converted, sypStep) : converted;
  }

  /// A sensible SYP rounding step for a given rate magnitude.
  static int suggestedRoundingStep(double rate) {
    if (rate >= 5000) return 100;
    if (rate >= 500) return 10;
    return 1;
  }

  /// True when [newRate] differs from [oldRate] by more than [threshold]
  /// (a fraction, 0.2 = 20%). Used to catch typing mistakes.
  static bool isLargeRateChange(
    double oldRate,
    double newRate, {
    double threshold = 0.2,
  }) {
    if (oldRate <= 0) return false;
    return (newRate - oldRate).abs() / oldRate > threshold;
  }

  /// Formats [minor] for display, e.g. `1,234.50 $` or `150,000 ل.س`.
  static String format(
    int minor,
    Currency currency, {
    DigitStyle digits = DigitStyle.western,
    bool withSymbol = true,
  }) {
    final negative = minor < 0;
    final abs = minor.abs();
    final whole = abs ~/ currency.minorFactor;
    final fraction = abs % currency.minorFactor;
    var text = _group(whole.toString());
    if (currency.decimals > 0) {
      text = '$text.${fraction.toString().padLeft(currency.decimals, '0')}';
    }
    if (negative) text = '-$text';
    text = Digits.localize(text, digits);
    return withSymbol ? '$text ${currency.symbol}' : text;
  }

  /// Formats an exchange rate: grouped, up to 2 decimals, no trailing zeros.
  static String formatRate(
    double rate, {
    DigitStyle digits = DigitStyle.western,
  }) {
    final parts = rate.toStringAsFixed(2).split('.');
    final fraction = parts[1].replaceFirst(RegExp(r'0+$'), '');
    var text = _group(parts[0]);
    if (fraction.isNotEmpty) text = '$text.$fraction';
    return Digits.localize(text, digits);
  }

  /// Parses a user-typed non-negative number. Accepts Arabic-Indic digits,
  /// `٫` as decimal point, and `,` `٬` `،` or spaces as thousands separators.
  /// Returns null when the text is not a valid number.
  static double? parseDecimal(String input) {
    final cleaned = Digits.toWestern(input).replaceAll(RegExp(r'[\s,]'), '');
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) return null;
    return double.tryParse(cleaned);
  }

  /// Parses a user-typed amount into minor units of [currency].
  static int? parse(String input, Currency currency) {
    final value = parseDecimal(input);
    if (value == null) return null;
    return (value * currency.minorFactor).round();
  }

  static String _group(String digits) {
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}
