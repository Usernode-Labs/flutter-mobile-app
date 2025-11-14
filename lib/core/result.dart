import 'package:crypto_mobile_app/core/errors/app_error.dart';

abstract class Result<T> {
  const Result();
  bool get isOk;
  bool get isErr => !isOk;
  T unwrapOr(T fallback);
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
  @override
  bool get isOk => true;
  @override
  T unwrapOr(T fallback) => value;
}

class Err<T> extends Result<T> {
  final AppError error;
  const Err(this.error);
  @override
  bool get isOk => false;
  @override
  T unwrapOr(T fallback) => fallback;
}

extension ResultX<T> on Result<T> {
  T? get ok => this is Ok<T> ? (this as Ok<T>).value : null;
  AppError? get err => this is Err<T> ? (this as Err<T>).error : null;
}
