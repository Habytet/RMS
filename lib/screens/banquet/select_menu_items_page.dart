import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/menu.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';

class SelectMenuItemsPage extends StatefulWidget {
  final Menu menu;
  final Map<String, Set<String>> initialSelections;
  final String branchId;
  final String hallName;

  SelectMenuItemsPage({
    required this.menu,
    required this.initialSelections,
    required this.branchId,
    required this.hallName,
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
      widget.initialSelections.entries
          .map((e) => MapEntry(e.key, {...e.value})),
    );
  }

  CollectionReference get categoriesCollection => FirebaseFirestore.instance
      .collection('branches')
      .doc(widget.branchId)
      .collection('halls')
      .doc(widget.hallName)
      .collection('menus')
      .doc(widget.menu.name)
      .collection('categories');

  CollectionReference get itemsCollection => FirebaseFirestore.instance
      .collection('branches')
      .doc(widget.branchId)
      .collection('halls')
      .doc(widget.hallName)
      .collection('menus')
      .doc(widget.menu.name)
      .collection('items');

  @override
  Widget build(BuildContext context) {
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
      body: StreamBuilder<QuerySnapshot>(
        stream: categoriesCollection.snapshots(),
        builder: (context, catSnapshot) {
          if (catSnapshot.hasError)
            return const Center(child: Text('Error loading categories.'));
          if (catSnapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final categories = catSnapshot.data!.docs
              .map((doc) =>
                  MenuCategory.fromMap(doc.data() as Map<String, dynamic>))
              .toList();
          if (categories.isEmpty)
            return const Center(child: Text('No categories.'));

          return StreamBuilder<QuerySnapshot>(
            stream: itemsCollection.snapshots(),
            builder: (context, itemSnapshot) {
              if (itemSnapshot.hasError)
                return const Center(child: Text('Error loading items.'));
              if (itemSnapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final items = itemSnapshot.data!.docs
                  .map((doc) =>
                      MenuItem.fromMap(doc.data() as Map<String, dynamic>))
                  .toList();

              return ListView(
                children: categories.map((cat) {
                  final catItems = items
                      .where((i) => i.categoryName == cat.categoryName)
                      .toList();
                  _selected.putIfAbsent(cat.categoryName, () => {});
                  final isOpen = _expanded[cat.categoryName] ?? false;

                  return ExpansionTile(
                    key: PageStorageKey(cat.categoryName),
                    title: Text(
                        '${cat.categoryName} (Pick ${cat.selectionLimit})'),
                    initiallyExpanded: isOpen,
                    onExpansionChanged: (val) =>
                        setState(() => _expanded[cat.categoryName] = val),
                    children: catItems.map((item) {
                      final selected =
                          _selected[cat.categoryName]!.contains(item.itemName);
                      return CheckboxListTile(
                        title: Text(item.itemName),
                        value: selected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              if (_selected[cat.categoryName]!.length <
                                  cat.selectionLimit) {
                                _selected[cat.categoryName]!.add(item.itemName);
                              }
                            } else {
                              _selected[cat.categoryName]!
                                  .remove(item.itemName);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
