import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../domain/repositories/milestone_repository.dart';

class ImportBitacoraParams extends Equatable {
  const ImportBitacoraParams(this.json);

  final String json;

  @override
  List<Object?> get props => [json];
}

class BitacoraImportResult extends Equatable {
  const BitacoraImportResult({required this.imported});

  final int imported;

  @override
  List<Object?> get props => [imported];
}

class ImportBitacoraUseCase
    implements UseCase<BitacoraImportResult, ImportBitacoraParams> {
  const ImportBitacoraUseCase(this._repository);

  final MilestoneRepository _repository;

  @override
  Future<Either<Failure, BitacoraImportResult>> call(
    ImportBitacoraParams params,
  ) async {
    final r = await _repository.importFromBackupJson(params.json);
    return r.map((n) => BitacoraImportResult(imported: n));
  }
}
