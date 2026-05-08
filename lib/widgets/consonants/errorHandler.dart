import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ride_sharing/widgets/consonants/apiException.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// One place to turn any thrown object into a user-facing string,
/// classify it, and surface it in the UI. Use this everywhere — providers
/// (when setting `state.error`), screens (in `catch` blocks), services
/// (when normalising third-party exceptions).
///
/// Example — provider:
///   } catch (e) {
///     state = state.copyWith(error: ErrorHandler.message(e));
///   }
///
/// Example — screen:
///   } catch (e) {
///     ErrorHandler.show(context, e);
///   }
class ErrorHandler {
  ErrorHandler._();

  /// Convert any error/exception into a clean message safe to show to the
  /// user. Strips the `Exception:` prefix, picks meaningful messages out of
  /// platform/http errors, and falls back to a generic catch-all.
  static String message(Object? error) {
    if (error == null) return 'Something went wrong.';

    if (error is ApiException) return error.message;

    if (error is SocketException) {
      return 'No internet connection. Please check your network.';
    }
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }
    if (error is http.ClientException) {
      return 'Network error: ${error.message}';
    }
    if (error is FormatException) {
      return 'Invalid response from server.';
    }
    if (error is Exception) {
      // Strip the "Exception: " prefix that Dart's default toString adds.
      final raw = error.toString();
      return raw.startsWith('Exception: ')
          ? raw.substring('Exception: '.length)
          : raw;
    }
    if (error is Error) {
      return error.toString();
    }
    return error.toString();
  }

  /// HTTP status code, or `0` for transport/unknown errors. Useful when
  /// callers need to special-case 401 (kick to login), 409 (already exists),
  /// etc.
  static int statusCode(Object? error) {
    if (error is ApiException) return error.statusCode;
    return 0;
  }

  static bool isUnauthorized(Object? error) =>
      error is ApiException && error.isUnauthorized;
  static bool isBadRequest(Object? error) =>
      error is ApiException && error.isBadRequest;
  static bool isNotFound(Object? error) =>
      error is ApiException && error.isNotFound;
  static bool isConflict(Object? error) =>
      error is ApiException && error.isConflict;
  static bool isServerError(Object? error) =>
      error is ApiException && error.isServerError;
  static bool isNetworkError(Object? error) =>
      error is ApiException
          ? error.isNetworkError
          : (error is SocketException ||
              error is TimeoutException ||
              error is http.ClientException);

  /// Show an error snackbar for any thrown object. Safe to call with the
  /// raw `e` from a `catch (e)` block — handles message extraction.
  static void show(BuildContext context, Object? error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(CustomWidgets.customErrorSnackBar(message(error)));
  }

  /// Show a success snackbar — paired here so success/error rendering lives
  /// in one place and stays visually consistent.
  static void success(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(CustomWidgets.customSuccessSnackBar(message));
  }
}
