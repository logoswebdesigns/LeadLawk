import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../error/failures.dart';

abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

// This is a marker class to use when a UseCase doesn't need any parameters
class NoParams extends Equatable {
  @override
  List<Object> get props => [];
}