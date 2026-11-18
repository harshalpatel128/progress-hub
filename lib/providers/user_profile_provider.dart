import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';
import '../core/database/database_service.dart';

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfileModel>>((ref) {
  return UserProfileNotifier();
});

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfileModel>> {
  UserProfileNotifier() : super(const AsyncValue.loading()) {
    loadProfile();
  }

  final _db = DatabaseService.instance;

  Future<void> loadProfile() async {
    try {
      state = const AsyncValue.loading();
      final profile = await _db.getUserProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile(UserProfileModel updated) async {
    try {
      await _db.saveUserProfile(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
