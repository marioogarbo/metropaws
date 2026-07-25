import 'package:flutter/material.dart';

class PetAvatar extends StatelessWidget {
  final String? photoUrl;
  final double size;
  final String? petName;

  const PetAvatar({super.key, this.photoUrl, this.size = 56, this.petName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surfaceContainerHighest,
        image: photoUrl != null
            ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: photoUrl == null
          ? ClipOval(
              child: Image.asset(
                'assets/images/pet-care-no-text.jpg',
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            )
          : null,
    );
  }
}
