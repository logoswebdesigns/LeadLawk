import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Sales Pitch Model
class SalesPitch {
  final String id;
  final String name;
  final String content;
  final String? description;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalesPitch({
    required this.id,
    required this.name,
    required this.content,
    this.description,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'description': description,
    'isDefault': isDefault,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SalesPitch.fromJson(Map<String, dynamic> json) {
    return SalesPitch(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      content: json['content'] ?? '',
      description: json['description'],
      isDefault: json['isDefault'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  SalesPitch copyWith({
    String? id,
    String? name,
    String? content,
    String? description,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SalesPitch(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Provider for managing sales pitches
final salesPitchesProvider = StateNotifierProvider<SalesPitchesNotifier, List<SalesPitch>>((ref) {
  return SalesPitchesNotifier();
});

class SalesPitchesNotifier extends StateNotifier<List<SalesPitch>> {
  static const String _storageKey = 'sales_pitches';
  
  SalesPitchesNotifier() : super([]) {
    _loadPitches();
  }

  Future<void> _loadPitches() async {
    final prefs = await SharedPreferences.getInstance();
    final pitchesJson = prefs.getString(_storageKey);
    
    if (pitchesJson != null) {
      final List<dynamic> decoded = json.decode(pitchesJson);
      state = decoded.map((e) => SalesPitch.fromJson(e)).toList();
    } else {
      // Initialize with default pitches if none exist
      await _initializeDefaultPitches();
    }
  }

  Future<void> _initializeDefaultPitches() async {
    final defaultPitches = [
      SalesPitch(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Professional Web Services',
        content: '''Hi! I noticed your business online and was impressed by your reviews. 

I specialize in helping local businesses like yours establish a stronger online presence through professional websites and digital marketing solutions.

Many of my clients have seen significant increases in customer inquiries after improving their web presence. I'd love to show you how we can do the same for your business.

Would you have 15 minutes this week for a brief call to discuss how we can help grow your customer base?''',
        description: 'Professional introduction for web development services',
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      SalesPitch(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        name: 'Quick Value Proposition',
        content: '''Hello! Quick question - are you happy with the number of new customers finding your business online?

I help local businesses get found by more customers through:
• Professional website design
• Google My Business optimization  
• Local SEO improvements

Most of my clients see results within 30 days. Interested in learning more?''',
        description: 'Short and direct pitch focusing on results',
        isDefault: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      SalesPitch(
        id: (DateTime.now().millisecondsSinceEpoch + 2).toString(),
        name: 'Competitor Comparison',
        content: '''Hi there! I was researching businesses in your industry and noticed that while you have great reviews, some of your competitors have a stronger online presence.

I specialize in helping businesses like yours:
• Stand out from the competition online
• Attract more high-quality leads
• Convert more visitors into customers

I have some specific ideas for your business that I'd love to share. Do you have time for a quick call this week?''',
        description: 'Pitch that leverages competitive analysis',
        isDefault: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    state = defaultPitches;
    await _savePitches();
  }

  Future<void> _savePitches() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> addPitch(SalesPitch pitch) async {
    state = [...state, pitch];
    await _savePitches();
  }

  Future<void> updatePitch(String id, SalesPitch updatedPitch) async {
    state = state.map((pitch) {
      if (pitch.id == id) {
        return updatedPitch;
      }
      // If setting a new default, unset others
      if (updatedPitch.isDefault && pitch.id != id) {
        return pitch.copyWith(isDefault: false);
      }
      return pitch;
    }).toList();
    await _savePitches();
  }

  Future<void> deletePitch(String id) async {
    // Don't allow deleting the last pitch
    if (state.length <= 1) return;
    
    final wasDefault = state.firstWhere((p) => p.id == id).isDefault;
    state = state.where((pitch) => pitch.id != id).toList();
    
    // If we deleted the default, make the first one default
    if (wasDefault && state.isNotEmpty) {
      state = state.map((pitch) {
        if (pitch == state.first) {
          return pitch.copyWith(isDefault: true);
        }
        return pitch;
      }).toList();
    }
    
    await _savePitches();
  }

  Future<void> setDefault(String id) async {
    state = state.map((pitch) {
      return pitch.copyWith(isDefault: pitch.id == id);
    }).toList();
    await _savePitches();
  }

  SalesPitch? getDefaultPitch() {
    try {
      return state.firstWhere((pitch) => pitch.isDefault);
    } catch (_) {
      return state.isNotEmpty ? state.first : null;
    }
  }
}