// lib/screens/admin/menu_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/menu.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';

// --- Screen 1: Shows the list of all main menus ---
class MenuManagementScreen extends StatefulWidget {
  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  // Get a reference to the 'menus' collection in Firestore
  final CollectionReference _menusCollection = FirebaseFirestore.instance.collection('menus');

  final _menuNameController = TextEditingController();
  final _menuPriceController = TextEditingController();

  @override
  void dispose() {
    _menuNameController.dispose();
    _menuPriceController.dispose();
    super.dispose();
  }

  void _addMenu() {
    _menuNameController.clear();
    _menuPriceController.clear();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _menuNameController, decoration: const InputDecoration(labelText: 'Menu Name')),
            TextField(controller: _menuPriceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = _menuNameController.text.trim();
              final price = double.tryParse(_menuPriceController.text.trim()) ?? 0.0;
              if (name.isNotEmpty) {
                // Create a new Menu object and convert it to a map
                final newMenu = Menu(name: name, price: price);
                // Use the menu name as the document ID to prevent duplicates
                await _menusCollection.doc(name).set(newMenu.toMap());
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _manageMenu(Menu menu) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MenuDetailScreen(menu: menu)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Management')),
      // Use a StreamBuilder to listen for real-time changes to the menus
      body: StreamBuilder<QuerySnapshot>(
        stream: _menusCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No menus found. Tap + to add one.'));
          }

          // Convert the Firestore documents into Menu objects
          final menus = snapshot.data!.docs.map((doc) {
            return Menu.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView(
            children: menus.map((m) {
              return ListTile(
                title: Text('${m.name} — ₹${m.price}+tax'),
                trailing: const Icon(Icons.edit),
                onTap: () => _manageMenu(m),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMenu,
        child: const Icon(Icons.add),
        tooltip: 'Add Menu',
      ),
    );
  }
}


// --- Screen 2: Shows the details (categories and items) for a specific menu ---
class MenuDetailScreen extends StatefulWidget {
  final Menu menu;
  const MenuDetailScreen({super.key, required this.menu});

  @override
  State<MenuDetailScreen> createState() => _MenuDetailScreenState();
}

class _MenuDetailScreenState extends State<MenuDetailScreen> {
  // References to the Firestore collections
  final CollectionReference _categoriesCollection = FirebaseFirestore.instance.collection('menuCategories');
  final CollectionReference _itemsCollection = FirebaseFirestore.instance.collection('menuItems');

  final _categoryNameController = TextEditingController();
  final _selectionLimitController = TextEditingController();
  final _itemNameController = TextEditingController();

  @override
  void dispose() {
    _categoryNameController.dispose();
    _selectionLimitController.dispose();
    _itemNameController.dispose();
    super.dispose();
  }

  void _addCategory() {
    _categoryNameController.clear();
    _selectionLimitController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _categoryNameController, decoration: const InputDecoration(labelText: 'Category Name')),
            TextField(controller: _selectionLimitController, decoration: const InputDecoration(labelText: 'Selection Limit'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = _categoryNameController.text.trim();
              final limit = int.tryParse(_selectionLimitController.text.trim()) ?? 1;
              if (name.isNotEmpty) {
                final newCategory = MenuCategory(
                  menuName: widget.menu.name,
                  categoryName: name,
                  selectionLimit: limit,
                );
                // Add the new category to Firestore
                await _categoriesCollection.add(newCategory.toMap());
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addItem(MenuCategory category) {
    _itemNameController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Item to ${category.categoryName}'),
        content: TextField(controller: _itemNameController, decoration: const InputDecoration(labelText: 'Item Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = _itemNameController.text.trim();
              if (name.isNotEmpty) {
                final newItem = MenuItem(
                  menuName: widget.menu.name,
                  categoryName: category.categoryName,
                  itemName: name,
                );
                // Add the new item to Firestore
                await _itemsCollection.add(newItem.toMap());
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.menu.name} Details')),
      // Use a StreamBuilder to get all categories for the current menu
      body: StreamBuilder<QuerySnapshot>(
        stream: _categoriesCollection.where('menuName', isEqualTo: widget.menu.name).snapshots(),
        builder: (context, categorySnapshot) {
          if (categorySnapshot.hasError) return const Center(child: Text('Error loading categories.'));
          if (categorySnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (categorySnapshot.data!.docs.isEmpty) return const Center(child: Text('No categories found. Tap + to add one.'));

          final categories = categorySnapshot.data!.docs.map((doc) {
            return MenuCategory.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView(
            children: categories.map((cat) {
              return ExpansionTile(
                title: Text('${cat.categoryName} (Max Selections: ${cat.selectionLimit})'),
                children: [
                  // Use a nested StreamBuilder to get items for THIS category
                  StreamBuilder<QuerySnapshot>(
                    stream: _itemsCollection
                        .where('menuName', isEqualTo: widget.menu.name)
                        .where('categoryName', isEqualTo: cat.categoryName)
                        .snapshots(),
                    builder: (context, itemSnapshot) {
                      if (itemSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(title: Text('Loading items...'));
                      }
                      final items = itemSnapshot.data?.docs.map((doc) {
                        return MenuItem.fromMap(doc.data() as Map<String, dynamic>);
                      }).toList() ?? [];

                      return Column(
                        children: [
                          ...items.map((item) => ListTile(title: Text(item.itemName))),
                          ListTile(
                            title: TextButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Add Item'),
                              onPressed: () => _addItem(cat),
                            ),
                          )
                        ],
                      );
                    },
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.category),
        tooltip: 'Add Category',
      ),
    );
  }
}
