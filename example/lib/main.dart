import 'package:flutter/material.dart';
import 'package:flutter_reels_composer/flutter_reels_composer.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  String _status = 'Ready';

  Future<void> _open() async {
    final result = await FlutterReelsComposer.open(
      context,
      config: ComposerConfig(
        theme: ComposerTheme.snapTikTok,
        templateCatalog: TemplateCatalog.bundled,
        locale: const Locale('en'),
        extraTools: const [],
        onEvent: (e) => debugPrint('${e.type.name} ${e.properties}'),
      ),
    );
    if (!mounted) return;
    setState(() {
      _status = result == null
          ? 'Cancelled'
          : 'Exported ${result.videoFile.path} (${result.duration.inSeconds}s)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Reels Composer')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_status, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _open,
                child: const Text('Open composer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
