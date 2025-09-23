import 'dart:io';
import 'package:flutter/material.dart';

Widget storyImage(
  String? path, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
}) {
  final p = (path ?? '').trim();
  if (p.isEmpty) return _placeholder();

  if (p.startsWith('assets/')) {
    return Image.asset(p, fit: fit, alignment: alignment, errorBuilder: _err);
  } else if (p.startsWith('http')) {
    return Image.network(p, fit: fit, alignment: alignment, errorBuilder: _err);
  } else {
    return Image.file(
      File(p),
      fit: fit,
      alignment: alignment,
      errorBuilder: _err,
    );
  }
}

Widget _err(BuildContext _, Object __, StackTrace? ___) => _placeholder();

Widget _placeholder() => Container(
  color: Colors.grey.shade300,
  alignment: Alignment.center,
  child: const Icon(Icons.broken_image_outlined),
);
