import 'package:honeybee/features/explore/services/poi_service.dart';

class CommunityContent {
  final String id;
  final String name;
  final String contentType;
  final String publicUrl;
  final DateTime createdAt;

  CommunityContent({
    required this.id,
    required this.name,
    required this.contentType,
    required this.publicUrl,
    required this.createdAt,
  });

  factory CommunityContent.fromJson(Map<String, dynamic> json, bool isLiked) {
    final profile = json['profiles'] as Map<String, dynamic>;
    
    return CommunityContent(
      id: json['id'] as String,
      name: json['name'] as String,
      contentType: json['content_type'] as String,
      publicUrl: json['public_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
} 