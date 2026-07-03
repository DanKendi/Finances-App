import 'package:flutter/material.dart';

// Mapeia o nome do ícone (salvo no banco) para o IconData do Flutter
const Map<String, IconData> categoryIcons = {
  'food': Icons.restaurant,
  'health': Icons.favorite,
  'education': Icons.school,
  'leisure': Icons.sports_esports,
  'transport': Icons.directions_car,
  'home': Icons.home,
  'clothing': Icons.checkroom,
  'bills': Icons.receipt,
  'other': Icons.category,
};

// Converte a string hex salva no banco para Color do Flutter
Color hexToColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}