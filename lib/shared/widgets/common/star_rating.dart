import 'package:flutter/material.dart';

class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({super.key, required this.rating, this.size = 18});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final full = i < rating.floor();
          final half = !full && i < rating;
          return Icon(
            full ? Icons.star : (half ? Icons.star_half : Icons.star_border),
            color: Colors.amber,
            size: size,
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: size * 0.8, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class StarRatingInput extends StatelessWidget {
  const StarRatingInput({super.key, required this.rating, required this.onChanged, this.size = 36});

  final double rating;
  final ValueChanged<double> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final starWidth = box.size.width / 5;
            final starIndex = (local.dx / starWidth).floor();
            final isHalf = (local.dx % starWidth) < starWidth / 2;
            onChanged((starIndex + (isHalf ? 0.5 : 1.0)).clamp(0.5, 5.0));
          },
          child: Icon(
            i < rating.floor()
                ? Icons.star
                : (i < rating ? Icons.star_half : Icons.star_border),
            color: Colors.amber,
            size: size,
          ),
        );
      }),
    );
  }
}
