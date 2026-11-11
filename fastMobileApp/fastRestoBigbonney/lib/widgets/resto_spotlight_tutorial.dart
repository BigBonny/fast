import 'package:flutter/material.dart';
import '../theme.dart';
import '../l10n/tr.dart';
import 'fast_ui.dart';

class RestoSpotlightTutorial extends StatelessWidget {
  final Rect? targetRect;
  final String title;
  final String description;
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const RestoSpotlightTutorial({
    super.key,
    required this.targetRect,
    required this.title,
    required this.description,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final target =
        targetRect ??
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 56,
          height: 56,
        );
    final showBelow = target.center.dy < size.height * 0.46;
    final horizontalInset = 16.0;
    final cardWidth = (size.width - horizontalInset * 2).clamp(0.0, 420.0);

    final card = Semantics(
      liveRegion: true,
      namesRoute: true,
      label:
          '${tr(context, 'tutor_step').replaceAll('{a}', '${step + 1}').replaceAll('{b}', '$totalSteps')} $title. $description',
      child: Material(
        color: context.fast.card,
        elevation: 18,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.all(FASTSpace.s16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FASTRadius.md),
            border: Border.all(color: FASTPro.teal, width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: FASTPro.teal.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(FASTRadius.pill),
                    ),
                    child: Text(
                      '${step + 1} / $totalSteps',
                      style: FASTText.price.copyWith(
                        fontSize: 12,
                        color: FASTPro.teal,
                      ),
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      minimumSize: Size(48, 48),
                      foregroundColor: context.fast.t2,
                    ),
                    child: Text(
                      tr(context, 'skip_tuto'),
                      style: FASTText.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                title,
                style: FASTText.title.copyWith(color: context.fast.t1),
              ),
              SizedBox(height: 8),
              Text(
                description,
                style: FASTText.body.copyWith(
                  color: context.fast.t2,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (step + 1) / totalSteps,
                        minHeight: 5,
                        backgroundColor: context.fast.faint,
                        valueColor: const AlwaysStoppedAnimation(FASTPro.teal),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  FastButton(
                    label: step == totalSteps - 1 ? 'Terminer' : 'Suivant',
                    onPressed: onNext,
                    kind: FastButtonKind.ink,
                    expand: false,
                    height: 48,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SpotlightPainter(target)),
            ),
            Positioned(
              left: (size.width - cardWidth) / 2,
              top: showBelow
                  ? (target.bottom + 18).clamp(
                      safePadding.top + 12,
                      size.height - 300,
                    )
                  : null,
              bottom: showBelow
                  ? null
                  : (size.height - target.top + 18).clamp(
                      safePadding.bottom + 12,
                      size.height - 300,
                    ),
              child: card,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect target;

  _SpotlightPainter(this.target);

  @override
  void paint(Canvas canvas, Size size) {
    final expanded = target.inflate(8);
    final radius = Radius.circular(expanded.height > 70 ? 16 : 12);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(expanded, radius));

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(expanded, radius),
      Paint()
        ..color = FASTPro.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}
