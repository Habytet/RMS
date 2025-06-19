import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../providers/token_provider.dart';

class PodiumOperatorScreen extends StatefulWidget {
  @override
  State<PodiumOperatorScreen> createState() => _PodiumOperatorScreenState();
}

class _PodiumOperatorScreenState extends State<PodiumOperatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paxController = TextEditingController();
  final _childrenController = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendWhatsAppMessage(String phone, String name, int token) async {
    String sanitized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (sanitized.length == 10) {
      sanitized = '91$sanitized';
    }
    final message = Uri.encodeComponent("Hello $name, your table is ready. Your token is $token.");
    final url = "https://wa.me/$sanitized?text=$message";

    try {
      final success = await launchUrlString(url, mode: LaunchMode.externalApplication);
      if (!success) throw 'WhatsApp not available';
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open WhatsApp.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TokenProvider>(context);
    final queue = provider.queue;
    final tables = provider.availableTables;

    return Scaffold(
      appBar: AppBar(
        title: Text('Podium Operator'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Register'),
            Tab(text: 'Call Customers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Register Tab
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text('Next Token: ${provider.nextToken}', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: _nameController, decoration: InputDecoration(labelText: 'Customer Name')),
                TextField(controller: _phoneController, decoration: InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.number),
                TextField(controller: _paxController, decoration: InputDecoration(labelText: 'No. of Adults'), keyboardType: TextInputType.number),
                TextField(controller: _childrenController, decoration: InputDecoration(labelText: 'No. of Children'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    final phone = _phoneController.text.trim();
                    final pax = int.tryParse(_paxController.text.trim()) ?? 0;
                    final children = int.tryParse(_childrenController.text.trim()) ?? 0;
                    if (name.isEmpty || phone.isEmpty || pax == 0) return;

                    provider.addCustomer(name, phone, pax, children);
                    _nameController.clear();
                    _phoneController.clear();
                    _paxController.clear();
                    _childrenController.clear();
                  },
                  child: Text('Register Customer'),
                ),
              ],
            ),
          ),

          // Call Customers Tab
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available Tables:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                tables.isEmpty
                    ? Text('No tables available', style: TextStyle(color: Colors.grey))
                    : Wrap(
                  spacing: 8,
                  children: tables
                      .map((t) => Chip(label: Text('Table $t'), onDeleted: () => provider.removeTable(t)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Divider(),
                Text('Customers Waiting:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: queue.isEmpty
                      ? Center(child: Text('No customers in queue'))
                      : ListView.builder(
                    itemCount: queue.length,
                    itemBuilder: (context, index) {
                      final c = queue[index];
                      final duration = DateTime.now().difference(c.registeredAt);
                      final isLate = duration.inMinutes >= 15;

                      return Card(
                        color: isLate ? Colors.red : null,
                        child: ListTile(
                          title: Text(
                            '${c.name} (${c.pax} adults, ${c.children} kids)',
                            style: TextStyle(color: isLate ? Colors.white : null),
                          ),
                          subtitle: Text(
                            'Token: ${c.token} | Phone: ${c.phone} | Waiting: ${duration.inMinutes} mins',
                            style: TextStyle(color: isLate ? Colors.white70 : null),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.message, color: Colors.green),
                                onPressed: () => _sendWhatsAppMessage(c.phone, c.name, c.token),
                              ),
                              ElevatedButton(
                                onPressed: () => provider.callNext(c.token),
                                child: Text('Call'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}