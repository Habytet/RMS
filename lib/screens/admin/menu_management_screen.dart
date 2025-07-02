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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Migrate Hall Menus',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This will move all existing menus from individual halls to the branch level. '
          'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _migrateHallMenusToBranch();
            },
            child: const Text('Migrate'),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
              ),
              const SizedBox(width: 16),
              const Text('Migrating menus...'),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add Menu',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _menuNameController,
                decoration: InputDecoration(
                  labelText: 'Menu Name',
                  prefixIcon: const Icon(Icons.restaurant_menu),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.red.shade400, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _menuPriceController,
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.red.shade400, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Menu Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Add migration button for existing users
          if (_selectedBranchId != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Migrate Hall Menus to Branch',
                onPressed: () => _showMigrationDialog(context),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            if (isCorporate)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business,
                            color: Colors.red.shade400, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Select Branch',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedBranchId,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.red.shade400, width: 2),
                        ),
                      ),
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
                  ],
                ),
              ),
            Expanded(
              child: (_selectedBranchId == null)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Please select a branch',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: menusCollection.snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Something went wrong',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          );
                        }
                        if (snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_menu_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No menus found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap + to add your first menu',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final menus = snapshot.data!.docs.map((doc) {
                          return Menu.fromMap(
                              doc.data() as Map<String, dynamic>);
                        }).toList();
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.restaurant_menu,
                                      color: Colors.red.shade400, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Manage Menus',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        Text(
                                          '${menus.length} menu${menus.length == 1 ? '' : 's'} found',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Menus List
                            ...menus
                                .map((m) => Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 5,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.all(16),
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.red.shade100,
                                          child: Icon(
                                            Icons.restaurant_menu,
                                            color: Colors.red.shade600,
                                          ),
                                        ),
                                        title: Text(
                                          m.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '₹${m.price}+tax',
                                                style: TextStyle(
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.edit,
                                            color: Colors.red.shade600,
                                            size: 20,
                                          ),
                                        ),
                                        onTap: () => _manageMenu(m),
                                      ),
                                    ))
                                .toList(),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: (_selectedBranchId != null)
          ? FloatingActionButton(
              onPressed: _addMenu,
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Add Category',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _categoryNameController,
              decoration: InputDecoration(
                labelText: 'Category Name',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _selectionLimitController,
              decoration: InputDecoration(
                labelText: 'Selection Limit',
                prefixIcon: const Icon(Icons.numbers),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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

  void _editCategory(MenuCategory category) {
    _categoryNameController.text = category.categoryName;
    _selectionLimitController.text = category.selectionLimit.toString();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Edit Category',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _categoryNameController,
              decoration: InputDecoration(
                labelText: 'Category Name',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _selectionLimitController,
              decoration: InputDecoration(
                labelText: 'Selection Limit',
                prefixIcon: const Icon(Icons.numbers),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final name = _categoryNameController.text.trim();
              final limit =
                  int.tryParse(_selectionLimitController.text.trim()) ?? 1;
              if (name.isNotEmpty) {
                final updatedCategory = MenuCategory(
                  menuName: widget.menu.name,
                  categoryName: name,
                  selectionLimit: limit,
                );
                await categoriesCollection.doc(category.categoryName).delete();
                await categoriesCollection
                    .doc(name)
                    .set(updatedCategory.toMap());
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(MenuCategory category) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Category',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${category.categoryName}"? This will also delete all items in this category. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              // Delete all items in this category first
              final itemsSnapshot = await itemsCollection
                  .where('categoryName', isEqualTo: category.categoryName)
                  .get();
              for (var doc in itemsSnapshot.docs) {
                await doc.reference.delete();
              }
              // Then delete the category
              await categoriesCollection.doc(category.categoryName).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Add Item to ${category.categoryName}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: _itemNameController,
          decoration: InputDecoration(
            labelText: 'Item Name',
            prefixIcon: const Icon(Icons.fastfood),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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

  void _editItem(MenuItem item) {
    _itemNameController.text = item.itemName;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Edit Item',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: _itemNameController,
          decoration: InputDecoration(
            labelText: 'Item Name',
            prefixIcon: const Icon(Icons.fastfood),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final name = _itemNameController.text.trim();
              if (name.isNotEmpty) {
                final updatedItem = MenuItem(
                  menuName: widget.menu.name,
                  categoryName: item.categoryName,
                  itemName: name,
                );
                // Find the document ID for this item
                final itemsSnapshot = await itemsCollection
                    .where('itemName', isEqualTo: item.itemName)
                    .where('categoryName', isEqualTo: item.categoryName)
                    .get();
                if (itemsSnapshot.docs.isNotEmpty) {
                  await itemsSnapshot.docs.first.reference
                      .update(updatedItem.toMap());
                }
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(MenuItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Item',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${item.itemName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              // Find the document ID for this item
              final itemsSnapshot = await itemsCollection
                  .where('itemName', isEqualTo: item.itemName)
                  .where('categoryName', isEqualTo: item.categoryName)
                  .get();
              if (itemsSnapshot.docs.isNotEmpty) {
                await itemsSnapshot.docs.first.reference.delete();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Menu: ${widget.menu.name}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.category, color: Colors.red.shade400, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: categoriesCollection.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading categories',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    );
                  }
                  final categories = snapshot.data!.docs
                      .map((doc) => MenuCategory.fromMap(
                          doc.data() as Map<String, dynamic>))
                      .toList();
                  if (categories.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No categories',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to add your first category',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: categories.map((cat) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(
                              Icons.category,
                              color: Colors.blue.shade600,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cat.categoryName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Colors.grey.shade600,
                                ),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editCategory(cat);
                                  } else if (value == 'delete') {
                                    _deleteCategory(cat);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit,
                                            color: Colors.blue.shade600,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Edit Category'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            color: Colors.red.shade600,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        const Text('Delete Category'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          subtitle: Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Selection limit: ${cat.selectionLimit}',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          children: [
                            StreamBuilder<QuerySnapshot>(
                              stream: itemsCollection
                                  .where('categoryName',
                                      isEqualTo: cat.categoryName)
                                  .snapshots(),
                              builder: (context, itemSnapshot) {
                                if (itemSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }
                                final items = itemSnapshot.data?.docs
                                        .map((doc) {
                                      return MenuItem.fromMap(
                                          doc.data() as Map<String, dynamic>);
                                    }).toList() ??
                                    [];
                                return Column(
                                  children: [
                                    if (items.isNotEmpty)
                                      ...items.map((item) => ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor:
                                                  Colors.green.shade100,
                                              radius: 16,
                                              child: Icon(
                                                Icons.fastfood,
                                                color: Colors.green.shade600,
                                                size: 16,
                                              ),
                                            ),
                                            title: Text(
                                              item.itemName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            trailing: PopupMenuButton<String>(
                                              icon: Icon(
                                                Icons.more_vert,
                                                color: Colors.grey.shade600,
                                                size: 18,
                                              ),
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  _editItem(item);
                                                } else if (value == 'delete') {
                                                  _deleteItem(item);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit,
                                                          color: Colors
                                                              .blue.shade600,
                                                          size: 16),
                                                      const SizedBox(width: 8),
                                                      const Text('Edit Item'),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete,
                                                          color: Colors
                                                              .red.shade600,
                                                          size: 16),
                                                      const SizedBox(width: 8),
                                                      const Text('Delete Item'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                    Container(
                                      margin: const EdgeInsets.all(8),
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Add Item'),
                                        onPressed: () => _addItem(cat),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade400,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Add Category',
      ),
    );
  }
}
