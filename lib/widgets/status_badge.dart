import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/invoice.dart';

class StatusBadge extends StatelessWidget {
  final PaymentStatus status;
  final bool isLarge;

  const StatusBadge({
    super.key,
    required this.status,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (status) {
      case PaymentStatus.paid:
        bg = AppColors.paidContainer;
        fg = AppColors.paidGreen;
        border = const Color(0xFFA7F3D0);
        break;
      case PaymentStatus.partiallyPaid:
        bg = AppColors.partialContainer;
        fg = AppColors.partialOrange;
        border = const Color(0xFFFDE68A);
        break;
      case PaymentStatus.unpaid:
        bg = AppColors.unpaidContainer;
        fg = AppColors.unpaidRed;
        border = const Color(0xFFFECACA);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : 8,
        vertical: isLarge ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isLarge ? 8 : 6,
            height: isLarge ? 8 : 6,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: fg,
              fontSize: isLarge ? 12 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
