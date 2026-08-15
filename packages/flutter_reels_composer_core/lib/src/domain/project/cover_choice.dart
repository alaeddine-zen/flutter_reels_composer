import 'package:equatable/equatable.dart';

class CoverChoice extends Equatable {
  const CoverChoice({this.timeOffset = Duration.zero, this.customPath});

  final Duration timeOffset;
  final String? customPath;

  CoverChoice copyWith({Duration? timeOffset, String? customPath}) {
    return CoverChoice(
      timeOffset: timeOffset ?? this.timeOffset,
      customPath: customPath ?? this.customPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'timeOffsetMs': timeOffset.inMilliseconds,
    'customPath': customPath,
  };

  factory CoverChoice.fromJson(Map<String, dynamic> json) {
    return CoverChoice(
      timeOffset: Duration(milliseconds: json['timeOffsetMs'] as int? ?? 0),
      customPath: json['customPath'] as String?,
    );
  }

  @override
  List<Object?> get props => [timeOffset, customPath];
}
