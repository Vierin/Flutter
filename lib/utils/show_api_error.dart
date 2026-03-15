import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Shows a SnackBar with the error message. Handles [ApiException] and generic [Exception].
void showApiError(BuildContext context, dynamic e, {Color? backgroundColor}) {
  if (!context.mounted) return;
  final message = e is ApiException
      ? e.message
      : e is Exception
          ? e.toString()
          : e?.toString() ?? 'Unknown error';
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor ?? Colors.red.shade700,
    ),
  );
}

/// Shows a success SnackBar.
void showSuccess(BuildContext context, String message, {Color? backgroundColor}) {
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor ?? Colors.green.shade700,
    ),
  );
}
