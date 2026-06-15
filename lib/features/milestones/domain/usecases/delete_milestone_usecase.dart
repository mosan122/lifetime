import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/repositories/milestone_repository.dart';

class DeleteMilestoneUseCase implements UseCase<void, DeleteMilestoneParams> {
  final MilestoneRepository repository;

  const DeleteMilestoneUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteMilestoneParams params) {
    return repository.deleteMilestone(
      params.id,
      accessToken: params.accessToken,
    );
  }
}

class DeleteMilestoneParams extends Equatable {
  final String id;
  final String? accessToken;

  const DeleteMilestoneParams(this.id, {this.accessToken});

  @override
  List<Object?> get props => [id, accessToken];
}
