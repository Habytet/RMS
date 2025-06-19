import 'package:hive/hive.dart';
part 'menu.g.dart';

@HiveType(typeId: 10)
class Menu extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double price;

  Menu({
    required this.name,
    required this.price,
  });
}