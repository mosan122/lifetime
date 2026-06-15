part of 'import_cubit.dart';

sealed class ImportState extends Equatable {
  const ImportState();

  @override
  List<Object?> get props => [];
}

class ImportIdle extends ImportState {
  const ImportIdle();
}

class ImportLoading extends ImportState {
  const ImportLoading();
}

class ImportSuccess extends ImportState {
  const ImportSuccess(this.imported);
  final int imported;

  @override
  List<Object?> get props => [imported];
}

class ImportError extends ImportState {
  const ImportError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
