import '../contracts/frame_extractor.dart';
import '../domain/project/timeline_clip.dart';

/// Drift that triggers a music seek while preview is playing.
const kPreviewAudioDriftThreshold = Duration(milliseconds: 120);

/// Playhead delta that makes [DuetStage] consider a seek (vs. normal playback).
const kDuetSeekNotifyThreshold = Duration(milliseconds: 80);

/// Allowed parent/user clock error before seeking the duet parent.
const kDuetParentDriftThreshold = Duration(milliseconds: 280);

/// Clip-cell filmstrip: full source, fixed count (trim/zoom crop in the widget).
const kTimelineThumbCount = 8;
const kTimelineThumbHeight = 56;

/// Music file position for a composition playhead.
Duration musicSeekTarget(Duration timelinePosition, Duration startOffset) {
  final t = startOffset + timelinePosition;
  return t.isNegative ? Duration.zero : t;
}

/// Whether two clocks have drifted enough to correct with a seek.
bool shouldCorrectClock({
  required Duration expected,
  required Duration actual,
  required Duration threshold,
}) {
  return (expected - actual).abs() >= threshold;
}

/// Whether a new preview [next] position should attempt a duet parent seek.
bool duetSeekFromNotify({
  required Duration? previous,
  required Duration? next,
  Duration jump = kDuetSeekNotifyThreshold,
}) {
  if (identical(previous, next) || previous == next) return false;
  if (previous == null || next == null) return true;
  return (previous - next).abs() >= jump;
}

/// Wrap [position] onto a looping parent whose duration is [mediaDuration].
Duration wrapLoopingClock(Duration position, Duration mediaDuration) {
  if (mediaDuration <= Duration.zero) {
    return position.isNegative ? Duration.zero : position;
  }
  if (position.isNegative) return Duration.zero;
  if (position < mediaDuration) return position;
  final span = mediaDuration.inMicroseconds;
  if (span <= 0) return Duration.zero;
  return Duration(microseconds: position.inMicroseconds % span);
}

/// Warm the same extract keys clip cells will request (no-op if already cached).
Future<void> prefetchTimelineThumbs(
  FrameExtractorPort extractor,
  Iterable<TimelineClip> clips, {
  int count = kTimelineThumbCount,
  int height = kTimelineThumbHeight,
}) {
  final jobs = <Future<void>>[];
  for (final clip in clips) {
    if (clip.kind == TimelineClipKind.image) continue;
    jobs.add(
      extractor.extract(
        sourcePath: clip.sourcePath,
        start: Duration.zero,
        end: clip.sourceDuration,
        count: count,
        height: height,
      ),
    );
  }
  if (jobs.isEmpty) return Future<void>.value();
  return Future.wait(jobs);
}
