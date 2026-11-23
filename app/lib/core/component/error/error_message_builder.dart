import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'error_message_builder.g.dart';

@riverpod
ErrorMessageBuilder errorMessageBuilder(Ref ref) => ErrorMessageBuilder();

class ErrorMessageBuilder {
  String build({
    required Object error,
    String? Function(int statusCode)? onDioExceptionStatusOverride,
  }) {
    if (error is DioException) {
      final response = error.response;
      if (response != null) {
        final advancedErrorMessage = switch (response.data) {
          {'error': final String errorMsg} => errorMsg,
          {'code': final String code, 'details': final String details} =>
            '$code: $details',
          _ => '请稍后再试。',
        };
        final statusCode = response.statusCode;
        if (statusCode != null) {
          final baseMessage =
              onDioExceptionStatusOverride?.call(statusCode) ??
              switch (statusCode) {
                400 => '请求不合法',
                403 => '访问被拒绝',
                404 => '找不到资源',
                500 => '服务器错误',
                503 => '服务不可用',
                _ => '出错了',
              };
          if (response.data is Map<String, dynamic>) {
            return '$baseMessage\n$advancedErrorMessage';
          }
          return '$baseMessage\n$advancedErrorMessage\n${response.data}';
        }
        return advancedErrorMessage;
      }
      return switch (error.type) {
        .badCertificate => 'SSL 证书无效',
        .badResponse => '服务器响应异常',
        .connectionTimeout => '连接服务器超时',
        .receiveTimeout => '等待服务器响应超时',
        .sendTimeout => '请求服务器超时',
        .connectionError => '连接服务器失败，请检查网络',
        .unknown => '发生未知错误',
        .cancel => '已取消',
        .transformTimeout => '转换超时',
      };
    }
    return '出错了\n'
        '请稍后再试。\n'
        '\n($error)';
  }
}
