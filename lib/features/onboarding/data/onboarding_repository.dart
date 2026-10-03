import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import '../../attendance/data/models.dart';
import 'models.dart';

/// Alta del club y guía "Primeros pasos" (`API_V1.md`, Sprint 5d).
class OnboardingRepository {
  OnboardingRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Map<String, dynamic> _data(Response<Object?> response) =>
      (response.data! as Map<String, dynamic>)['data'] as Map<String, dynamic>;

  List<Map<String, dynamic>> _list(Response<Object?> response) {
    final body = response.data;
    final list = body is Map ? body['data'] as List : body as List;
    return list.cast<Map<String, dynamic>>();
  }

  // Alta del club (sin organización activa).

  Future<OnboardingTemplates> templates() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/onboarding/templates',
    );
    return OnboardingTemplates.fromJson(_data(response));
  }

  Future<SlugCheck> checkSlug(String value) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/slug',
      queryParameters: {'value': value},
    );
    final body = response.data!;
    return SlugCheck.fromJson(
      body['data'] is Map ? body['data'] as Map<String, dynamic> : body,
    );
  }

  /// Crea el club y devuelve su slug. La organización activa pasa a ser esa.
  Future<String> createOrganization({
    required String name,
    required String type,
    required String slug,
    required Map<String, String> terminology,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/organizations',
      data: {
        'name': name,
        'type': type,
        'slug': slug,
        'terminology': terminology,
      },
    );
    final created = _data(response)['slug'] as String;
    await _storage.writeOrganization(created);
    return created;
  }

  // Guía.

  Future<Onboarding> onboarding() async =>
      Onboarding.fromJson(_data(await _dio.get('/onboarding')));

  Future<Onboarding> setDismissed(bool dismissed) async => Onboarding.fromJson(
    _data(await _dio.put('/onboarding', data: {'dismissed': dismissed})),
  );

  Future<Onboarding> skip(String key, {bool skipped = true}) async =>
      Onboarding.fromJson(
        _data(
          await _dio.put('/onboarding/steps/$key', data: {'skipped': skipped}),
        ),
      );

  // Paso 1: disciplinas.

  Future<List<SetupProgram>> programs() async =>
      _list(await _dio.get<Object?>('/setup/programs'))
          .map(SetupProgram.fromJson)
          .toList();

  Future<List<SetupProgram>> createPrograms(
    Map<String, GroupCriterion> programs,
  ) async => _list(
    await _dio.post<Object?>(
      '/setup/programs',
      data: {
        'programs': [
          for (final entry in programs.entries)
            {'name': entry.key, 'group_criterion': entry.value.value},
        ],
      },
    ),
  ).map(SetupProgram.fromJson).toList();

  // Paso 2: categorías y horarios.

  Future<List<SetupGroup>> groups() async =>
      _list(await _dio.get<Object?>('/setup/groups'))
          .map(SetupGroup.fromJson)
          .toList();

  Future<List<GroupDraft>> suggestGroups({
    required int programId,
    int? from,
    int? to,
    int? span,
    List<String>? levels,
  }) async => _list(
    await _dio.post<Object?>(
      '/setup/groups/suggestions',
      data: {
        'program_id': programId,
        if (levels != null)
          'levels': levels
        else
          'ages': {'from': from, 'to': to, 'span': span},
      },
    ),
  ).map(GroupDraft.fromJson).toList();

  /// Crea las categorías con sus horarios; [venueId] o el lugar nuevo va en
  /// todos los horarios.
  Future<List<SetupGroup>> createGroups({
    required int programId,
    required List<GroupDraft> groups,
    int? capacity,
    int? venueId,
    String? venueName,
    String? venueAddress,
  }) async => _list(
    await _dio.post<Object?>(
      '/setup/groups',
      data: {
        'program_id': programId,
        'groups': [
          for (final group in groups)
            {
              'name': group.name,
              'min_age': group.minAge,
              'max_age': group.maxAge,
              'level': group.level,
              'capacity': capacity,
              'schedules': [
                for (final slot in group.filledSlots)
                  ...slot.toSchedules().map((s) => s.toJson()),
              ],
            },
        ],
        if (venueId != null)
          'venue': {'id': venueId}
        else if (venueName != null && venueName.trim().isNotEmpty)
          'venue': {
            'name': venueName.trim(),
            if (venueAddress != null && venueAddress.trim().isNotEmpty)
              'address': venueAddress.trim(),
          },
      },
    ),
  ).map(SetupGroup.fromJson).toList();

  Future<SetupGroup> updateGroup(
    SetupGroup group,
    List<GroupSchedule> schedules,
  ) async => SetupGroup.fromJson(
    _data(
      await _dio.put(
        '/setup/groups/${group.id}',
        data: group.toJson(schedules: schedules),
      ),
    ),
  );

  Future<void> deleteGroup(int id) => _dio.delete<void>('/setup/groups/$id');

  Future<List<Venue>> venues() async =>
      _list(await _dio.get<Object?>('/venues')).map(Venue.fromJson).toList();

  // Paso 3: temporada.

  Future<List<SetupSeason>> seasons() async =>
      _list(await _dio.get<Object?>('/setup/seasons'))
          .map(SetupSeason.fromJson)
          .toList();

  Future<SeasonDraft> newSeason() async =>
      SeasonDraft.fromJson(_data(await _dio.get('/setup/seasons/new')));

  Future<SeasonPreview> previewSeason(SeasonDraft draft) async =>
      SeasonPreview.fromJson(
        _data(await _dio.post('/setup/seasons/preview', data: draft.toJson())),
      );

  Future<SetupSeason> createSeason(SeasonDraft draft) async =>
      SetupSeason.fromJson(
        _data(await _dio.post('/setup/seasons', data: draft.toJson())),
      );

  // Paso 4: técnicos.

  Future<SetupInstructors> instructors() async =>
      SetupInstructors.fromJson(_data(await _dio.get('/setup/instructors')));

  /// Invita por celular o por correo (uno de los dos).
  Future<SetupInstructor> inviteInstructor({
    required String name,
    String? phone,
    String? email,
    required List<int> groupIds,
  }) async => SetupInstructor.fromJson(
    _data(
      await _dio.post(
        '/setup/instructors',
        data: {
          'name': name,
          'phone': ?phone,
          'email': ?email,
          'group_ids': groupIds,
        },
      ),
    ),
  );

  Future<SetupInstructors> setTeaching({
    required bool teaches,
    required List<int> groupIds,
  }) async => SetupInstructors.fromJson(
    _data(
      await _dio.put(
        '/setup/instructors/me',
        data: {'teaches': teaches, 'group_ids': groupIds},
      ),
    ),
  );

  Future<SetupInstructor> setInstructorGroups(
    int userId,
    List<int> groupIds,
  ) async => SetupInstructor.fromJson(
    _data(
      await _dio.put(
        '/setup/instructors/$userId',
        data: {'group_ids': groupIds},
      ),
    ),
  );

  /// Token nuevo para una invitación pendiente o vencida; devuelve el link.
  Future<String> resendInvitation(int id) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/setup/invitations/$id/resend',
    );
    final body = response.data!;
    final data = body['data'] is Map ? body['data'] as Map : body;
    return data['link'] as String;
  }

  Future<void> revokeInvitation(int id) =>
      _dio.delete<void>('/setup/invitations/$id');
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);
