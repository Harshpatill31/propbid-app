import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/base64_image.dart';
import 'home_screen.dart' show inr;

class PropertyDetailScreen extends StatefulWidget {
  final String propertyId;
  const PropertyDetailScreen({super.key, required this.propertyId});
  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  final _bid = TextEditingController();
  Timer? _timer;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bid.dispose();
    super.dispose();
  }

  String _left(DateTime ends) {
    final d = ends.difference(DateTime.now());
    if (d.isNegative) return 'Ended';
    final days = d.inDays;
    final h = d.inHours % 24, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return '${days > 0 ? '${days}d ' : ''}${h}h ${m}m ${s}s';
  }

  Future<void> _placeBid() async {
    final amount = double.tryParse(_bid.text.trim());
    if (amount == null || amount <= 0) {
      _msg('Enter a valid amount');
      return;
    }
    setState(() => _placing = true);
    try {
      await ApiService.placeBid(widget.propertyId, amount);
      _bid.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      _msg('Bid placed!');
    } catch (e) {
      _msg(cleanError(e));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ref = FirebaseFirestore.instance.collection('properties').doc(widget.propertyId);
    return Scaffold(
      appBar: AppBar(title: const Text('Property details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Could not load property'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final p = snap.data!.data();
          if (p == null) return const Center(child: Text('Property not found'));

          final images = List<String>.from(p['images'] ?? []);
          final ends = (p['endsAt'] as Timestamp).toDate();
          final live = ends.isAfter(DateTime.now());
          final isOwner = p['ownerId'] == uid;
          final hasBids = (p['bidCount'] ?? 0) > 0;
          final minBid = hasBids ? (p['currentBid'] + p['minIncrement']) : p['basePrice'];

          return ListView(
            children: [
              SizedBox(
                height: 240,
                child: images.isEmpty
                    ? const Center(child: Icon(Icons.home, size: 60))
                    : PageView(
                        children: [
                          for (final img in images) Base64Image(img),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['title'] ?? '', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${p['type']} • ${p['city']} • by ${p['ownerName']}'),
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(hasBids ? 'Current bid' : 'Starting price'),
                              Text(inr.format(p['currentBid']),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              if (hasBids) Text('Leader: ${p['highestBidderName']}'),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              const Text('Time left'),
                              Text(_left(ends),
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: live ? Colors.green.shade800 : Colors.red)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    if (!live)
                      Card(
                        color: Colors.amber.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(hasBids
                              ? (p['highestBidderId'] == uid
                                  ? '🎉 You won this auction at ${inr.format(p['currentBid'])}'
                                  : 'Auction ended. Winner: ${p['highestBidderName']} at ${inr.format(p['currentBid'])}')
                              : 'Auction ended with no bids.'),
                        ),
                      )
                    else if (isOwner)
                      const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('This is your listing. You cannot bid on it.')))
                    else ...[
                      TextField(
                        controller: _bid,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Your bid (₹)',
                          helperText: 'Minimum: ${inr.format(minBid)}',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _placing ? null : _placeBid,
                          icon: _placing
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.gavel),
                          label: const Text('Place bid'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text('Description', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text((p['description'] ?? '').toString().isEmpty ? 'No description' : p['description']),
                    const SizedBox(height: 20),
                    Text('Bid history (live)', style: Theme.of(context).textTheme.titleMedium),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: ref.collection('bids').orderBy('amount', descending: true).limit(20).snapshots(),
                      builder: (context, bs) {
                        if (!bs.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
                        if (bs.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('No bids yet. Be the first!'));
                        return Column(
                          children: [
                            for (final d in bs.data!.docs)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                                title: Text(d['bidderName'] ?? 'Bidder'),
                                trailing: Text(inr.format(d['amount']), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
