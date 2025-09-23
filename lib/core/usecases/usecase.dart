import 'package:equatable/equatable.dart';

/// Abstract base class for all use cases in the application
///
/// This follows the Clean Architecture pattern where use cases represent
/// the business logic of the application
abstract class UseCase<T, P> {
  /// Execute the use case with the given parameters
  Future<T> call(P params);
}

/// Use case that doesn't require any parameters
abstract class UseCaseNoParams<T> {
  /// Execute the use case without parameters
  Future<T> call();
}

/// Base class for use case parameters
///
/// All use case parameters should extend this class to ensure
/// they can be compared for equality
abstract class Params extends Equatable {
  const Params();
}

/// Empty parameters class for use cases that don't need parameters
class NoParams extends Params {
  const NoParams();

  @override
  List<Object> get props => [];
}
