// lib/models/menu_category.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// All Hive-related code has been removed.

class MenuCategory { // No longer extends HiveObject
  String menuName;
  String categoryName;
  int selectionLimit;

  MenuCategory({
    required this.menuName,
    required this.categoryName,
    required this.selectionLimit,
  });

  /// Convert this MenuCategory to a Firestore map
  Map<String, dynamic> toMap() {
    return {
      'menuName': menuName,
      'categoryName': categoryName,
      'selectionLimit': selectionLimit,
    };
  }

  /// Create a MenuCategory from Firestore data
  factory MenuCategory.fromMap(Map<String, dynamic> map) {
    return MenuCategory(
      menuName: map['menuName'] ?? '',
      categoryName: map['categoryName'] ?? '',
      selectionLimit: map['selectionLimit'] ?? 0,
    );
  }
}
