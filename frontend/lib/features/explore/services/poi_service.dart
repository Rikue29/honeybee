import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:honeybee/features/explore/models/poi.dart';
import 'package:honeybee/features/explore/models/community_content.dart';
import 'package:flutter/material.dart';

class POIService {
  final _supabase = Supabase.instance.client;

  Future<List<POI>> getPOIs() async {
    try {
      debugPrint('Fetching POIs from Supabase...');
      final response = await _supabase
          .from('points_of_interest')
          .select('*, poi_facilities(facility)');

      debugPrint('POIs response: $response');

      final pois = response.map<POI>((json) => POI.fromJson(json)).toList();

      debugPrint('Parsed POIs: ${pois.map((p) => '${p.name} (${p.latitude}, ${p.longitude})').join(', ')}');
      return pois;
    } catch (e, stackTrace) {
      debugPrint('Error fetching POIs: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<CommunityContent>> getCommunityContent(String poiId) async {
    try {
      debugPrint('Fetching content from community-content bucket...');
      final List<FileObject> files = await _supabase
          .storage
          .from('community-content')
          .list();

      debugPrint('Found ${files.length} files in storage');
      
      final contents = files.map((file) {
        final url = _supabase.storage.from('community-content').getPublicUrl(file.name);
        debugPrint('Generated URL for ${file.name}: $url');
        
        return CommunityContent(
          id: file.name,
          name: file.name,
          contentType: _getContentType(file.name),
          publicUrl: url,
          createdAt: DateTime.now(),
        );
      }).toList();

      debugPrint('Processed ${contents.length} content items');
      return contents;
    } catch (e, stackTrace) {
      debugPrint('Error fetching community content: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'video';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'photo';
      default:
        return 'unknown';
    }
  }

  Future<void> toggleLike(String contentId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final existingLike = await _supabase
        .from('community_content_likes')
        .select()
        .eq('content_id', contentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingLike != null) {
      await _supabase
          .from('community_content_likes')
          .delete()
          .eq('content_id', contentId)
          .eq('user_id', userId);
    } else {
      await _supabase
          .from('community_content_likes')
          .insert({
            'content_id': contentId,
            'user_id': userId,
          });
    }
  }

  String getStorageUrl(String path) {
    return _supabase.storage.from('community-content').getPublicUrl(path);
  }
} 