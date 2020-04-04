using System;
using System.Collections.Generic;
using System.IO;
using System.Reactive;

namespace ATAP.Utilities.HostedServices {
  public interface IFileWatchersHostedServiceData {
    List<IObservable<EventPattern<FileSystemEventArgs>>> FileWatchers { get; }

    void Dispose();
  }
}