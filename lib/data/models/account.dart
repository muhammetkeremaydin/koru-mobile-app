/// A Koru account that has signed in on this device.
///
/// Passwords are never stored here: Firebase Auth keeps the session,
/// this row only remembers who used the device and their profile basics.
class Account {
  const Account({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.lastLoginAt,
    this.birthYear,
    this.color = defaultColor,
    this.isCurrent = false,
  });

  /// Terracotta from the Notebook palette, used for the avatar circle.
  static const String defaultColor = '#B4532A';

  final String uid;
  final String email;
  final String displayName;

  /// Optional. The app asks only for the year, so the age is approximate.
  final int? birthYear;
  final String color;
  final DateTime lastLoginAt;

  /// True for the account that is signed in right now (at most one).
  final bool isCurrent;

  int? ageOn(DateTime day) => birthYear == null ? null : day.year - birthYear!;

  Account copyWith({
    String? email,
    String? displayName,
    int? birthYear,
    String? color,
    DateTime? lastLoginAt,
    bool? isCurrent,
  }) {
    return Account(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      birthYear: birthYear ?? this.birthYear,
      color: color ?? this.color,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }

  Map<String, Object?> toMap() => {
        'uid': uid,
        'email': email,
        'display_name': displayName,
        'birth_year': birthYear,
        'color': color,
        'last_login_at': lastLoginAt.millisecondsSinceEpoch,
        'is_current': isCurrent ? 1 : 0,
      };

  factory Account.fromMap(Map<String, Object?> map) => Account(
        uid: map['uid'] as String,
        email: map['email'] as String,
        displayName: map['display_name'] as String,
        birthYear: map['birth_year'] as int?,
        color: map['color'] as String,
        lastLoginAt:
            DateTime.fromMillisecondsSinceEpoch(map['last_login_at'] as int),
        isCurrent: map['is_current'] == 1,
      );
}
