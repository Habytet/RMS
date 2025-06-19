import 'package:hive/hive.dart';
part 'menu_category.g.dart';

@HiveType(typeId: 11)
class MenuCategory extends HiveObject {
  @HiveField(0)
  String menuName;

  @HiveField(1)
  String categoryName;

  @HiveField(2)
  int selectionLimit;

  MenuCategory({
    required this.menuName,
    required this.categoryName,
    required this.selectionLimit,
  });
}