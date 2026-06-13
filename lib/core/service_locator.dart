library;

/// Very small service locator for dependency injection.
///
/// This is intentionally minimal and can be replaced by a package like
/// `get_it` in the future if needed.
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  final Map<Type, dynamic> _services = <Type, dynamic>{};

  bool isRegistered<T>() => _services.containsKey(T);

  /// Registers a singleton instance for [T].
  void registerSingleton<T>(T instance) {
    _services[T] = instance;
  }

  /// Returns the registered singleton for [T].
  ///
  /// Throws [StateError] if no instance has been registered.
  T get<T>() {
    final dynamic instance = _services[T];
    if (instance == null) {
      throw StateError('No service registered for type $T');
    }
    return instance as T;
  }
}

