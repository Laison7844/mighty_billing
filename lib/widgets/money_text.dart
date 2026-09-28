import 'package:flutter/material.dart';
import '../core/utils/currency_formatter.dart';

class MoneyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool showDecimals;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;

  const MoneyText({
    super.key,
    required this.amount,
    this.style,
    this.textAlign,
    this.showDecimals = true,
    this.color,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = CurrencyFormatter.format(amount, showDecimals: showDecimals);
    final effectiveStyle = (style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );

    return Text(
      formatted,
      textAlign: textAlign,
      style: effectiveStyle,
    );
  }
}
