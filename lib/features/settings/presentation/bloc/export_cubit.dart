import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../milestones/domain/usecases/export_bitacora_usecase.dart';

part 'export_state.dart';

class ExportCubit extends Cubit<ExportState> {
  final ExportBitacoraUseCase _exportBitacora;

  ExportCubit(this._exportBitacora) : super(const ExportIdle());

  Future<void> export() async {
    emit(const ExportLoading());
    try {
      final result = await _exportBitacora(const NoParams());
      result.fold(
        (failure) => emit(ExportError(failure.message)),
        (exportResult) => emit(ExportReady(exportResult)),
      );
    } catch (e) {
      emit(ExportError(e.toString()));
    }
  }
}
