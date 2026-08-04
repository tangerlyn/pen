import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 프로필 이미지가 있으면 보여주고, 없으면 사람 아이콘으로 대체하는 공용 아바타.
/// [localFile]이 주어지면 [imageUrl]보다 우선한다 (새로 고른 사진 미리보기용).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.localFile,
    required this.radius,
    double? iconSize,
    this.backgroundColor = AppColors.chipBackground,
    this.iconColor = AppColors.textTertiary,
  }) : iconSize = iconSize ?? radius;

  final String? imageUrl;
  final File? localFile;
  final double radius;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final hasUrl = imageUrl != null && imageUrl!.isNotEmpty;
    final ImageProvider? provider = localFile != null
        ? FileImage(localFile!)
        : (hasUrl ? CachedNetworkImageProvider(imageUrl!) : null);

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: provider,
      child: provider == null
          ? Icon(Icons.person, size: iconSize, color: iconColor)
          : null,
    );
  }
}
