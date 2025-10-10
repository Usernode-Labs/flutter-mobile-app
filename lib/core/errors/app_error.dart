sealed class AppError implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppError(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkError extends AppError {
  const NetworkError(super.message, {super.cause, super.stackTrace});
}

final class BackendError extends AppError {
  const BackendError(super.message, {super.cause, super.stackTrace});
}

final class StorageError extends AppError {
  const StorageError(super.message, {super.cause, super.stackTrace});
}

final class ValidationError extends AppError {
  const ValidationError(super.message, {super.cause, super.stackTrace});
}

final class UnknownError extends AppError {
  const UnknownError(super.message, {super.cause, super.stackTrace});
}
