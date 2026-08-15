enum DuetLayout { none, split, pip }

extension DuetLayoutX on DuetLayout {
  bool get isActive => this != DuetLayout.none;

  static DuetLayout parse(String? raw) {
    if (raw == null || raw.isEmpty) return DuetLayout.none;
    return DuetLayout.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => DuetLayout.none,
    );
  }
}
