class Race {
  final String id;
  final String date;
  final String location;
  final String name;

  Race({required this.id, required this.date, required this.location, required this.name});

  @override
  String toString() {
    return 'ID: $id, Date: $date, Location: $location, Name: $name';
  }
}
