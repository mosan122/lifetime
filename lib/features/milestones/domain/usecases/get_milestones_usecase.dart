import 'package:dartz/dartz.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/entities/milestone.dart';
import '../../../../domain/repositories/milestone_repository.dart';

class GetMilestonesUseCase implements UseCase<List<Milestone>, NoParams> {
  final MilestoneRepository repository;

  const GetMilestonesUseCase(this.repository);

  @override
  Future<Either<Failure, List<Milestone>>> call(NoParams params) {
    return repository.getMilestones();
  }
}
