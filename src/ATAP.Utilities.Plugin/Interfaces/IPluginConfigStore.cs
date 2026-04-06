using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// Abstraction over a key-value configuration store for plugin settings.
  /// Replaces the Ace-era Redis ICacheClient dependency with a pluggable interface.
  /// Default implementation: InMemoryPluginConfigStore (ConcurrentDictionary with optional JSON persistence).
  /// </summary>
  public interface IPluginConfigStore {
    /// <summary>Retrieves a typed value by key, or default if not found.</summary>
    Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default);

    /// <summary>Sets a typed value by key.</summary>
    Task SetAsync<T>(string key, T value, CancellationToken cancellationToken = default);

    /// <summary>Returns all keys matching the given prefix.</summary>
    Task<IEnumerable<string>> GetKeysAsync(string prefix, CancellationToken cancellationToken = default);

    /// <summary>Removes a key from the store.</summary>
    Task RemoveAsync(string key, CancellationToken cancellationToken = default);
  }
}
