// Stateful version of future_progress_dialog.
// Future callbacks were interfering with the stateless nature of the old version.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

Decoration _defaultDecoration(BuildContext context) => BoxDecoration(
  // FIXME Cupertino: large border with a different color
  color: isCupertino(context) ? CupertinoTheme.of(context).scaffoldBackgroundColor : Theme.of(context).dialogBackgroundColor,
  shape: BoxShape.rectangle,
  borderRadius: const BorderRadius.all(Radius.circular(10)),
);

class FutureProgressDialog extends StatefulWidget {

  /// Dialog will be closed when [future] task is finished.
  @required
  final Future future;

  /// [BoxDecoration] of [FutureProgressDialog].
  final BoxDecoration? decoration;

  /// opacity of [FutureProgressDialog]
  final double opacity;

  /// If you want to use custom progress widget set [progress].
  final Widget? progress;

  /// If you want to use message widget set [message].
  final Widget? message;

  const FutureProgressDialog(
    this.future, {
    this.decoration,
    this.opacity = 1.0,
    this.progress,
    this.message,
  });

  @override
  _FutureProgressDialogState createState() => _FutureProgressDialogState();
}

class _FutureProgressDialogState extends State<FutureProgressDialog> {

  @override
  void initState() {
    super.initState();
    widget.future.then((val) {
      Navigator.of(context).pop(val);
    }).catchError((e) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        return Future(() {
          return false;
        });
      },
      child: _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    Widget content;
    if (widget.message == null) {
      content = Center(
        child: Container(
          height: 100,
          width: 100,
          alignment: Alignment.center,
          decoration: widget.decoration ?? _defaultDecoration(context),
          child: widget.progress ?? const CircularProgressIndicator(),
        ),
      );
    } else {
      content = Container(
        height: 100,
        padding: const EdgeInsets.all(20),
        decoration: widget.decoration ?? _defaultDecoration(context),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          widget.progress ?? const CircularProgressIndicator(),
          const SizedBox(width: 20),
          _buildText(context)
        ]),
      );
    }

    return PlatformAlertDialog(
      material: (context, platform) => MaterialAlertDialogData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      content: Opacity(
        opacity: widget.opacity,
        child: content,
      ),
    );
  }

  Widget _buildText(BuildContext context) {
    if (widget.message == null) {
      return const SizedBox.shrink();
    }
    return Expanded(
      flex: 1,
      child: widget.message!,
    );
  }
}
