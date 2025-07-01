// lib/screens/admin/menu_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/menu.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';
import '../../providers/user_provider.dart';
import 'package:provider/provider.dart';

// --- Screen 1: Shows the list of all main menus ---
class MenuManagementScreen extends StatefulWidget {
  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  String? _selectedBranchId;
  final _menuNameController = TextEditingController();
  final _menuPriceController = TextEditingController();

  CollectionReference getMenusCollection() {
    if (_selectedBranchId != null) {
      return FirebaseFirestore.instance
          .collection('branches')
          .doc(_selectedBranchId)
          .collection('menus');
    }
    // fallback to a dummy collection
    return FirebaseFirestore.instance.collection('dummy');
  }

  @override
  void dispose() {
    _menuNameController.dispose();
    _menuPriceController.dispose();
    super.dispose();
  }

  void _showMigrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Migrate Hall Menus'),
        content: Text(
          'This will move all existing menus from individual halls to the branch level. '
          'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _migrateHallMenusToBranch();
            },
            child: Text('Migrate'),
          ),
        ],
      ),
    );
  }

  Future<void> _migrateHallMenusToBranch() async {
    if (_selectedBranchId == null) return;

    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Migrating menus...'),
            ],
          ),
        ),
      );

      // Get all halls in the branch
      final hallsSnapshot = await FirebaseFirestore.instance
          .collection('branches')
          .doc(_selectedBranchId)
          .collection('halls')
          .get();

      final branchMenusCollection = FirebaseFirestore.instance
          .collection('branches')
          .doc(_selectedBranchId)
          .collection('menus');

      // Track migrated menus to avoid duplicates
      Set<String> migratedMenuNames = {};

      for (var hallDoc in hallsSnapshot.docs) {
        final hallName = hallDoc.id;
        final hallMenusCollection = FirebaseFirestore.instance
            .collection('branches')
            .doc(_selectedBranchId)
            .collection('halls')
            .doc(hallName)
            .collection('menus');

        // Get all menus in this hall
        final menusSnapshot = await hallMenusCollection.get();

        for (var menuDoc in menusSnapshot.docs) {
          final menuData = menuDoc.data();
          final menuName = menuDoc.id;

          // Skip if already migrated
          if (migratedMenuNames.contains(menuName)) continue;

          // Migrate menu to branch level
          await branchMenusCollection.doc(menuName).set(menuData);

          // Migrate categories
          final categoriesSnapshot = await hallMenusCollection
              .doc(menuName)
              .collection('categories')
              .get();

          for (var categoryDoc in categoriesSnapshot.docs) {
            await branchMenusCollection
                .doc(menuName)
                .collection('categories')
                .doc(categoryDoc.id)
                .set(categoryDoc.data());
          }

          // Migrate items
          final itemsSnapshot =
              await hallMenusCollection.doc(menuName).collection('items').get();

          for (var itemDoc in itemsSnapshot.docs) {
            await branchMenusCollection
                .doc(menuName)
                .collection('items')
                .add(itemDoc.data());
          }

          migratedMenuNames.add(menuName);
        }
      }

      // Close progress dialog
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully migrated ${migratedMenuNames.length} menus to branch level'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close progress dialog
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isCorporate = userProvider.currentUser?.branchId == 'all';
    final branches = userProvider.branches;

    // Set default branch for admin only once
    if (isCorporate && _selectedBranchId == null && branches.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedBranchId = branches
                .firstWhere((b) => b.id != 'all', orElse: () => branches.first)
                .id;
          });
        }
      });
    } else if (!isCorporate && _selectedBranchId == null) {
      _selectedBranchId = userProvider.currentBranchId;
    }

    final menusCollection = getMenusCollection();

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
              TextField(
                  controller: _menuNameController,
                  decoration: const InputDecoration(labelText: 'Menu Name')),
              TextField(
                  controller: _menuPriceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = _menuNameController.text.trim();
                final price =
                    double.tryParse(_menuPriceController.text.trim()) ?? 0.0;
                if (name.isNotEmpty) {
                  final newMenu = Menu(name: name, price: price);
                  await menusCollection.doc(name).set(newMenu.toMap());
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
        MaterialPageRoute(
            builder: (_) =>
                MenuDetailScreen(menu: menu, branchId: _selectedBranchId!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        actions: [
          // Add migration button for existing users
          if (_selectedBranchId != null)
            IconButton(
              icon: Icon(Icons.sync),
              tooltip: 'Migrate Hall Menus to Branch',
              onPressed: () => _showMigrationDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          if (isCorporate)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: DropdownButtonFormField<String>(
                value: _selectedBranchId,
                decoration: const InputDecoration(
                    labelText: 'Select Branch', border: OutlineInputBorder()),
                items: [
                  ...branches.where((b) => b.id != 'all').map((b) =>
                      DropdownMenuItem(value: b.id, child: Text(b.name))),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBranchId = value;
                  });
                },
              ),
            ),
          Expanded(
            child: (_selectedBranchId == null)
                ? const Center(child: Text('Please select a branch.'))
                : StreamBuilder<QuerySnapshot>(
                    stream: menusCollection.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                            child: Text('Something went wrong.'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text('No menus found. Tap + to add one.'));
                      }
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
          ),
        ],
      ),
      floatingActionButton: (_selectedBranchId != null)
          ? FloatingActionButton(
              onPressed: _addMenu,
              child: const Icon(Icons.add),
              tooltip: 'Add Menu',
            )
          : null,
    );
  }
}

// --- Screen 2: Shows the details (categories and items) for a specific menu ---
class MenuDetailScreen extends StatefulWidget {
  final Menu menu;
  final String branchId;

  const MenuDetailScreen(
      {super.key, required this.menu, required this.branchId});

  @override
  State<MenuDetailScreen> createState() => _MenuDetailScreenState();
}

class _MenuDetailScreenState extends State<MenuDetailScreen> {
  CollectionReference get categoriesCollection => FirebaseFirestore.instance
      .collection('branches')
      .doc(widget.branchId)
      .collection('menus')
      .doc(widget.menu.name)
      .collection('categories');

  CollectionReference get itemsCollection => FirebaseFirestore.instance
      .collection('branches')
      .doc(widget.branchId)
      .collection('menus')
      .doc(widget.menu.name)
      .collection('items');

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
            TextField(
                controller: _categoryNameController,
                decoration: const InputDecoration(labelText: 'Category Name')),
            TextField(
                controller: _selectionLimitController,
                decoration: const InputDecoration(labelText: 'Selection Limit'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = _categoryNameController.text.trim();
              final limit =
                  int.tryParse(_selectionLimitController.text.trim()) ?? 1;
              if (name.isNotEmpty) {
                final newCategory = MenuCategory(
                  menuName: widget.menu.name,
                  categoryName: name,
                  selectionLimit: limit,
                );
                await categoriesCollection.doc(name).set(newCategory.toMap());
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
        content: TextField(
            controller: _itemNameController,
            decoration: const InputDecoration(labelText: 'Item Name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = _itemNameController.text.trim();
              if (name.isNotEmpty) {
                final newItem = MenuItem(
                  menuName: widget.menu.name,
                  categoryName: category.categoryName,
                  itemName: name,
                );
                await itemsCollection.add(newItem.toMap());
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
      appBar: AppBar(title: Text('Menu: ${widget.menu.name}')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          const Text('Categories',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: categoriesCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading categories.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final categories = snapshot.data!.docs
                    .map((doc) => MenuCategory.fromMap(
                        doc.data() as Map<String, dynamic>))
                    .toList();
                if (categories.isEmpty) {
                  return const Center(child: Text('No categories.'));
                }
                return ListView(
                  children: categories.map((cat) {
                    return ExpansionTile(
                      title: Text(cat.categoryName),
                      subtitle: Text('Selection limit: ${cat.selectionLimit}'),
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: itemsCollection
                              .where('categoryName',
                                  isEqualTo: cat.categoryName)
                              .snapshots(),
                          builder: (context, itemSnapshot) {
                            if (itemSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const ListTile(
                                  title: Text('Loading items...'));
                            }
                            final items = itemSnapshot.data?.docs.map((doc) {
                                  return MenuItem.fromMap(
                                      doc.data() as Map<String, dynamic>);
                                }).toList() ??
                                [];
                            return Column(
                              children: [
                                ...items.map((item) =>
                                    ListTile(title: Text(item.itemName))),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
        tooltip: 'Add Category',
      ),
    );
  }
}
