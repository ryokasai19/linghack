import 'package:cloud_firestore/cloud_firestore.dart';

enum UserTier { free, monthly, lifetime }

class UserProfile {
  final String uid;
  final String email;
  final UserTier tier;
  
  // Usage Tracking
  final int dailyScansUsed;
  final DateTime lastScanDate;

  UserProfile({
    required this.uid,
    required this.email,
    this.tier = UserTier.free,
    this.dailyScansUsed = 0,
    required this.lastScanDate,
  });

  /// 1. Check if user has Unlimited Access
  bool get isPremium => tier == UserTier.monthly || tier == UserTier.lifetime;

  /// 2. Check if user can use the AI Scanner
  bool canUseAiScanner(int limit) {
    if (isPremium) return true;
    
    // ✅ FIX: Access the public getter
    if (isNewDay) return true;

    return dailyScansUsed < limit;
  }

  /// 3. Helper to display "1/3 Scans Left" in UI
  int scansRemaining(int limit) {
    if (isPremium) return -1; 
    // ✅ FIX: Access the public getter
    if (isNewDay) return limit;
    return (limit - dailyScansUsed).clamp(0, limit);
  }

  // ✅ FIX: Changed from private method '_isNewDay' to public getter 'isNewDay'
  bool get isNewDay {
    final now = DateTime.now();
    return now.day != lastScanDate.day || 
           now.month != lastScanDate.month || 
           now.year != lastScanDate.year;
  }

  // --- Serialization ---

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'tier': tier.name,
      // ✅ FIX: Access the public getter
      'dailyScansUsed': isNewDay ? 0 : dailyScansUsed, 
      'lastScanDate': Timestamp.fromDate(lastScanDate),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    UserTier parsedTier = UserTier.free;
    if (map['tier'] == 'monthly') parsedTier = UserTier.monthly;
    if (map['tier'] == 'lifetime') parsedTier = UserTier.lifetime;

    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      tier: parsedTier,
      dailyScansUsed: map['dailyScansUsed'] ?? 0,
      lastScanDate: (map['lastScanDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}