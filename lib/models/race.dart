class Race {
  final String id;
  final String date;
  final String location;
  final String name;

  Race({required this.id, required this.date, required this.location, required this.name});

  // Convert a Race object to a Map (JSON-like format)
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'location': location,
    'name': name,
  };

  // Create a Race object from a Map (JSON format)
  factory Race.fromJson(Map<String, dynamic> json) => Race(
    id: json['id'],
    date: json['date'],
    location: json['location'],
    name: json['name'],
  );

  @override
  String toString() {
    return 'ID: $id, Date: $date, Location: $location, Name: $name';
  }
}
