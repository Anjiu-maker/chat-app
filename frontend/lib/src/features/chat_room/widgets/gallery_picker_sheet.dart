import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

Future<File?> showGalleryPickerSheet(BuildContext context) {
  return showGeneralDialog<File?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭相册',
    barrierColor: Colors.black.withValues(alpha: .34),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, __) => const _GalleryPickerShell(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _GalleryPickerShell extends StatelessWidget {
  const _GalleryPickerShell();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth =
            constraints.maxWidth > 520 ? 430.0 : constraints.maxWidth;
        return ColoredBox(
          color: Colors.black.withValues(alpha: .18),
          child: Center(
            child: SizedBox(
              width: pageWidth,
              height: constraints.maxHeight,
              child: const _GalleryPickerPanel(),
            ),
          ),
        );
      },
    );
  }
}

class _GalleryPickerPanel extends StatefulWidget {
  const _GalleryPickerPanel();

  @override
  State<_GalleryPickerPanel> createState() => _GalleryPickerPanelState();
}

class _GalleryPickerPanelState extends State<_GalleryPickerPanel> {
  static const _pageSize = 80;

  final _assets = <AssetEntity>[];
  List<AssetPathEntity> _albums = const [];
  AssetPathEntity? _album;
  AssetEntity? _selected;
  bool _loading = true;
  bool _albumsOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        setState(() {
          _loading = false;
          _error = '需要允许访问相册后才能选择图片';
        });
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );
      if (albums.isEmpty) {
        setState(() {
          _albums = const [];
          _album = null;
          _assets.clear();
          _loading = false;
          _error = '相册里暂时没有图片';
        });
        return;
      }

      _albums = albums;
      await _selectAlbum(albums.first, closeMenu: false);
    } catch (_) {
      setState(() {
        _loading = false;
        _error = '相册加载失败';
      });
    }
  }

  Future<void> _selectAlbum(
    AssetPathEntity album, {
    bool closeMenu = true,
  }) async {
    setState(() {
      _album = album;
      _assets.clear();
      _selected = null;
      _loading = true;
      if (closeMenu) _albumsOpen = false;
    });

    try {
      final assets = await album.getAssetListPaged(page: 0, size: _pageSize);
      setState(() {
        _assets
          ..clear()
          ..addAll(assets);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = '相册加载失败';
      });
    }
  }

  Future<void> _sendSelected() async {
    final asset = _selected;
    if (asset == null) return;
    final file = await asset.originFile;
    if (!mounted) return;
    Navigator.of(context).pop(file);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF171717),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _GalleryHeader(
                  title: _albumTitle(_album),
                  expanded: _albumsOpen,
                  onClose: () => Navigator.of(context).pop(),
                  onToggleAlbums: () {
                    setState(() => _albumsOpen = !_albumsOpen);
                  },
                ),
                Expanded(child: _buildBody()),
                _GalleryFooter(
                  selected: _selected,
                  assets: _assets,
                  onSelect: (asset) => setState(() => _selected = asset),
                  onSend: _sendSelected,
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 56,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  );
                },
                child: _albumsOpen
                    ? _AlbumList(
                        key: const ValueKey('albums'),
                        albums: _albums,
                        selected: _album,
                        onSelect: _selectAlbum,
                      )
                    : const SizedBox.shrink(key: ValueKey('closed')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF159BFF)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                color: Colors.white54,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadAlbums,
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        return _AssetTile(
          asset: asset,
          selected: _selected?.id == asset.id,
          onTap: () => setState(() => _selected = asset),
        );
      },
    );
  }

  String _albumTitle(AssetPathEntity? album) {
    if (album == null) return '最近项目';
    return album.isAll ? '最近项目' : album.name;
  }
}

class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader({
    required this.title,
    required this.expanded,
    required this.onClose,
    required this.onToggleAlbums,
  });

  final String title;
  final bool expanded;
  final VoidCallback onClose;
  final VoidCallback onToggleAlbums;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          TextButton.icon(
            onPressed: onToggleAlbums,
            iconAlignment: IconAlignment.end,
            label: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumList extends StatelessWidget {
  const _AlbumList({
    required this.albums,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<AssetPathEntity> albums;
  final AssetPathEntity? selected;
  final ValueChanged<AssetPathEntity> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF171717),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 512),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          shrinkWrap: true,
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            final active = selected?.id == album.id;
            return _AlbumTile(
              album: album,
              selected: active,
              onTap: () => onSelect(album),
            );
          },
        ),
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.album,
    required this.selected,
    required this.onTap,
  });

  final AssetPathEntity album;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            _AlbumCover(album: album),
            const SizedBox(width: 12),
            Expanded(
              child: FutureBuilder<int>(
                future: album.assetCountAsync,
                builder: (context, snapshot) {
                  final count = snapshot.data;
                  final title = album.isAll ? '最近项目' : album.name;
                  return Text(
                    count == null ? title : '$title ($count)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: Color(0xFF159BFF)),
          ],
        ),
      ),
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({required this.album});

  final AssetPathEntity album;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AssetEntity>>(
      future: album.getAssetListPaged(page: 0, size: 1),
      builder: (context, snapshot) {
        final assets = snapshot.data ?? const <AssetEntity>[];
        final asset = assets.isEmpty ? null : assets.first;
        if (asset == null) {
          return const SizedBox(
            width: 44,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFF2A2A2A)),
            ),
          );
        }
        return SizedBox(
          width: 44,
          height: 44,
          child: _AssetThumbnail(asset: asset),
        );
      },
    );
  }
}

class _GalleryFooter extends StatelessWidget {
  const _GalleryFooter({
    required this.selected,
    required this.assets,
    required this.onSelect,
    required this.onSend,
  });

  final AssetEntity? selected;
  final List<AssetEntity> assets;
  final ValueChanged<AssetEntity> onSelect;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final previewAssets = assets.take(12).toList();
    return SizedBox(
      height: 92,
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final asset = previewAssets[index];
                return GestureDetector(
                  onTap: () => onSelect(asset),
                  child: Opacity(
                    opacity: selected?.id == asset.id ? 1 : .58,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: _AssetThumbnail(asset: asset),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 3),
              itemCount: previewAssets.length,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  TextButton(
                    onPressed: null,
                    child: Text(
                      '预览',
                      style: TextStyle(
                        color: selected == null
                            ? Colors.white24
                            : Colors.white.withValues(alpha: .72),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: null,
                    child: Text(
                      '编辑',
                      style: TextStyle(
                        color: selected == null
                            ? Colors.white24
                            : Colors.white.withValues(alpha: .72),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: selected == null ? null : onSend,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF159BFF),
                      disabledBackgroundColor:
                          const Color(0xFF159BFF).withValues(alpha: .22),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white38,
                      minimumSize: const Size(58, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('发送'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final AssetEntity asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _AssetThumbnail(asset: asset),
          Positioned(
            right: 6,
            top: 6,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? const Color(0xFF159BFF)
                    : Colors.black.withValues(alpha: .12),
                border: Border.all(color: Colors.white, width: 1.3),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetThumbnail extends StatelessWidget {
  const _AssetThumbnail({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(
        const ThumbnailSize.square(260),
        quality: 82,
      ),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFF242424)),
          );
        }
        return Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
