import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});
  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  final _price = TextEditingController();
  String _type = 'House';
  int _hours = 24;
  List<XFile> _images = [];
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _city.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final files = await ImagePicker().pickMultiImage(imageQuality: 40, maxWidth: 640);
      if (files.isNotEmpty) setState(() => _images = files.take(3).toList());
    } catch (_) {
      _msg('Could not open gallery');
    }
  }

  Future<void> _submit() async {
    final price = double.tryParse(_price.text.trim());
    if (_title.text.trim().length < 3 || _city.text.trim().isEmpty || price == null || price <= 0) {
      _msg('Enter title, city and a valid price');
      return;
    }
    if (_images.isEmpty) {
      _msg('Add at least one photo');
      return;
    }
    setState(() => _loading = true);
    try {
      final encoded = <String>[];
      var total = 0;
      for (final f in _images) {
        final b64 = base64Encode(await f.readAsBytes());
        total += b64.length;
        encoded.add(b64);
      }
      if (total > 850000) {
        throw Exception('Photos are too large. Use fewer or smaller photos.');
      }
      await ApiService.createProperty({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'city': _city.text.trim(),
        'type': _type,
        'basePrice': price,
        'durationHours': _hours,
        'images': encoded,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Property listed!')));
    } catch (e) {
      _msg(cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List a property')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 110,
            child: _images.isEmpty
                ? OutlinedButton.icon(
                    onPressed: _loading ? null : _pick,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Add photos (max 3)'))
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in _images)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(f.path), width: 110, height: 110, fit: BoxFit.cover)),
                        ),
                      IconButton(onPressed: _loading ? null : _pick, icon: const Icon(Icons.edit)),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City / Area')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const ['House', 'Apartment', 'Villa', 'Plot', 'Commercial']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? 'House'),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Starting price (₹)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _hours,
            decoration: const InputDecoration(labelText: 'Auction duration'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 hour')),
              DropdownMenuItem(value: 6, child: Text('6 hours')),
              DropdownMenuItem(value: 24, child: Text('24 hours')),
              DropdownMenuItem(value: 72, child: Text('3 days')),
              DropdownMenuItem(value: 168, child: Text('7 days')),
            ],
            onChanged: (v) => setState(() => _hours = v ?? 24),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _desc,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description (beds, area, facilities...)')),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Start auction'),
            ),
          ),
        ],
      ),
    );
  }
}
