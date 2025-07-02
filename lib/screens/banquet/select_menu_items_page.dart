import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/menu.dart';
import '../../models/menu_category.dart';
import '../../models/menu_item.dart';

class SelectMenuItemsPage extends StatefulWidget {
  final Menu menu;
  final Map<String, Set<String>> initialSelections;
  final String branchId;

  SelectMenuItemsPage({
    required this.menu,
    required this.initialSelections,
    required this.branchId,
  });

  @override
  State<SelectMenuItemsPage> createState() => _SelectMenuItemsPageState();
}

class _SelectMenuItemsPageState extends State<SelectMenuItemsPage> {
  final Map<String, bool> _expanded = {};
  late Map<String, Set<String>> _selected;

  List<MenuCategory>? _categories;
  List<MenuItem>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = Map.fromEntries(
      widget.initialSelections.entries
          .map((e) => MapEntry(e.key, {...e.value})),
    );
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('menus')
          .doc(widget.menu.name)
          .collection('categories')
          .get();
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('branches')
          .doc(widget.branchId)
          .collection('menus')
          .doc(widget.menu.name)
          .collection('items')
          .get();
      setState(() {
        _categories = categoriesSnapshot.docs
            .map((doc) =>
                MenuCategory.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
        _items = itemsSnapshot.docs
            .map((doc) => MenuItem.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading menu data.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Select Items - ${widget.menu.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade400.withOpacity(0.95),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save selections',
            onPressed: () {
              Navigator.pop(context, _selected);
            },
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
        child: SafeArea(
          child: _loading
              ? _buildStateMessage(
                  icon: Icons.hourglass_empty,
                  text: 'Loading menu...',
                  color: Colors.red.shade300,
                )
              : _error != null
                  ? _buildStateMessage(
                      icon: Icons.error_outline,
                      text: _error!,
                      color: Colors.red.shade400,
                    )
                  : _categories == null || _categories!.isEmpty
                      ? _buildStateMessage(
                          icon: Icons.category_outlined,
                          text: 'No categories.',
                          color: Colors.grey.shade500,
                        )
                      : _items == null
                          ? _buildStateMessage(
                              icon: Icons.hourglass_empty,
                              text: 'Loading items...',
                              color: Colors.red.shade300,
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 24, 16, 90),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 18),
                              itemCount: _categories!.length,
                              itemBuilder: (context, idx) {
                                final cat = _categories![idx];
                                final catItems = _items!
                                    .where((i) =>
                                        i.categoryName == cat.categoryName)
                                    .toList();
                                _selected.putIfAbsent(
                                    cat.categoryName, () => {});
                                final isOpen =
                                    _expanded[cat.categoryName] ?? false;

                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  color: Colors.white,
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                      splashColor: Colors.red.shade50,
                                    ),
                                    child: ExpansionTile(
                                      key: PageStorageKey(cat.categoryName),
                                      initiallyExpanded: isOpen,
                                      onExpansionChanged: (val) => setState(
                                          () => _expanded[cat.categoryName] =
                                              val),
                                      tilePadding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 8),
                                      title: Row(
                                        children: [
                                          Icon(Icons.fastfood,
                                              color: Colors.red.shade400,
                                              size: 22),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              cat.categoryName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Pick ${cat.selectionLimit}',
                                              style: TextStyle(
                                                color: Colors.red.shade400,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      children: catItems.isEmpty
                                          ? [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Text(
                                                  'No items in this category.',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade500,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                            ]
                                          : catItems.map((item) {
                                              final selected =
                                                  _selected[cat.categoryName]!
                                                      .contains(item.itemName);
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    onTap: () {
                                                      setState(() {
                                                        if (!selected &&
                                                            _selected[cat
                                                                        .categoryName]!
                                                                    .length <
                                                                cat.selectionLimit) {
                                                          _selected[cat
                                                                  .categoryName]!
                                                              .add(item
                                                                  .itemName);
                                                        } else if (selected) {
                                                          _selected[cat
                                                                  .categoryName]!
                                                              .remove(item
                                                                  .itemName);
                                                        }
                                                      });
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        color: selected
                                                            ? Colors.red.shade50
                                                            : Colors
                                                                .grey.shade50,
                                                        border: Border.all(
                                                          color: selected
                                                              ? Colors
                                                                  .red.shade400
                                                              : Colors.grey
                                                                  .shade300,
                                                          width:
                                                              selected ? 2 : 1,
                                                        ),
                                                      ),
                                                      child: ListTile(
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 12,
                                                                vertical: 2),
                                                        leading: Icon(
                                                          selected
                                                              ? Icons
                                                                  .check_circle
                                                              : Icons
                                                                  .circle_outlined,
                                                          color: selected
                                                              ? Colors
                                                                  .red.shade400
                                                              : Colors.grey
                                                                  .shade400,
                                                        ),
                                                        title: Text(
                                                          item.itemName,
                                                          style: TextStyle(
                                                            fontWeight: selected
                                                                ? FontWeight
                                                                    .bold
                                                                : FontWeight
                                                                    .normal,
                                                            color: selected
                                                                ? Colors.red
                                                                    .shade400
                                                                : Colors.grey
                                                                    .shade800,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text(
              'Save Selections',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            onPressed: () {
              Navigator.pop(context, _selected);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
