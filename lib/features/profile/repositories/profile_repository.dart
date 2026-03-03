import '../../auth/models/user_model.dart';
import '../datasources/profile_remote_datasource.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';

class Result<T> {
  final T? data;
  final Failure? failure;

  Result.success(this.data) : failure = null;
  Result.failure(this.failure) : data = null;

  bool get isSuccess => data != null;
  bool get isFailure => failure != null;
}

abstract class ProfileRepository {
  Future<Result<User>> getProfile();
  Future<Result<User>> updateProfile({
    String? name,
    String? lastName,
    String? phoneNumber,
  });
  Future<Result<User>> uploadProfilePicture(String filePath);
}

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDatasource _remoteDatasource;

  ProfileRepositoryImpl({required ProfileRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  @override
  Future<Result<User>> getProfile() async {
    try {
      final user = await _remoteDatasource.getProfile();
      return Result.success(user);
    } on NetworkException catch (e) {
      return Result.failure(NetworkFailure(e.message));
    } on UnauthorizedException catch (e) {
      return Result.failure(UnauthorizedFailure(e.message));
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure('An unexpected error occurred'));
    }
  }

  @override
  Future<Result<User>> updateProfile({
    String? name,
    String? lastName,
    String? phoneNumber,
  }) async {
    try {
      final user = await _remoteDatasource.updateProfile(
        name: name,
        lastName: lastName,
        phoneNumber: phoneNumber,
      );
      return Result.success(user);
    } on ValidationException catch (e) {
      return Result.failure(ValidationFailure(e.message, e.errors));
    } on NetworkException catch (e) {
      return Result.failure(NetworkFailure(e.message));
    } on UnauthorizedException catch (e) {
      return Result.failure(UnauthorizedFailure(e.message));
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure('An unexpected error occurred'));
    }
  }

  @override
  Future<Result<User>> uploadProfilePicture(String filePath) async {
    try {
      final user = await _remoteDatasource.uploadProfilePicture(filePath);
      return Result.success(user);
    } on ValidationException catch (e) {
      return Result.failure(ValidationFailure(e.message, e.errors));
    } on NetworkException catch (e) {
      return Result.failure(NetworkFailure(e.message));
    } on UnauthorizedException catch (e) {
      return Result.failure(UnauthorizedFailure(e.message));
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (e) {
      return Result.failure(ServerFailure('An unexpected error occurred'));
    }
  }
}
