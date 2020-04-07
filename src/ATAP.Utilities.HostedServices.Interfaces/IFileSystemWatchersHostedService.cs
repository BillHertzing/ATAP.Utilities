using System;
using System.Collections.Generic;
using System.IO;
using System.Reactive;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.HostedServices {
  // ToDo: enhance to include other System.FileIO.FielSystemwatcher properties like BufferSize, etc, that could be set by property initialization in the constructor
  public interface IFileSystemWatcherArg {
    public string Path { get; }
    public string Filter { get; }
    public bool IncludeSubdirectories { get; }
    System.IO.NotifyFilters NotifyFilter { get; }
  }

  public interface IFileSystemWatchersAsObservable {
    public IEnumerable<IFileSystemWatcherArg> FileSystemWatcherArgs { get; }
    public IObservable<EventPattern<FileSystemEventArgs>> Watcher { get; }
    public void StartListening();
    public void StopListening();
  }

  public interface IFileSystemWatchersHostedService {
    public IFileSystemWatchersAsObservable Create(IEnumerable<IFileSystemWatcherArg> fileSystemWatcherArgs);
    IFileSystemWatchersHostedServiceData fileSystemWatchersHostedServiceData { get; }
  
    void Dispose();
    Task StartAsync(CancellationToken externalCancellationToken);
    void Startup();
    Task StopAsync(CancellationToken cancellationToken);
  }
}
