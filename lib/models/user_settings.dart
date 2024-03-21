class UserSettings {
  Map<String, bool> fieldVisibility;
  bool normalizeTShirtSizes;

  UserSettings({
    required this.fieldVisibility,
    required this.normalizeTShirtSizes,
  });

  static UserSettings getDefault() {
    return UserSettings(
      fieldVisibility: {
        'bib': true,
        'name': false,
        'age': false,
        'gender': false,
        'city': false,
        'state': false,
        'division': true,
        'team': false,
        't_shirt': true,
        'extra': false,
        'status': false,
      },
      normalizeTShirtSizes: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fieldVisibility': fieldVisibility,
      'normalizeTShirtSizes': normalizeTShirtSizes,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> fieldsMap = Map<String, dynamic>.from(map['fieldVisibility']);
    Map<String, bool> fieldVisibility = {};
    fieldsMap.forEach((key, value) {
      fieldVisibility[key] = value;
    });
    return UserSettings(
      fieldVisibility: fieldVisibility,
      normalizeTShirtSizes: map['normalizeTShirtSizes'],
    );
  }
}
