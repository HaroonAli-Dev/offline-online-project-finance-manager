import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Restores the nullable-value convenience getter removed in Riverpod 3.
extension AsyncValueNullableValue<T> on AsyncValue<T> {
  T? get valueOrNull => hasValue ? value : null;
}
