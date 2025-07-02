class RestaurantTable {
  final int number;
  final int capacity;

  RestaurantTable({
    required this.number,
    required this.capacity,
  });

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'capacity': capacity,
    };
  }

  factory RestaurantTable.fromMap(Map<String, dynamic> map) {
    return RestaurantTable(
      number: map['number'] as int,
      capacity: map['capacity'] as int,
    );
  }

  @override
  String toString() {
    return 'Table $number, Seat $capacity';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RestaurantTable &&
        other.number == number &&
        other.capacity == capacity;
  }

  @override
  int get hashCode => number.hashCode ^ capacity.hashCode;
}
