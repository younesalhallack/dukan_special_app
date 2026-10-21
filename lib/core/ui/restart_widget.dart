import 'package:flutter/widgets.dart';

/// Rebuilds everything below it from scratch (new widget state, and new
/// Riverpod state when a ProviderScope is inside). Used after a restore so the
/// whole app reloads the restored data.
class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restart();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
