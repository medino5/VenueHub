import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

final moneyFormat = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
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
    if (imageUrl.trim().isEmpty) {
      return _ImageFallback(height: height, width: width);
    }

    final bytes = _isDataImage(imageUrl) ? _dataImageBytes(imageUrl) : null;
    final child = bytes != null
        ? Image.memory(
            bytes,
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
        .map(
          (image) => image is String
              ? image
              : (image['imageUrl'] ?? image['url'])?.toString(),
        )
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

Uint8List? _dataImageBytes(String value) {
  try {
    final comma = value.indexOf(',');
    final payload = comma >= 0 ? value.substring(comma + 1) : value;
    final bytes = base64Decode(payload);
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
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
  Widget build(BuildContext context) => StatusPill(status);
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final normalized = status.toUpperCase();
    final color = switch (normalized) {
      'APPROVED' || 'PAID' || 'COMPLETED' => colors.success,
      'REJECTED' || 'CANCELLED' => colors.danger,
      'PARTIALLY_PAID' || 'PENDING' => colors.warning,
      _ => colors.rausch,
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }
}

class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.onTap,
    this.title = 'Start your search',
    this.subtitle = 'Anywhere · Any week · Add guests',
    this.trailing,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        shadowColor: Colors.black.withValues(alpha: 0.16),
        elevation: 8,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          highlightColor: colors.surfaceGray,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: colors.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: colors.ink, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.divider),
                  ),
                  child: Icon(Icons.tune_rounded, color: colors.ink, size: 20),
                ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryItem {
  const CategoryItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

class CategoryRail extends StatelessWidget {
  const CategoryRail({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<CategoryItem> items;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return SizedBox(
      height: 82,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final item = items[index];
          final active = item.label == selected;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            highlightColor: colors.surfaceGray,
            onTap: () => onSelected(item.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 86,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    color: active ? colors.ink : colors.secondaryText,
                    size: 25,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: active ? colors.ink : colors.secondaryText,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 7),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: active ? 34 : 0,
                    height: 2,
                    decoration: BoxDecoration(
                      color: colors.ink,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemCount: items.length,
      ),
    );
  }
}

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(color: AppTheme.colorsOf(context).divider, height: 32);
  }
}

class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.amount,
    this.suffix = 'day',
    this.underlined = true,
    this.compact = false,
  });

  final num amount;
  final String suffix;
  final bool underlined;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      decoration: underlined ? TextDecoration.underline : null,
      decorationThickness: 1.2,
      color: AppTheme.colorsOf(context).ink,
    );
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(
            text: moneyFormat.format(amount),
            style: TextStyle(
              fontWeight: compact ? FontWeight.w700 : FontWeight.w800,
            ),
          ),
          TextSpan(text: ' / $suffix'),
        ],
      ),
    );
  }
}

class StickyBookingBar extends StatelessWidget {
  const StickyBookingBar({
    super.key,
    required this.price,
    required this.onReserve,
    this.label = 'Reserve',
  });

  final num price;
  final VoidCallback onReserve;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PriceText(amount: price, suffix: 'day', underlined: false),
                  Text(
                    'Total before taxes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: onReserve,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(label),
                ),
              ),
            ),
          ],
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
