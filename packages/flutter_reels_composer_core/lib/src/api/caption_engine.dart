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
  Future<List<CaptionCue>> transcribe(String mediaPath, {String locale = 'en'});
}

class NullCaptionEngine implements CaptionEngine {
  const NullCaptionEngine();

  @override
  Future<List<CaptionCue>> transcribe(
    String mediaPath, {
    String locale = 'en',
  }) async {
    return const [];
  }
}
