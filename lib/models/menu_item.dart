import 'package:hive/hive.dart';
part 'menu_item.g.dart';

@HiveType(typeId: 12)
class MenuItem extends HiveObject {
  @HiveField(0)
  String menuName;

  @HiveField(1)
  String categoryName;

  @HiveField(2)
  String itemName;

  MenuItem({
    required this.menuName,
    required this.categoryName,
    required this.itemName,
  });
}