
import 'counter_style.dart';

class CounterData {
  int? id;
  String name;
  int count;
  CounterStyle style;

  CounterData({
    this.id,
    required this.name,
    this.count = 0,
    required this.style,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'count': count,
      ...style.toMap(),
    };
  }

  factory CounterData.fromMap(Map<String, dynamic> map) {
    return CounterData(
      id: map['id'] as int?,
      name: map['name'] as String,
      count: map['count'] as int,
      style: CounterStyle.fromMap(map),
    );
  }
}
