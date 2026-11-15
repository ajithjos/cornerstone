import 'package:flutter/material.dart';

/// Host-owned semantic colours. Packages use these tokens instead of choosing
/// their own app palette. The object contains no learner or authentication data.
Map<String, dynamic> activityPackageAppearance(ThemeData theme) {
  final colors = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  String hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  return {
    'mode': dark ? 'dark' : 'light',
    'colors': {
      'background': hex(theme.scaffoldBackgroundColor),
      'surface': hex(colors.surface),
      'surface-muted': hex(colors.surfaceContainerLow),
      'text': hex(colors.onSurface),
      'muted': hex(colors.onSurfaceVariant),
      'border': hex(colors.outlineVariant),
      'primary': hex(colors.primary),
      'on-primary': hex(colors.onPrimary),
      'primary-container': hex(colors.primaryContainer),
      'on-primary-container': hex(colors.onPrimaryContainer),
      'error': hex(colors.error),
      'error-container': hex(colors.errorContainer),
      'on-error-container': hex(colors.onErrorContainer),
      'success': dark ? '#9cd8ac' : '#236b3c',
      'success-container': dark ? '#203e2a' : '#e9f5ec',
      'focus': hex(colors.primary),
    },
  };
}
