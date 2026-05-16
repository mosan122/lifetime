import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../milestones/domain/usecases/import_bitacora_usecase.dart';

part 'import_state.dart';

class ImportCubit extends Cubit<ImportState> {
  ImportCubit(this._importUseCase) : super(const ImportIdle());

  final ImportBitacoraUseCase _importUseCase;

  Future<void> importJson(String json) async {
    emit(const ImportLoading());
    try {
      final r = await _importUseCase(ImportBitacoraParams(json));
      r.fold(
        (f) => emit(ImportError(f.message)),
        (res) => emit(ImportSuccess(res.imported)),
      );
    } catch (e) {
      emit(ImportError(e.toString()));
    }
  }

  void reset() => emit(const ImportIdle());
}
