/// Defines a strict Result type for predictable error propagation.
sealed class Result<T, E extends Exception> {
  const Result();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  S fold<S>(S Function(T value) onSuccess, S Function(E error) onFailure);

  T getOrThrow() => fold((v) => v, (e) => throw e);
}

class Success<T, E extends Exception> extends Result<T, E> {
  final T value;
  const Success(this.value);

  @override
  S fold<S>(S Function(T value) onSuccess, S Function(E error) onFailure) =>
      onSuccess(value);
}

class Failure<T, E extends Exception> extends Result<T, E> {
  final E error;
  const Failure(this.error);

  @override
  S fold<S>(S Function(T value) onSuccess, S Function(E error) onFailure) =>
      onFailure(error);
}
