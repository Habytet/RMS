import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../models/menu.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';

class SelectMenuItemsPage extends StatefulWidget {
  final Menu menu;
  final Map<String, Set<String>> initialSelections;

  SelectMenuItemsPage({
    required this.menu,
    required this.initialSelections,
  });

  @override
  State<SelectMenuItemsPage> createState() => _SelectMenuItemsPageState();
}

class _SelectMenuItemsPageState extends State<SelectMenuItemsPage> {
  final Map<String, bool> _expanded = {};
  late Map<String, Set<String>> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Map.fromEntries(
      widget.initialSelections.entries.map((e) => MapEntry(e.key, {...e.value})),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = Hive.box<MenuCategory>('menuCategories')
        .values
        .where((c) => c.menuName == widget.menu.name)
        .toList();
    final items = Hive.box<MenuItem>('menuItems')
        .values
        .where((i) => i.menuName == widget.menu.name)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Items - ${widget.menu.name}'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            tooltip: 'Save selections',
            onPressed: () {
              Navigator.pop(context, _selected);
            },
          ),
        ],
      ),
      body: ListView(
        children: categories.map((cat) {
          final catItems = items.where((i) => i.categoryName == cat.categoryName).toList();
          _selected.putIfAbsent(cat.categoryName, () => {});
          final isOpen = _expanded[cat.categoryName] ?? false;

          return ExpansionTile(
            key: PageStorageKey(cat.categoryName),
            title: Text('${cat.categoryName} (Pick ${cat.selectionLimit})'),
            initiallyExpanded: isOpen,
            onExpansionChanged: (val) => setState(() => _expanded[cat.categoryName] = val),
            children: catItems.map((item) {
              final selected = _selected[cat.categoryName]!.contains(item.itemName);
              return CheckboxListTile(
                title: Text(item.itemName),
                value: selected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      if (_selected[cat.categoryName]!.length < cat.selectionLimit) {
                        _selected[cat.categoryName]!.add(item.itemName);
                      }
                    } else {
                      _selected[cat.categoryName]!.remove(item.itemName);
                    }
                  });
                },
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}