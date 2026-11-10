/// A book club. The same group can be cached once and shared by
/// several accounts on the device through [Membership].
class ClubGroup {
  const ClubGroup({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toMap() => {'id': id, 'name': name};

  factory ClubGroup.fromMap(Map<String, Object?> map) =>
      ClubGroup(id: map['id'] as String, name: map['name'] as String);
}

enum GroupRole { owner, admin, member }

/// An account's place in a group.
class Membership {
  const Membership({required this.group, required this.role});

  final ClubGroup group;
  final GroupRole role;

  bool get canManage => role != GroupRole.member;
}
