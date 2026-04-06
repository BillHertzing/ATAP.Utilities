using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// In-memory implementation of IPluginConfigStore backed by ConcurrentDictionary.
  /// Replaces the Ace-era Redis ICacheClient with a zero-dependency default.
  /// Optionally persists to a JSON file on dispose.
  /// </summary>
  public class InMemoryPluginConfigStore : IPluginConfigStore, IDisposable {
    private readonly ConcurrentDictionary<string, string> _store = new();
    private readonly string? _persistencePath;
    private bool _disposed;

    /// <summary>
    /// Creates a volatile in-memory config store.
    /// </summary>
    public InMemoryPluginConfigStore() { }

    /// <summary>
    /// Creates an in-memory config store that persists to a JSON file on dispose.
    /// </summary>
    /// <param name="persistencePath">File path for JSON persistence.</param>
    public InMemoryPluginConfigStore(string persistencePath) {
      _persistencePath = persistencePath;
      if (System.IO.File.Exists(persistencePath)) {
        var json = System.IO.File.ReadAllText(persistencePath);
        var data = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
        if (data is not null) {
          foreach (var kvp in data) {
            _store[kvp.Key] = kvp.Value;
          }
        }
      }
    }

    public Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default) {
      if (_store.TryGetValue(key, out var json)) {
        return Task.FromResult(JsonSerializer.Deserialize<T>(json));
      }
      return Task.FromResult(default(T));
    }

    public Task SetAsync<T>(string key, T value, CancellationToken cancellationToken = default) {
      _store[key] = JsonSerializer.Serialize(value);
      return Task.CompletedTask;
    }

    public Task<IEnumerable<string>> GetKeysAsync(string prefix, CancellationToken cancellationToken = default) {
      var keys = _store.Keys.Where(k => k.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
      return Task.FromResult(keys);
    }

    public Task RemoveAsync(string key, CancellationToken cancellationToken = default) {
      _store.TryRemove(key, out _);
      return Task.CompletedTask;
    }

    public void Dispose() {
      if (!_disposed && _persistencePath is not null) {
        var json = JsonSerializer.Serialize(_store.ToDictionary(k => k.Key, v => v.Value));
        System.IO.File.WriteAllText(_persistencePath, json);
        _disposed = true;
      }
    }
  }
}
