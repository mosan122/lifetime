import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lifetime/core/failures/failure.dart';
import 'package:lifetime/data/datasources/milestone_remote_datasource.dart';
import 'package:lifetime/data/models/milestone_model.dart';
import 'package:lifetime/data/repositories/milestone_repository_impl.dart';

class MockMilestoneRemoteDataSource extends Mock
    implements MilestoneRemoteDataSource {}

void main() {
  late MockMilestoneRemoteDataSource mockDatasource;
  late MilestoneRepositoryImpl repository;

  final tDate = DateTime(2026, 4, 26);
  const tUserNote = 'Celebré mi 30 cumpleaños con amigos.';
  const tLocationName = 'Madrid';

  final tBiographerResult =
      (title: 'Mi 30 cumpleaños', narrative: 'Fue un día especial.');

  final tMilestoneModel = MilestoneModel(
    id: 'ms-1',
    userId: 'user-1',
    title: 'Mi 30 cumpleaños',
    description: 'Fue un día especial.',
    participants: const ['Ana'],
    media: const [],
    eventDate: DateTime(2026, 4, 26),
    locationName: 'Madrid',
    latitude: 40.4168,
    longitude: -3.7038,
    category: 'familia',
    isPublic: false,
    createdAt: DateTime(2026, 4, 26, 10),
  );

  setUp(() {
    mockDatasource = MockMilestoneRemoteDataSource();
    repository = MilestoneRepositoryImpl(mockDatasource);
  });

  group('createMilestone', () {
    void stubBiographerSuccess() {
      when(() => mockDatasource.callBiographerNarrative(
            userNote: any(named: 'userNote'),
            date: any(named: 'date'),
            location: any(named: 'location'),
          )).thenAnswer((_) async => tBiographerResult);
    }

    test('returns Right(Milestone) on full success', () async {
      stubBiographerSuccess();
      when(() => mockDatasource.insertMilestone(any()))
          .thenAnswer((_) async => tMilestoneModel);

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        locationName: tLocationName,
        latitude: 40.4168,
        longitude: -3.7038,
        category: 'familia',
        participants: ['Ana'],
      );

      expect(result, Right(tMilestoneModel));
    });

    test('insert map includes POINT WKT when lat/lng provided', () async {
      stubBiographerSuccess();
      Map<String, dynamic>? capturedData;
      when(() => mockDatasource.insertMilestone(any())).thenAnswer((inv) async {
        capturedData = inv.positionalArguments[0] as Map<String, dynamic>;
        return tMilestoneModel;
      });

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
        latitude: 40.4168,
        longitude: -3.7038,
      );

      expect(capturedData!['location_coords'], equals('POINT(-3.7038 40.4168)'));
    });

    test('insert map omits location_coords when lat/lng are null', () async {
      stubBiographerSuccess();
      Map<String, dynamic>? capturedData;
      when(() => mockDatasource.insertMilestone(any())).thenAnswer((inv) async {
        capturedData = inv.positionalArguments[0] as Map<String, dynamic>;
        return tMilestoneModel;
      });

      await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(capturedData!.containsKey('location_coords'), isFalse);
    });

    test('returns Left(AuthFailure) when AuthException is thrown', () async {
      when(() => mockDatasource.callBiographerNarrative(
            userNote: any(named: 'userNote'),
            date: any(named: 'date'),
            location: any(named: 'location'),
          )).thenThrow(const AuthException('Not authenticated'));

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<AuthFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('returns Left(DatabaseFailure) when PostgrestException is thrown on insert', () async {
      stubBiographerSuccess();
      when(() => mockDatasource.insertMilestone(any())).thenThrow(
        PostgrestException(message: 'duplicate key', code: '23505'),
      );

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<DatabaseFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('returns Left(BiographerFailure) when FormatException is thrown', () async {
      when(() => mockDatasource.callBiographerNarrative(
            userNote: any(named: 'userNote'),
            date: any(named: 'date'),
            location: any(named: 'location'),
          )).thenThrow(const FormatException('Missing narrative'));

      final result = await repository.createMilestone(
        userNote: tUserNote,
        eventDate: tDate,
      );

      expect(result, const Left(BiographerFailure()));
    });
  });

  group('getMilestones', () {
    test('returns Right(List<Milestone>) on success', () async {
      when(() => mockDatasource.fetchMilestones())
          .thenAnswer((_) async => [tMilestoneModel]);

      final result = await repository.getMilestones();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (list) => expect(list, [tMilestoneModel]),
      );
    });

    test('returns Left(DatabaseFailure) when PostgrestException is thrown', () async {
      when(() => mockDatasource.fetchMilestones()).thenThrow(
        PostgrestException(message: 'connection error', code: '08000'),
      );

      final result = await repository.getMilestones();

      result.fold(
        (f) => expect(f, isA<DatabaseFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('getMilestoneById', () {
    test('returns Right(Milestone) on success', () async {
      when(() => mockDatasource.fetchMilestoneById('ms-1'))
          .thenAnswer((_) async => tMilestoneModel);

      final result = await repository.getMilestoneById('ms-1');

      expect(result, Right(tMilestoneModel));
    });

    test('returns Left(DatabaseFailure) when PostgrestException is thrown', () async {
      when(() => mockDatasource.fetchMilestoneById(any())).thenThrow(
        PostgrestException(message: 'not found', code: 'PGRST116'),
      );

      final result = await repository.getMilestoneById('ms-999');

      result.fold(
        (f) => expect(f, isA<DatabaseFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
