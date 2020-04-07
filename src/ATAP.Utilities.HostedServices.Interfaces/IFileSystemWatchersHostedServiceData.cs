namespace ATAP.Utilities.HostedServices {
  public interface IFileSystemWatchersHostedServiceData {
    int NonDisposedCount { get; }

    void Dispose();
  }
}