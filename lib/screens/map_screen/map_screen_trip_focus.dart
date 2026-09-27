part of '../map_screen.dart';

/// Clearance under the trip card so the last stop is not hidden behind the
/// map's bottom bar.
const double _kTripFocusBottomSpacer = 100;

class _TripFocusBottomCard extends StatelessWidget {
  const _TripFocusBottomCard({
    required this.drag,
    required this.onBack,
    required this.itinerary,
    required this.isLoading,
    required this.errorMessage,
    required this.bottomSpacer,
    required this.onStopTap,
    required this.onRefresh,
    required this.lastUpdated,
  });

  final SheetDrag drag;
  final VoidCallback onBack;
  final Itinerary? itinerary;
  final bool isLoading;
  final String? errorMessage;
  final double bottomSpacer;
  final StopTapCallback onStopTap;
  final Future<void> Function() onRefresh;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHandle(drag: drag),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              BottomSheetBackButton(onPressed: onBack),
              if (lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: LastUpdatedFooter(
                    lastUpdated: lastUpdated,
                    compact: true,
                  ),
                ),
            ],
          ),
          Expanded(
            child: _TripFocusContent(
              itinerary: itinerary,
              isLoading: isLoading,
              errorMessage: errorMessage,
              bottomSpacer: bottomSpacer,
              onStopTap: onStopTap,
              onRefresh: onRefresh,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripFocusContent extends StatelessWidget {
  const _TripFocusContent({
    required this.itinerary,
    required this.isLoading,
    required this.errorMessage,
    required this.bottomSpacer,
    required this.onStopTap,
    required this.onRefresh,
  });

  final Itinerary? itinerary;
  final bool isLoading;
  final String? errorMessage;
  final double bottomSpacer;
  final StopTapCallback onStopTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoadingSkeleton();
    if (errorMessage != null) return _buildError();

    final itinerary = this.itinerary;
    if (itinerary == null || itinerary.legs.isEmpty) return _buildEmpty();

    return TripDetailsView(
      itinerary: itinerary,
      onRefresh: onRefresh,
      onStopTap: onStopTap,
      trailingSlivers: const [
        SliverToBoxAdapter(child: SizedBox(height: _kTripFocusBottomSpacer)),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            const SkeletonCard(
              height: 140,
              borderRadius: BorderRadius.all(Radius.circular(14)),
              margin: EdgeInsets.all(12),
            ),
            const SkeletonCard(
              height: 420,
              borderRadius: BorderRadius.all(Radius.circular(14)),
              margin: EdgeInsets.all(12),
            ),
            SizedBox(height: bottomSpacer),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ErrorNotice(message: errorMessage!),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: EmptyState(
        title: 'No trip data available',
        titleStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.black.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
