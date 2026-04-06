using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Text.Json;

namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// Base implementation of IPluginData. Uses ConcurrentDictionary internally
  /// and provides deep-copy semantics on DataStore access to prevent
  /// cross-AssemblyLoadContext reference leaking.
  /// Formalizes the Ace-era "plugin Data object" pattern.
  ///
  /// When ConcurrentObservableCollections is updated for .NET 10 (BinaryFormatter removal),
  /// this can be switched to use ConcurrentObservableDictionary for richer change notification.
  /// </summary>
  public class PluginDataBase : IPluginData, IDisposable {
    private readonly ConcurrentDictionary<string, object> _store = new();
    private readonly List<Action<PluginDataChangedEventArgs>> _subscribers = new();
    private readonly object _subscriberLock = new();
    private bool _disposed;

    /// <summary>
    /// Returns a deep-copied read-only snapshot of the data store.
    /// </summary>
    public IReadOnlyDictionary<string, object> DataStore {
      get {
        var snapshot = new Dictionary<string, object>();
        foreach (var kvp in _store) {
          snapshot[kvp.Key] = DeepCopy(kvp.Value);
        }
        return snapshot;
      }
    }

    /// <summary>
    /// Observable stream of data change notifications.
    /// Implementation uses a simple subscriber list instead of full Rx dependency.
    /// </summary>
    public IObservable<PluginDataChangedEventArgs> DataChanged => new PluginDataObservable(_subscribers, _subscriberLock);

    /// <summary>Sets a value in the internal store and raises change notification.</summary>
    protected void Set(string key, object value) {
      var existed = _store.TryGetValue(key, out var oldValue);
      _store[key] = value;
      NotifyChange(new PluginDataChangedEventArgs {
        Key = key,
        OldValue = existed ? DeepCopy(oldValue!) : null,
        NewValue = DeepCopy(value),
        ChangeKind = existed ? PluginDataChangeKind.Updated : PluginDataChangeKind.Added
      });
    }

    /// <summary>Gets a typed value from the internal store.</summary>
    protected T? Get<T>(string key) {
      if (_store.TryGetValue(key, out var val) && val is T typed)
        return typed;
      return default;
    }

    /// <summary>Removes a key from the internal store and raises change notification.</summary>
    protected bool Remove(string key) {
      if (_store.TryRemove(key, out var removed)) {
        NotifyChange(new PluginDataChangedEventArgs {
          Key = key,
          OldValue = DeepCopy(removed),
          ChangeKind = PluginDataChangeKind.Removed
        });
        return true;
      }
      return false;
    }

    private void NotifyChange(PluginDataChangedEventArgs args) {
      Action<PluginDataChangedEventArgs>[] snapshot;
      lock (_subscriberLock) {
        snapshot = _subscribers.ToArray();
      }
      foreach (var subscriber in snapshot) {
        subscriber(args);
      }
    }

    private static object DeepCopy(object obj) {
      var json = JsonSerializer.Serialize(obj);
      return JsonSerializer.Deserialize<object>(json)!;
    }

    public void Dispose() {
      if (!_disposed) {
        lock (_subscriberLock) {
          _subscribers.Clear();
        }
        _disposed = true;
      }
    }

    private sealed class PluginDataObservable : IObservable<PluginDataChangedEventArgs> {
      private readonly List<Action<PluginDataChangedEventArgs>> _subscribers;
      private readonly object _lock;

      public PluginDataObservable(List<Action<PluginDataChangedEventArgs>> subscribers, object subscriberLock) {
        _subscribers = subscribers;
        _lock = subscriberLock;
      }

      public IDisposable Subscribe(IObserver<PluginDataChangedEventArgs> observer) {
        Action<PluginDataChangedEventArgs> handler = args => observer.OnNext(args);
        lock (_lock) {
          _subscribers.Add(handler);
        }
        return new Unsubscriber(_subscribers, handler, _lock);
      }

      private sealed class Unsubscriber : IDisposable {
        private readonly List<Action<PluginDataChangedEventArgs>> _subscribers;
        private readonly Action<PluginDataChangedEventArgs> _handler;
        private readonly object _lock;

        public Unsubscriber(List<Action<PluginDataChangedEventArgs>> subscribers, Action<PluginDataChangedEventArgs> handler, object subscriberLock) {
          _subscribers = subscribers;
          _handler = handler;
          _lock = subscriberLock;
        }

        public void Dispose() {
          lock (_lock) {
            _subscribers.Remove(_handler);
          }
        }
      }
    }
  }
}
