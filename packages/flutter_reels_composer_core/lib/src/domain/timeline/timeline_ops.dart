import '../project/timeline_clip.dart';

/// Smallest composition piece kept after a trim or split.
const kMinClipPiece = Duration(milliseconds: 120);

/// Default snap window on the composition timeline.
const kDefaultSnapWindow = Duration(milliseconds: 100);

/// Dip-to-black fade applied at a clip's outgoing edge (and matching fade-in
/// on the next clip). Not an overlapping crossfade.
const kDefaultClipFade = Duration(milliseconds: 300);

/// Caps a fade so it cannot exceed half the clip (avoids overlapping in/out).
Duration clampFade(Duration fade, Duration clipDuration) {
  if (fade <= Duration.zero || clipDuration <= Duration.zero) {
    return Duration.zero;
  }
  final max = Duration(microseconds: clipDuration.inMicroseconds ~/ 2);
  if (max < const Duration(milliseconds: 40)) return Duration.zero;
  return fade > max ? max : fade;
}

/// Opacity of a clip at [localTime] (0 at the clip start).
///
/// [fadeIn] comes from the previous clip's [TimelineClip.transitionOut].
/// [fadeOut] is this clip's own `transitionOut`.
double clipFadeOpacity({
  required Duration localTime,
  required Duration clipDuration,
  Duration fadeIn = Duration.zero,
  Duration fadeOut = Duration.zero,
}) {
  if (clipDuration <= Duration.zero) return 1.0;
  var t = localTime;
  if (t.isNegative) t = Duration.zero;
  if (t > clipDuration) t = clipDuration;

  var opacity = 1.0;
  final fadeInClamped = clampFade(fadeIn, clipDuration);
  final fadeOutClamped = clampFade(fadeOut, clipDuration);
  if (fadeInClamped > Duration.zero && t < fadeInClamped) {
    opacity = t.inMicroseconds / fadeInClamped.inMicroseconds;
  }
  if (fadeOutClamped > Duration.zero) {
    final remaining = clipDuration - t;
    if (remaining < fadeOutClamped) {
      opacity *= remaining.inMicroseconds / fadeOutClamped.inMicroseconds;
    }
  }
  return opacity.clamp(0.0, 1.0);
}

/// Snap [value] onto the nearest [targets] if within [window].
Duration snapDuration(
  Duration value, {
  required Iterable<Duration> targets,
  Duration window = kDefaultSnapWindow,
}) {
  var best = value;
  var bestDelta = window;
  for (final target in targets) {
    final delta = (target - value).abs();
    if (delta <= bestDelta) {
      best = target;
      bestDelta = delta;
    }
  }
  return best;
}

/// Composition times at 0, every clip junction, and the project end.
List<Duration> clipJunctions(List<TimelineClip> clips) {
  final out = <Duration>[Duration.zero];
  var cursor = Duration.zero;
  for (final clip in clips) {
    cursor += clip.trimmedDuration;
    out.add(cursor);
  }
  return out;
}

Duration prefixBeforeClip(List<TimelineClip> clips, int index) {
  var sum = Duration.zero;
  for (var i = 0; i < index && i < clips.length; i++) {
    sum += clips[i].trimmedDuration;
  }
  return sum;
}

/// Clip that contains [at] on the composition timeline (last clip includes end).
int? clipIndexAt(List<TimelineClip> clips, Duration at) {
  if (clips.isEmpty) return null;
  var cursor = Duration.zero;
  for (var i = 0; i < clips.length; i++) {
    final end = cursor + clips[i].trimmedDuration;
    final last = i == clips.length - 1;
    if (at < end || (last && at <= end)) return i;
    cursor = end;
  }
  return clips.length - 1;
}

/// Split [clip] at global composition time [at].
///
/// Returns null when the cut would leave a piece shorter than [minPiece].
({TimelineClip left, TimelineClip right})? splitLegacyClip({
  required TimelineClip clip,
  required Duration prefix,
  required Duration at,
  required String newClipId,
  Duration minPiece = kMinClipPiece,
}) {
  final local = at - prefix;
  if (local < minPiece || clip.trimmedDuration - local < minPiece) {
    return null;
  }
  final sourceAt =
      clip.trimStart +
      Duration(microseconds: (local.inMicroseconds * clip.speed).round());
  if (sourceAt <= clip.trimStart || sourceAt >= clip.trimEnd) return null;
  return (
    left: clip.copyWith(trimEnd: sourceAt, transitionOut: Duration.zero),
    right: clip.copyWith(id: newClipId, trimStart: sourceAt),
  );
}

Duration _compSpan(Duration sourceSpan, double speed) {
  if (speed <= 0) return sourceSpan;
  return Duration(microseconds: (sourceSpan.inMicroseconds / speed).round());
}

Duration _sourceSpan(Duration composition, double speed) {
  return Duration(microseconds: (composition.inMicroseconds * speed).round());
}

/// Moves the junction between [leftIndex] and [leftIndex + 1] to [junction].
///
/// Trims the left clip's end and the right clip's start together so the
/// timeline stays gapless. Returns null when the cut is impossible.
List<TimelineClip>? rollJunction({
  required List<TimelineClip> clips,
  required int leftIndex,
  required Duration junction,
  Duration minPiece = kMinClipPiece,
}) {
  if (leftIndex < 0 || leftIndex + 1 >= clips.length) return null;
  final left = clips[leftIndex];
  final right = clips[leftIndex + 1];
  final prefix = prefixBeforeClip(clips, leftIndex);
  final pair = left.trimmedDuration + right.trimmedDuration;

  final leftMax = _compSpan(left.sourceDuration - left.trimStart, left.speed);
  final rightMax = _compSpan(right.trimEnd, right.speed);
  var minLeft = minPiece;
  var maxLeft = pair - minPiece;
  if (leftMax < maxLeft) maxLeft = leftMax;
  final minLeftFromRight = pair - rightMax;
  if (minLeftFromRight > minLeft) minLeft = minLeftFromRight;
  if (maxLeft < minLeft) return null;

  var leftComp = junction - prefix;
  if (leftComp < minLeft) leftComp = minLeft;
  if (leftComp > maxLeft) leftComp = maxLeft;

  final leftEnd = left.trimStart + _sourceSpan(leftComp, left.speed);
  final rightComp = pair - leftComp;
  final rightStart = right.trimEnd - _sourceSpan(rightComp, right.speed);
  if (leftEnd <= left.trimStart ||
      leftEnd > left.sourceDuration ||
      rightStart < Duration.zero ||
      rightStart >= right.trimEnd) {
    return null;
  }

  final next = [...clips];
  next[leftIndex] = left.copyWith(trimEnd: leftEnd);
  next[leftIndex + 1] = right.copyWith(trimStart: rightStart);
  return next;
}
