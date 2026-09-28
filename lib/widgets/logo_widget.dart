import 'dart:io';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  final String? customPath;
  final bool isWatermark;
  final double opacity;

  const LogoWidget({
    super.key,
    this.size = 64,
    this.customPath,
    this.isWatermark = false,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (customPath != null && customPath!.isNotEmpty && File(customPath!).existsSync()) {
      imageWidget = Image.file(
        File(customPath!),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else {
      imageWidget = Image.asset(
        AppConstants.defaultLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    if (isWatermark) {
      return IgnorePointer(
        child: Opacity(
          opacity: opacity > 0 ? opacity : 0.06,
          child: imageWidget,
        ),
      );
    }

    if (opacity < 1.0) {
      return Opacity(
        opacity: opacity,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.15),
        border: Border.all(color: AppColors.accent, width: size * 0.03),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'M',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.45,
              height: 1.0,
            ),
          ),
          if (size >= 60)
            Text(
              'MIGHTY',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.13,
                letterSpacing: 1.0,
              ),
            ),
        ],
      ),
    );
  }
}
