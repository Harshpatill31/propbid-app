import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/base64_image.dart';
import 'add_property_screen.dart';
import 'property_detail_screen.dart';

final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _search = '';
  bool _onlyLive = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Auctions'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPropertyScreen())),
        icon: const Icon(Icons.add_home_work),
        label: const Text('List property'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                        hintText: 'Search city or title',
                        prefixIcon: Icon(Icons.search),
                        isDense: true),
                    onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Live'),
                  selected: _onlyLive,
                  onSelected: (v) => setState(() => _onlyLive = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('properties')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return const Center(child: Text('Could not load properties'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final now = DateTime.now();
                final docs = snap.data!.docs.where((d) {
                  final p = d.data();
                  final text = '${p['title']} ${p['city']}'.toLowerCase();
                  if (_search.isNotEmpty && !text.contains(_search)) return false;
                  final ends = (p['endsAt'] as Timestamp?)?.toDate();
                  if (_onlyLive && (ends == null || ends.isBefore(now))) return false;
                  return true;
                }).toList();
                if (docs.isEmpty) {
                  return const Center(child: Text('No properties yet. Tap "List property" to add one.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _PropertyCard(id: docs[i].id, data: docs[i].data(), uid: user?.uid),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final String? uid;
  const _PropertyCard({required this.id, required this.data, required this.uid});

  @override
  Widget build(BuildContext context) {
    final images = List<String>.from(data['images'] ?? []);
    final ends = (data['endsAt'] as Timestamp?)?.toDate();
    final live = ends != null && ends.isAfter(DateTime.now());
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: id))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: images.isEmpty
                      ? Container(color: Colors.grey.shade300, child: const Icon(Icons.home, size: 48))
                      : Base64Image(images.first),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Chip(
                    label: Text(live ? 'LIVE' : 'ENDED', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    backgroundColor: live ? Colors.green : Colors.red,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
                if (data['ownerId'] == uid)
                  const Positioned(
                      top: 8,
                      right: 8,
                      child: Chip(label: Text('Your listing'), visualDensity: VisualDensity.compact)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${data['type'] ?? ''} • ${data['city'] ?? ''}'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(inr.format(data['currentBid'] ?? 0),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary)),
                      Text('${data['bidCount'] ?? 0} bids'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
