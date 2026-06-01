import 'package:flutter/widgets.dart';

class PhysicalViewport extends StatelessWidget {
  const PhysicalViewport({
    required this.child,
    this.alignment = Alignment.topLeft,
    super.key,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final ratio = media.devicePixelRatio <= 1 ? 1.0 : media.devicePixelRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalSize = Size(constraints.maxWidth, constraints.maxHeight);
        final physicalSize = Size(
          logicalSize.width * ratio,
          logicalSize.height * ratio,
        );
        final physicalMedia = media.copyWith(
          size: physicalSize,
          devicePixelRatio: 1,
        );
        return FittedBox(
          fit: BoxFit.fill,
          alignment: alignment,
          child: SizedBox(
            width: physicalSize.width,
            height: physicalSize.height,
            child: MediaQuery(data: physicalMedia, child: child),
          ),
        );
      },
    );
  }
}
