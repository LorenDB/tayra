import 'package:dio/dio.dart';

/// A short explanation of a failed load, fit to show under an error icon.
///
/// Exceptions print for developers ("DioException [connection error]: The
/// connection errored: … SocketException: Failed host lookup …"). This turns
/// the common cases into a sentence the user can act on, and falls back to
/// the exception's own text only when that is already short and plain.
String describeLoadError(Object error) {
  if (error is DioException) {
    final type = error.type;
    if (type == DioExceptionType.badResponse) {
      return _describeStatus(error.response?.statusCode);
    }
    if (type == DioExceptionType.badCertificate) {
      return "The server's security certificate could not be verified.";
    }
    if (type == DioExceptionType.cancel) return 'The request was cancelled.';
    // Matched by name so a timeout kind added by a newer Dio (it has grown
    // one before) is still described as a timeout.
    if (type.name.endsWith('Timeout')) {
      return 'The server took too long to respond.';
    }
    return "Can't reach the server. Check your connection.";
  }
  if (error is FormatException || error is TypeError) {
    return 'The server sent data this app could not read.';
  }

  var text = error.toString().trim();
  const prefix = 'Exception: ';
  if (text.startsWith(prefix)) text = text.substring(prefix.length);
  final isPlain = text.isNotEmpty && text.length <= 80 && !text.contains('\n');
  return isPlain ? text : 'Something went wrong.';
}

String _describeStatus(int? status) {
  if (status == null) return 'The server sent an unexpected response.';
  if (status == 401) return 'Your session has expired. Sign in again.';
  if (status == 403) return "You don't have access to this.";
  if (status == 404) return 'This could not be found on the server.';
  if (status == 429) return 'Too many requests. Try again in a moment.';
  if (status >= 500) return 'The server ran into a problem ($status).';
  return 'The server refused the request ($status).';
}
