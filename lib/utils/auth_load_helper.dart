import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

/// Runs [fn] with the current access token. Returns the result or null on no token/error.
/// If [mounted] and [showErrorSnackBar] are true, shows a SnackBar on exception.
Future<T?> loadWithAuth<T>(
  BuildContext context, {
  required Future<T> Function(String token) fn,
  bool showErrorSnackBar = true,
  void Function(bool loading)? onLoading,
}) async {
  final token = context.read<AuthService>().accessToken;
  if (token == null || token.isEmpty) {
    return null;
  }
  onLoading?.call(true);
  try {
    final result = await fn(token);
    return result;
  } catch (e) {
    if (showErrorSnackBar && context.mounted) {
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(msg.length > 80 ? 'Ошибка' : msg),
          backgroundColor: Colors.red,
        ),
      );
    }
    rethrow;
  } finally {
    if (context.mounted) onLoading?.call(false);
  }
}
