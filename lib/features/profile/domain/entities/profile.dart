import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  final String id;
  final bool isPremium;

  const Profile({
    required this.id,
    required this.isPremium,
  });

  @override
  List<Object?> get props => [id, isPremium];
}

