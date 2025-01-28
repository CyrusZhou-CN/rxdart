import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'errors.dart';

/// Signature for the `listener` function which takes the `BuildContext` along
/// with the previous and current `value` and is responsible for
/// executing in response to `value` changes.
typedef ValueStreamWidgetListener<T> = void Function(
  BuildContext context,
  T previous,
  T current,
);

/// {@template value_stream_listener}
/// Takes a [ValueStreamWidgetListener] and a [stream] and invokes
/// the [listener] in response to `value` changes in the [stream].
///
/// It should be used for functionality that needs to occur only in response to
/// a `value` change such as navigation, showing a `SnackBar`, showing
/// a `Dialog`, etc...
///
/// The [listener] is guaranteed to only be called once for each `value` change
/// unlike the `builder` in `ValueStreamBuilder`.
///
/// [ValueStreamListener] requires [stream.hasValue] to always be `true`,
/// and the [stream] does not emit any error events.
/// See [ValueStreamHasNoValueError] and [UnhandledStreamError]
/// for more information.
///
/// **Example**
///
/// ```dart
/// ValueStreamListener<T>(
///   stream: valueStream,
///   listener: (context, previous, current) {
///     // do stuff here based on valueStream's
///     // previous and current values
///   },
///   child: Container(),
/// )
/// ```
/// {@endtemplate}
class ValueStreamListener<T> extends StatefulWidget {
  /// {@macro value_stream_listener}
  const ValueStreamListener({
    Key? key,
    required this.stream,
    required this.listener,
    required this.child,
  }) : super(key: key);

  /// The [ValueStream] that the [ValueStreamConsumer] will interact with.
  final ValueStream<T> stream;

  /// Takes the `BuildContext` along with the `previous` and `current` values
  ///  and is responsible for executing in response to `value` changes.
  final ValueStreamWidgetListener<T> listener;

  /// The widget which will be rendered as a descendant of the
  /// [ValueStreamListener].
  final Widget child;

  @override
  State<ValueStreamListener<T>> createState() => _ValueStreamListenerState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ValueStream<T>>('stream', stream))
      ..add(ObjectFlagProperty<ValueStreamWidgetListener<T>>.has(
          'listener', listener))
      ..add(
        ObjectFlagProperty<Widget>.has('child', child),
      );
  }
}

class _ValueStreamListenerState<T> extends State<ValueStreamListener<T>> {
  StreamSubscription<T>? _subscription;
  late T _currentValue;
  ErrorAndStackTrace? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _initialized = true;
  }

  @override
  void didUpdateWidget(covariant ValueStreamListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream != oldWidget.stream) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    final stream = widget.stream;

    _error = validateValueStreamInitialValue(stream);
    if (_error != null) {
      return;
    }

    if (!_initialized) {
      _currentValue = stream.value;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyListener(stream.value);
      });
    }

    _subscription = stream.skip(1).listen(
      (value) {
        if (!mounted) return;
        _notifyListener(value);
      },
      onError: (Object e, StackTrace s) {
        if (!mounted) return;
        _error = ErrorAndStackTrace(UnhandledStreamError(e), s);
        reportError(_error!);
        setState(() {});
      },
    );
  }

  void _notifyListener(T value) {
    final previousValue = _currentValue;
    _currentValue = value;
    widget.listener(context, previousValue, value);
  }

  void _unsubscribe() {
    _subscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ErrorWidget(_error!.error);
    }
    return widget.child;
  }
}
