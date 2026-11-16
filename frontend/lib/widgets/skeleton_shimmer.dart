import 'package:flutter/material.dart';

/// Reusable Shimmer Animation Controller & Skeleton Building Blocks
class SkeletonShimmer extends StatefulWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animation = Tween<double>(begin: -1.2, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + _animation.value, -0.3),
              end: Alignment(1.0 + _animation.value, 0.3),
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF8FAFC),
                Color(0xFFE2E8F0),
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Standalone skeleton placeholder box
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shimmer Skeleton for an entire House / EB Record Card
class HouseCardSkeleton extends StatelessWidget {
  const HouseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Chips: Zone & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 80, height: 22, borderRadius: 12),
              SkeletonBox(width: 70, height: 22, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 12),

          // Consumer & EB Number
          Row(
            children: [
              SkeletonBox(width: 36, height: 36, shape: BoxShape.circle),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 16, borderRadius: 6),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 100, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Address lines
          SkeletonBox(width: double.infinity, height: 12, borderRadius: 4),
          const SizedBox(height: 6),
          SkeletonBox(width: 220, height: 12, borderRadius: 4),
          const SizedBox(height: 14),

          // Action Buttons Bar
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 38, borderRadius: 10)),
              const SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 38, borderRadius: 10)),
              const SizedBox(width: 8),
              SkeletonBox(width: 38, height: 38, borderRadius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full screen list skeleton for HomeScreen
class HomeListSkeleton extends StatelessWidget {
  const HomeListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        itemCount: 4,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        itemBuilder: (_, __) => const HouseCardSkeleton(),
      ),
    );
  }
}
