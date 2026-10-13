import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Base64 string ko ek baar decode karke image dikhata hai
/// (timer se rebuild hone par dobara decode nahi hota).
class Base64Image extends StatefulWidget {
  final String data;
  const Base64Image(this.data, {super.key});
  @override
  State<Base64Image> createState() => _Base64ImageState();
}

class _Base64ImageState extends State<Base64Image> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant Base64Image old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _decode();
  }

  void _decode() {
    try {
      _bytes = base64Decode(widget.data);
    } catch (_) {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return Container(color: Colors.grey.shade300, child: const Center(child: Icon(Icons.broken_image)));
    }
    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      width: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          Container(color: Colors.grey.shade300, child: const Center(child: Icon(Icons.broken_image))),
    );
  }
}
