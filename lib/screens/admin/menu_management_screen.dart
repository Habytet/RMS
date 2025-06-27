// lib/screens/admin/menu_management_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/menu.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';
import '../../providers/user_provider.dart';
import '../../models/hall.dart';
import 'package:provider/provider.dart';

// --- Screen 1: Shows the list of all main menus ---
class MenuManagementScreen extends StatefulWidget {
  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  String? _selectedBranchId;
  String? _selectedHallId;
  List<Hall> _halls = [];
  final _menuNameController = TextEditingController();
  final _menuPriceController = TextEditingController();

  CollectionReference getMenusCollection() {
    if (_selectedBranchId != null && _selectedHallId != null) {
      return FirebaseFirestore.instance
          .collection('branches')
          .doc(_selectedBranchId)
          .collection('halls')
          .doc(_selectedHallId)
          .collection('menus');
    }
    // fallback to a dummy collection
    return FirebaseFirestore.instance.collection('dummy');
  }

  Future<void> _fetchHalls() async {
    if (_selectedBranchId == null) return;
    final hallsSnapshot = await FirebaseFirestore.instance
        .collection('branches')
        .doc(_selectedBranchId)
        .collection('halls')
        .get();
    setState(() {
      _halls = hallsSnapshot.docs
          .map((doc) => Hall.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      if (_halls.isNotEmpty &&
          (_selectedHallId == null ||
              !_halls.any((h) => h.name == _selectedHallId))) {
        _selectedHallId = _halls.first.name;
      }
    });
  }

  @override
  void dispose() {
    _menuNameController.dispose();
    _menuPriceController.dispose();
    super.dispose();
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
          _fetchHalls();
        }
      });
    } else if (!isCorporate && _selectedBranchId == null) {
      _selectedBranchId = userProvider.currentBranchId;
      _fetchHalls();
    }

    // Fetch halls when branch changes
    if (_selectedBranchId != null &&
        (_halls.isEmpty || !_halls.any((h) => h.name == _selectedHallId))) {
      _fetchHalls();
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
            builder: (_) => MenuDetailScreen(
                menu: menu,
                branchId: _selectedBranchId!,
                hallId: _selectedHallId!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Menu Management')),
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
                    _selectedHallId = null;
                    _halls = [];
                  });
                  _fetchHalls();
                },
              ),
            ),
          if (_halls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: DropdownButtonFormField<String>(
                value: _selectedHallId,
                decoration: const InputDecoration(
                    labelText: 'Select Hall', border: OutlineInputBorder()),
                items: [
                  ..._halls.map((h) =>
                      DropdownMenuItem(value: h.name, child: Text(h.name))),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedHallId = value;
                  });
                },
              ),
            ),
          Expanded(
            child: (_selectedBranchId == null || _selectedHallId == null)
                ? const Center(child: Text('Please select a branch and hall.'))
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
      floatingActionButton:
          (_selectedBranchId != null && _selectedHallId != null)
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
  final String hallId;
  const MenuDetailScreen(
      {super.key,
      required this.menu,
      required this.branchId,
      required this.hallId});

  @override
  State<MenuDetailScreen> createState() => _MenuDetailScreenState();
}

class _MenuDetailScreenState extends State<MenuDetailScreen> {
  CollectionReference get categoriesCollection => FirebaseFirestore.instance
      .collection('branches')
      .doc(widget.branchId)
      .collection('halls')
      .doc(widget.hallId)
      .collection('menus')
      .doc(widget.menu.name)
      .collection('categories');

  CollectionReference get itemsCollection => FirebaseFirestore.instance
      .collection('branches')
      .doc(widget.branchId)
      .collection('halls')
      .doc(widget.hallId)
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
