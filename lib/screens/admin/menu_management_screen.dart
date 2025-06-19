import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/menu.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';

class MenuManagementScreen extends StatefulWidget {
  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final _menusBox = Hive.box<Menu>('menus');
  final _categoriesBox = Hive.box<MenuCategory>('menuCategories');
  final _itemsBox = Hive.box<MenuItem>('menuItems');

  final _menuNameController = TextEditingController();
  final _menuPriceController = TextEditingController();

  void _addMenu() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _menuNameController, decoration: InputDecoration(labelText: 'Menu Name')),
            TextField(controller: _menuPriceController, decoration: InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = _menuNameController.text.trim();
              final price = double.tryParse(_menuPriceController.text.trim()) ?? 0;
              if (name.isNotEmpty) {
                _menusBox.put(name, Menu(name: name, price: price));
              }
              _menuNameController.clear();
              _menuPriceController.clear();
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('Add'),
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
    final menus = _menusBox.values.toList();

    return Scaffold(
      appBar: AppBar(title: Text('Menu Management')),
      body: ListView(
        children: menus.map((m) {
          return ListTile(
            title: Text('${m.name} — ₹${m.price}+tax'),
            trailing: Icon(Icons.edit),
            onTap: () => _manageMenu(m),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMenu,
        child: Icon(Icons.add),
        tooltip: 'Add Menu',
      ),
    );
  }
}

class MenuDetailScreen extends StatefulWidget {
  final Menu menu;
  MenuDetailScreen({required this.menu});

  @override
  State<MenuDetailScreen> createState() => _MenuDetailScreenState();
}

class _MenuDetailScreenState extends State<MenuDetailScreen> {
  final _categoriesBox = Hive.box<MenuCategory>('menuCategories');
  final _itemsBox = Hive.box<MenuItem>('menuItems');

  final _categoryNameController = TextEditingController();
  final _selectionLimitController = TextEditingController();

  void _addCategory() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _categoryNameController, decoration: InputDecoration(labelText: 'Category Name')),
            TextField(controller: _selectionLimitController, decoration: InputDecoration(labelText: 'Selection Limit'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = _categoryNameController.text.trim();
              final limit = int.tryParse(_selectionLimitController.text.trim()) ?? 1;
              if (name.isNotEmpty) {
                _categoriesBox.add(MenuCategory(
                  menuName: widget.menu.name,
                  categoryName: name,
                  selectionLimit: limit,
                ));
              }
              _categoryNameController.clear();
              _selectionLimitController.clear();
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addItem(MenuCategory category) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Item to ${category.categoryName}'),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: 'Item Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _itemsBox.add(MenuItem(
                  menuName: widget.menu.name,
                  categoryName: category.categoryName,
                  itemName: name,
                ));
              }
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categoriesBox.values
        .where((c) => c.menuName == widget.menu.name)
        .toList();

    final items = _itemsBox.values
        .where((i) => i.menuName == widget.menu.name)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('${widget.menu.name} Details')),
      body: ListView(
        children: [
          ...categories.map((cat) {
            final catItems = items.where((i) => i.categoryName == cat.categoryName).toList();
            return ExpansionTile(
              title: Text('${cat.categoryName} (Max: ${cat.selectionLimit})'),
              children: [
                ...catItems.map((item) => ListTile(title: Text(item.itemName))),
                ListTile(
                  title: TextButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Add Item'),
                    onPressed: () => _addItem(cat),
                  ),
                )
              ],
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: Icon(Icons.category),
        tooltip: 'Add Category',
      ),
    );
  }
}