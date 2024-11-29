class Race {
  final String id;
  final String date;
  final String location;
  final String name;
  final String? registrationUrl; // Add this field

  Race({
    required this.id,
    required this.date,
    required this.location,
    required this.name,
    this.registrationUrl  // Make it optional
  });

  // Update JSON serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'location': location,
    'name': name,
    'registrationUrl': registrationUrl,
  };

  factory Race.fromJson(Map<String, dynamic> json) => Race(
    id: json['id'],
    date: json['date'],
    location: json['location'],
    name: json['name'],
    registrationUrl: json['registrationUrl'],
  );

  @override
  String toString() {
    return 'ID: $id, Date: $date, Location: $location, Name: $name';
  }
}
