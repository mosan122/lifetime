// test/features/auth/presentation/bloc/auth_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/core/services/premium_service.dart';
import 'package:lifetime/features/auth/domain/entities/auth_user.dart';
import 'package:lifetime/features/auth/domain/repositories/auth_repository.dart';
import 'package:lifetime/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:lifetime/features/profile/domain/entities/profile.dart';
import 'package:lifetime/features/profile/domain/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, GoTrueClient, User;

class MockAuthRepository extends Mock implements AuthRepository {}
class MockProfileRepository extends Mock implements ProfileRepository {}
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository mockRepo;
  late MockProfileRepository mockProfileRepo;
  late PremiumService premiumService;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockGoTrue;
  late MockUser mockSupaUser;

  const tUser = AuthUser(
    id: 'goog-1',
    email: 'test@gmail.com',
    displayName: 'Test User',
    photoUrl: null,
    accessToken: 'token-abc',
  );

  setUp(() {
    mockRepo = MockAuthRepository();
    mockProfileRepo = MockProfileRepository();
    SharedPreferences.setMockInitialValues({});
    premiumService = PremiumService();

    mockSupabase = MockSupabaseClient();
    mockGoTrue = MockGoTrueClient();
    mockSupaUser = MockUser();
    when(() => mockSupabase.auth).thenReturn(mockGoTrue);
    when(() => mockGoTrue.currentUser).thenReturn(mockSupaUser);
    when(() => mockSupaUser.id).thenReturn('supa-uid-1');
  });

  AuthCubit makeCubit() =>
      AuthCubit(mockRepo, premiumService, mockProfileRepo, mockSupabase);

  test('initial state is AuthUnauthenticated', () {
    expect(makeCubit().state, const AuthUnauthenticated());
  });

  group('checkCurrentUser', () {
    blocTest<AuthCubit, AuthState>(
      'emits Authenticated(isPremium: false) when session exists and no premium stored',
      setUp: () {
        when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => tUser);
        when(() => mockProfileRepo.fetchProfile('supa-uid-1')).thenAnswer(
          (_) async => const Right(Profile(id: 'supa-uid-1', isPremium: false)),
        );
      },
      build: makeCubit,
      act: (c) => c.checkCurrentUser(),
      expect: () => [const AuthAuthenticated(tUser, isPremium: false)],
    );

    blocTest<AuthCubit, AuthState>(
      'emits Authenticated(isPremium: true) when session exists and premium stored',
      setUp: () {
        when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => tUser);
        when(() => mockProfileRepo.fetchProfile('supa-uid-1')).thenAnswer(
          (_) async => const Right(Profile(id: 'supa-uid-1', isPremium: true)),
        );
      },
      build: makeCubit,
      act: (c) => c.checkCurrentUser(),
      expect: () => [const AuthAuthenticated(tUser, isPremium: true)],
    );

    blocTest<AuthCubit, AuthState>(
      'emits Unauthenticated when no session',
      setUp: () =>
          when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => null),
      build: makeCubit,
      act: (c) => c.checkCurrentUser(),
      expect: () => [const AuthUnauthenticated()],
    );
  });

  group('signInWithGoogle', () {
    blocTest<AuthCubit, AuthState>(
      'emits [Authenticating, Authenticated(isPremium: false)] on success',
      setUp: () {
        when(() => mockRepo.signInWithGoogle())
            .thenAnswer((_) async => const Right(tUser));
        when(() => mockProfileRepo.fetchProfile('supa-uid-1')).thenAnswer(
          (_) async => const Right(Profile(id: 'supa-uid-1', isPremium: false)),
        );
      },
      build: makeCubit,
      act: (c) => c.signInWithGoogle(),
      expect: () => [
        const AuthAuthenticating(),
        const AuthAuthenticated(tUser, isPremium: false),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [Authenticating, Unauthenticated] when cancelled',
      setUp: () => when(() => mockRepo.signInWithGoogle())
          .thenAnswer((_) async =>
              const Left(AuthFailure('Sign-in cancelled'))),
      build: makeCubit,
      act: (c) => c.signInWithGoogle(),
      expect: () => [
        const AuthAuthenticating(),
        const AuthUnauthenticated(error: 'Sign-in cancelled'),
      ],
    );
  });

  group('signOut', () {
    blocTest<AuthCubit, AuthState>(
      'emits Unauthenticated after sign out',
      setUp: () => when(() => mockRepo.signOut())
          .thenAnswer((_) async => const Right(unit)),
      build: makeCubit,
      seed: () => const AuthAuthenticated(tUser),
      act: (c) => c.signOut(),
      expect: () => [const AuthUnauthenticated()],
    );
  });

  group('setPremium', () {
    blocTest<AuthCubit, AuthState>(
      'emits AuthAuthenticated(isPremium: true) when called with true',
      build: makeCubit,
      seed: () => const AuthAuthenticated(tUser, isPremium: false),
      act: (c) => c.setPremium(true),
      expect: () => [const AuthAuthenticated(tUser, isPremium: true)],
    );

    blocTest<AuthCubit, AuthState>(
      'does not emit when state is Unauthenticated',
      build: makeCubit,
      seed: () => const AuthUnauthenticated(),
      act: (c) => c.setPremium(true),
      expect: () => [],
    );
  });
}
