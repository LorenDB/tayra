import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

/// Browser adapter — the browser owns connection pooling / keep-alive.
void configureHttpClient(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: false);
}
