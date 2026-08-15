/// One timed caption cue (karaoke / auto-subs).
class CaptionCue {
  const CaptionCue({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;
  final Duration start;
  final Duration end;

  Map<String, dynamic> toJson() => {
    'text': text,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
  };

  factory CaptionCue.fromJson(Map<String, dynamic> json) {
    return CaptionCue(
      text: json['text'] as String? ?? '',
      start: Duration(milliseconds: json['startMs'] as int? ?? 0),
      end: Duration(
        milliseconds: json['endAtMs'] as int? ?? json['endMs'] as int? ?? 0,
      ),
    );
  }
}

abstract class CaptionEngine {
  const CaptionEngine();

  Future<List<CaptionCue>> transcribe(String mediaPath, {String locale = 'en'});

  /// Whether [transcribe] can return cues. [NullCaptionEngine] is false so the
  /// UI does not show a Generate action that cannot succeed.
  bool get canTranscribe => true;
}

class NullCaptionEngine extends CaptionEngine {
  const NullCaptionEngine();

  @override
  bool get canTranscribe => false;

  @override
  Future<List<CaptionCue>> transcribe(
    String mediaPath, {
    String locale = 'en',
  }) async {
    return const [];
  }
}
