part of 'export_cubit.dart';

abstract class ExportState extends Equatable {
  const ExportState();
}

class ExportIdle extends ExportState {
  const ExportIdle();
  @override
  List<Object?> get props => const [];
}

class ExportLoading extends ExportState {
  const ExportLoading();
  @override
  List<Object?> get props => const [];
}

class ExportReady extends ExportState {
  final ExportResult result;
  const ExportReady(this.result);
  @override
  List<Object?> get props => [result];
}

class ExportError extends ExportState {
  final String message;
  const ExportError(this.message);
  @override
  List<Object?> get props => [message];
}
