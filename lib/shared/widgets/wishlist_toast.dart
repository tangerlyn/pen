import 'package:flutter/material.dart';
import 'center_toast.dart';

Future<void> showWishlistToast(BuildContext context, {required bool added}) {
  return showCenterToast(
    context,
    message: added ? '위시리스트에 추가되었습니다' : '위시리스트에서 제거되었습니다',
    icon: added ? Icons.favorite : Icons.favorite_border,
    iconColor: added ? Colors.redAccent : null,
  );
}
