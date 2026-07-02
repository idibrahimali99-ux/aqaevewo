import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// معرض صور بملء الشاشة مع تمرير سلس.
Future<void> showPropertyImageGallery(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  int? propertyCode,
}) {
  final urls = imageUrls.where((u) => u.trim().isNotEmpty).toList();
  if (urls.isEmpty) return Future.value();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق',
    barrierColor: Colors.black87,
    pageBuilder: (ctx, _, _) => _GalleryPage(
      urls: urls,
      initialIndex: initialIndex.clamp(0, urls.length - 1),
      propertyCode: propertyCode,
    ),
  );
}

class _GalleryPage extends StatefulWidget {
  const _GalleryPage({
    required this.urls,
    required this.initialIndex,
    this.propertyCode,
  });

  final List<String> urls;
  final int initialIndex;
  final int? propertyCode;

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _page = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _page,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return InteractiveViewer(
                  minScale: 0.85,
                  maxScale: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.urls[i],
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Text(
                '${_index + 1} / ${widget.urls.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
