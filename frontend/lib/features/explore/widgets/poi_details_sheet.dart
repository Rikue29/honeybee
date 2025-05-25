import 'package:flutter/material.dart';
import 'package:honeybee/features/explore/models/poi.dart';
import 'package:honeybee/features/explore/models/community_content.dart';
import 'package:honeybee/features/explore/services/poi_service.dart';

class POIDetailsSheet extends StatefulWidget {
  final POI poi;

  const POIDetailsSheet({super.key, required this.poi});

  @override
  State<POIDetailsSheet> createState() => _POIDetailsSheetState();
}

class _POIDetailsSheetState extends State<POIDetailsSheet> {
  final _poiService = POIService();
  List<CommunityContent>? _communityContent;
  bool _isLoading = true;
  Map<String, bool> _expandedSections = {
    'openingHours': false,
    'crowdDensity': false,
    'ticketPrices': false,
    'bestTimeToVisit': false,
  };

  @override
  void initState() {
    super.initState();
    _loadCommunityContent();
  }

  Future<void> _loadCommunityContent() async {
    try {
      final content = await _poiService.getCommunityContent(widget.poi.id);
      setState(() {
        _communityContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // TODO: Handle error
    }
  }

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
  }

  Widget _buildInfoRow({
    required String section,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
    Color? backgroundColor,
  }) {
    final isExpanded = _expandedSections[section] ?? false;
    
    return GestureDetector(
      onTap: () => _toggleSection(section),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: iconColor.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: iconColor,
                  size: 20,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 8),
              Divider(color: iconColor.withOpacity(0.2)),
              const SizedBox(height: 8),
              content,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityIcon(Facility facility) {
    IconData icon;
    Color color = Colors.orange.shade600;
    String label;

    switch (facility) {
      case Facility.toilets:
        icon = Icons.wc;
        label = 'Restrooms';
        break;
      case Facility.parking:
        icon = Icons.local_parking;
        label = 'Parking';
        break;
      case Facility.wifi:
        icon = Icons.wifi;
        label = 'Wi-Fi';
        break;
      case Facility.food:
        icon = Icons.restaurant;
        label = 'Food';
        break;
      case Facility.accessible:
        icon = Icons.accessible;
        label = 'Accessible';
        break;
    }

    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }

  ImageProvider _getPoiImage() {
    // Map of POI names to their corresponding image files
    final imageMap = {
      'Sultan Abu Bakar Museum': 'sultan_museum.png',
      'Abu Bakar Palace': 'istana_abubakar.png',
      'Pekan Riverfront': 'pekan_riverfront.png',
      'Masjid Sultan Abdullah': 'masjid_sultan_abdullah.png',
    };

    // Try to load the mapped image first
    if (imageMap.containsKey(widget.poi.name)) {
      return AssetImage('assets/images/${imageMap[widget.poi.name]}');
    }

    // Fallback to ID-based image if it exists
    return AssetImage('assets/images/${widget.poi.id}.jpg');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: _getPoiImage(),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.orange.shade700,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.poi.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.poi.description,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        section: 'openingHours',
                        icon: Icons.access_time,
                        iconColor: Colors.orange.shade700,
                        backgroundColor: Colors.orange.shade50,
                        title: 'Opening Hours',
                        content: Text(
                          '${widget.poi.openingTime?.format(context)} - ${widget.poi.closingTime?.format(context)}',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.poi.crowdDensity != null) ...[
                        _buildInfoRow(
                          section: 'crowdDensity',
                          icon: Icons.people,
                          iconColor: Colors.blue.shade700,
                          backgroundColor: Colors.blue.shade50,
                          title: 'Crowd Density',
                          content: Text(
                            widget.poi.crowdDensity!,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (widget.poi.ticketPriceAdult != null) ...[
                        _buildInfoRow(
                          section: 'ticketPrices',
                          icon: Icons.confirmation_number,
                          iconColor: Colors.green.shade700,
                          backgroundColor: Colors.green.shade50,
                          title: 'Ticket Prices',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Adults: RM ${widget.poi.ticketPriceAdult}',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Children: RM ${widget.poi.ticketPriceChild}',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (widget.poi.bestTimeToVisit != null) ...[
                        _buildInfoRow(
                          section: 'bestTimeToVisit',
                          icon: Icons.schedule,
                          iconColor: Colors.purple.shade700,
                          backgroundColor: Colors.purple.shade50,
                          title: 'Best Time to Visit',
                          content: Text(
                            widget.poi.bestTimeToVisit!,
                            style: TextStyle(
                              color: Colors.purple.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Available Facilities',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: widget.poi.facilities
                            .map((f) => _buildFacilityIcon(f))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Community Content',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_communityContent?.isEmpty ?? true)
                        Center(
                          child: Text(
                            'No community content yet',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _communityContent!.length,
                          itemBuilder: (context, index) {
                            final content = _communityContent![index];
                            debugPrint('Loading content: ${content.name} from URL: ${content.publicUrl}');
                            return GestureDetector(
                              onTap: () {
                                // TODO: Show full content view
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    content.publicUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint('Error loading image: $error');
                                      debugPrint('Stack trace: $stackTrace');
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.error_outline,
                                          color: Colors.red,
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / 
                                                loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Text(
                                      content.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 