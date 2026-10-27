import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final int? count;
  final double starSize;
  final Color starColor;
  final bool isInteractive;
  final ValueChanged<double>? onRatingChanged;

  const RatingStars({
    super.key,
    required this.rating,
    this.count,
    this.starSize = 18.0,
    this.starColor = const Color(0xFFFFB800),
    this.isInteractive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isInteractive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starValue = index + 1.0;
          return IconButton(
            iconSize: starSize,
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            constraints: const BoxConstraints(),
            icon: Icon(
              rating >= starValue
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: starColor,
            ),
            onPressed: () => onRatingChanged?.call(starValue),
          );
        }),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ...List.generate(5, (index) {
          final difference = rating - index;
          IconData iconData;
          if (difference >= 0.75) {
            iconData = Icons.star_rounded;
          } else if (difference >= 0.25) {
            iconData = Icons.star_half_rounded;
          } else {
            iconData = Icons.star_border_rounded;
          }

          return Icon(
            iconData,
            size: starSize,
            color: starColor,
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: starSize * 0.75,
            color: Colors.grey[800],
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: starSize * 0.7,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}
