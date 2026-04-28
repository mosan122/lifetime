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

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late PremiumService premiumService;

  const tUser = AuthUser(
    id: 'goog-1',
    email: 'test@gmail.com',
    displayName: 'Test User',
    photoUrl: null,
    accessToken: 'token-abc',
  );

  setUp(() {
    mockRepo = MockAuthRepository();
    SharedPreferences.setMockInitialValues({});
    premiumService = PremiumService();
  });

  AuthCubit makeCubit() => AuthCubit(mockRepo, premiumService);

  test('initial state is AuthUnauthenticated', () {
    expect(makeCubit().state, const AuthUnauthenticated());
  });

  group('checkCurrentUser', () {
    blocTest<AuthCubit, AuthState>(
      'emits Authenticated(isPremium: false) when session exists and no premium stored',
      setUp: () =>
          when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => tUser),
      build: makeCubit,
      act: (c) => c.checkCurrentUser(),
      expect: () => [const AuthAuthenticated(tUser, isPremium: false)],
    );

    blocTest<AuthCubit, AuthState>(
      'emits Authenticated(isPremium: true) when session exists and premium stored',
      setUp: () {
        SharedPreferences.setMockInitialValues({'is_premium': true});
        premiumService = PremiumService();
        when(() => mockRepo.getCurrentUser()).thenAnswer((_) async => tUser);
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
      setUp: () => when(() => mockRepo.signInWithGoogle())
          .thenAnswer((_) async => const Right(tUser)),
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
