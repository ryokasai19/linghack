import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  // Singleton pattern (so we can call it easily from anywhere)
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // 1. Initialize (Run this in main.dart)
  Future<void> initialize() async {
    try {
      // A. Set "Safe Default" (If no internet, limit is 3)
      await _remoteConfig.setDefaults({'daily_free_limit': 3});
      
      // B. Fetch fresh values from the cloud
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1), // Cache for 1 hour
      ));
      
      await _remoteConfig.fetchAndActivate();
      print("Remote Config Fetched: Limit is ${dailyFreeLimit}");
    } catch (e) {
      print("Remote Config fetch failed: $e");
    }
  }

  // 2. The Getter (Returns 999 or 3)
  int get dailyFreeLimit => _remoteConfig.getInt('daily_free_limit');
}