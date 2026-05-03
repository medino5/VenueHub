import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

final moneyFormat = NumberFormat.currency(
  locale: 'en_PH',
  symbol: 'PHP ',
  decimalDigits: 0,
);
final dateFormat = DateFormat('MMM d, yyyy');
const venueHubLogoAsset = 'assets/branding/venuehub_logo.jpg';

class VenueHubLogo extends StatelessWidget {
  const VenueHubLogo({super.key, this.size = 64, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        venueHubLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppTheme.sky,
            borderRadius: BorderRadius.circular(size * 0.24),
          ),
          child: Icon(
            Icons.apartment_rounded,
            color: AppTheme.navy,
            size: size * 0.5,
          ),
        ),
      ),
    );

    if (!showWordmark) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        const Text(
          'VenueHub',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.ink),
        ),
      ],
    );
  }
}

class VenueImageView extends StatelessWidget {
  const VenueImageView({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.borderRadius,
  });

  final String imageUrl;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = _isDataImage(imageUrl)
        ? Image.memory(
            _dataImageBytes(imageUrl),
            height: height,
            width: width,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                _ImageFallback(height: height, width: width),
          )
        : Image.network(
            imageUrl,
            height: height,
            width: width,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _ImageFallback(height: height, width: width),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                height: height,
                width: width,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          );

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}

class VenueImageCarousel extends StatefulWidget {
  const VenueImageCarousel({
    super.key,
    required this.images,
    this.height = 220,
    this.borderRadius,
  });

  final List<dynamic> images;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<VenueImageCarousel> createState() => _VenueImageCarouselState();
}

class _VenueImageCarouselState extends State<VenueImageCarousel> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.images
        .map((image) => image is String ? image : image['imageUrl']?.toString())
        .whereType<String>()
        .where((imageUrl) => imageUrl.isNotEmpty)
        .toList();

    final carousel = Stack(
      children: [
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: urls.isEmpty
              ? _ImageFallback(height: widget.height, width: double.infinity)
              : PageView.builder(
                  itemCount: urls.length,
                  onPageChanged: (value) => setState(() => page = value),
                  itemBuilder: (context, index) => VenueImageView(
                    imageUrl: urls[index],
                    height: widget.height,
                    width: double.infinity,
                  ),
                ),
        ),
        if (urls.length > 1)
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${page + 1}/${urls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.borderRadius == null) return carousel;
    return ClipRRect(borderRadius: widget.borderRadius!, child: carousel);
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.height, this.width});

  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      color: AppTheme.sky,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppTheme.navy,
          size: 42,
        ),
      ),
    );
  }
}

bool _isDataImage(String value) => value.startsWith('data:image');

Uint8List _dataImageBytes(String value) {
  try {
    final comma = value.indexOf(',');
    final payload = comma >= 0 ? value.substring(comma + 1) : value;
    return base64Decode(payload);
  } catch (_) {
    return Uint8List(0);
  }
}

class VHSectionTitle extends StatelessWidget {
  const VHSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class VHStatCard extends StatelessWidget {
  const VHStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.blue),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class VHStatusChip extends StatelessWidget {
  const VHStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toUpperCase()) {
      'APPROVED' || 'PAID' => Colors.green,
      'REJECTED' || 'CANCELLED' => Colors.redAccent,
      'PARTIALLY_PAID' => Colors.orange,
      _ => AppTheme.teal,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 54, color: Colors.black38),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
