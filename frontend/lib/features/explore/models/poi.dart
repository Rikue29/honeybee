import 'package:flutter/material.dart';

enum Facility {
  toilets,
  parking,
  wifi,
  food,
  accessible
}

class POI {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;
  final String? crowdDensity;
  final double? ticketPriceAdult;
  final double? ticketPriceChild;
  final String? bestTimeToVisit;
  final List<Facility> facilities;
  final DateTime createdAt;
  final DateTime updatedAt;

  POI({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.openingTime,
    this.closingTime,
    this.crowdDensity,
    this.ticketPriceAdult,
    this.ticketPriceChild,
    this.bestTimeToVisit,
    required this.facilities,
    required this.createdAt,
    required this.updatedAt,
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTimeString(String? timeStr) {
      if (timeStr == null) return null;
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      return null;
    }

    return POI(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      openingTime: parseTimeString(json['opening_time']),
      closingTime: parseTimeString(json['closing_time']),
      crowdDensity: json['crowd_density'],
      ticketPriceAdult: json['ticket_price_adult']?.toDouble(),
      ticketPriceChild: json['ticket_price_child']?.toDouble(),
      bestTimeToVisit: json['best_time_to_visit'],
      facilities: (json['poi_facilities'] as List<dynamic>?)
          ?.map((f) => Facility.values.firstWhere(
              (e) => e.toString().split('.').last == f['facility']))
          .toList() ?? [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
} 