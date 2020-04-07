using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Reactive;
using System.Reactive.Concurrency;
using System.Reactive.Disposables;
using System.Reactive.Linq;
using System.Reactive.Subjects;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.ETW;
using ATAP.Utilities.Reactive;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;

namespace ATAP.Utilities.HostedServices {

  

  // ToDo: enhance to include other System.FileIO.FielSystemwatcher properties like BufferSize, etc, that could be set by property initialization in the constructor
  public class FileSystemWatcherArg : IFileSystemWatcherArg {
    public FileSystemWatcherArg(string path = "", string filter = "*.*", bool includeSubdirectories = false, NotifyFilters notifyFilter = NotifyFilters.LastWrite | NotifyFilters.FileName | NotifyFilters.DirectoryName) {
      Path = path;
      Filter = filter;
      IncludeSubdirectories = includeSubdirectories;
      NotifyFilter = notifyFilter;
    }

    public string Path { get; }
    public string Filter { get; }
    public bool IncludeSubdirectories { get; }
    public NotifyFilters NotifyFilter { get; }
  }

 

  public class FileSystemWatchersAsObservable : IFileSystemWatchersAsObservable, IDisposable {
    public FileSystemWatchersAsObservable(IEnumerable<IFileSystemWatcherArg> fileSystemWatcherArgs) {
      FileSystemWatcherArgs = fileSystemWatcherArgs ?? new List<FileSystemWatcherArg>() { new FileSystemWatcherArg() };
      // materialize the FileSystemWatcherArg
      IFileSystemWatcherArg[] fileSystemWatcherArgsArray = FileSystemWatcherArgs.ToArray();
      int numFileSystemWatchers = fileSystemWatcherArgsArray.Length;
      individualFileSystemWatchers = new FileSystemWatcher[numFileSystemWatchers];
      int individualFileSystemWatchersIndex = 0;
      IObservable<EventPattern<FileSystemEventArgs>>[] individualObservables = new IObservable<EventPattern<FileSystemEventArgs>>[numFileSystemWatchers];
      foreach (var individualFileSystemWatcherArg in fileSystemWatcherArgsArray) {
        // Supply a default notify filter if not specified, and a default value for includeSubdirecotries
        individualFileSystemWatchers[individualFileSystemWatchersIndex] = new FileSystemWatcher(individualFileSystemWatcherArg.Path, individualFileSystemWatcherArg.Filter) {
          NotifyFilter = individualFileSystemWatcherArg.NotifyFilter,
          IncludeSubdirectories = individualFileSystemWatcherArg.IncludeSubdirectories
        };
        // create each individual Observerable
        IObservable<EventPattern<FileSystemEventArgs>> individualObservable = Observable
                  .FromEventPattern<FileSystemEventHandler,
                  FileSystemEventArgs>(dlgt => individualFileSystemWatchers[individualFileSystemWatchersIndex].Created += dlgt,
                  dlgt => individualFileSystemWatchers[individualFileSystemWatchersIndex].Created -= dlgt);
        individualObservables[individualFileSystemWatchersIndex] = individualObservable;
        individualFileSystemWatchersIndex++;
      }
      // populate the Watcher property with a Merged stream of individual Observable's streams
      Watcher = individualObservables.Merge();
      // Create a single CompositeDisposable which will dispose of each individualObservable
      CompositeDisposable = new CompositeDisposable() {
                 Watcher
                 .Subscribe() };

      //.RateConstrained(TimeSpan.FromSeconds(1)) // complaining it needs a Func returning Task for onNext
      //  //.Subscribe(evt=> Console.WriteLine("{0}:{1}:{2}",evt.EventArgs.Name,evt.EventArgs.ChangeType,evt.EventArgs.FullPath)) // ToDo replace with Func to execute when a sequence element arrives
    }
    public void StartListening() {
      foreach (var fSW in individualFileSystemWatchers) { fSW.EnableRaisingEvents = true; }
    }
    public void StopListening() {
      foreach (var fSW in individualFileSystemWatchers) { fSW.EnableRaisingEvents = false; }
    }

    public IEnumerable<IFileSystemWatcherArg> FileSystemWatcherArgs { get; }
    public IObservable<EventPattern<FileSystemEventArgs>> Watcher { get; }

    // local data for this class
    internal protected FileSystemWatcher[] individualFileSystemWatchers;
    internal protected List<IObservable<EventPattern<FileSystemEventArgs>>> individualObservables { get; }
    internal protected CompositeDisposable CompositeDisposable { get; }

    // Useage
    // FileSystemWatchersAsObservable MyFileSystemWatchersAsObservable = new FileSystemWatchersAsObservable(new fileSystemWatcherArgs(){new FileSystemWatcherArg("."});


    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          //  dispose managed state (managed objects).
          CompositeDisposable.Dispose();
        }

        // TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
        // TODO: set large fields to null.

        disposedValue = true;
      }
    }

    // This code added to correctly implement the disposable pattern.
    void IDisposable.Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
      // TODO: uncomment the following line if the finalizer is overridden above.
      // GC.SuppressFinalize(this);
    }
    #endregion
  }

#if TRACE
  [ETWLogAttribute]
#endif
  // A service that provides a reactive (IObservable) stream (watcher) that aggregates a number of FileSystemWatcher events into an IObservable stream
  class FileSystemWatchersAsObservableKey { int Key { get; set; } }
  public class FileSystemWatchersHostedServiceData : IDisposable, IFileSystemWatchersHostedServiceData {
    // internal storage to track every watcher that has been handed out but not disposed
    internal ConcurrentDictionary<FileSystemWatchersAsObservableKey, FileSystemWatchersAsObservable> watchersDictionary { get; }
    // The number of watchers handed out that have not been disposed
    public int NonDisposedCount { get => watchersDictionary.Count; }
    public FileSystemWatchersHostedServiceData() { watchersDictionary = new ConcurrentDictionary<FileSystemWatchersAsObservableKey, FileSystemWatchersAsObservable>(); }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // Loop over every dictionary entry, disposing of any that are left behind
          foreach (var value in watchersDictionary.Values) { value.CompositeDisposable.Dispose(); }
          GC.SuppressFinalize(this);
        }
        disposedValue = true;
      }
    }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion

  }
#if TRACE
  [ETWLogAttribute]
#endif
  // attribution to https://gist.github.com/RobertDyball/e4bc7b2914d201ad3db9
  public class FileSystemWatchersHostedService : IHostedService, IDisposable, IFileSystemWatchersHostedService {
    #region Common Constructor-injected fields from the GenericHost
    private readonly ILogger<FileSystemWatchersHostedService> logger;
    private readonly IStringLocalizer<ConsoleSourceHostedService> stringLocalizer;
    private readonly IHostEnvironment hostEnvironment;
    private readonly IConfiguration hostConfiguration;
    private readonly IHostLifetime hostLifetime;
    private readonly IHostApplicationLifetime hostApplicationLifetime;
    #endregion
    #region Internal and Linked CancellationTokenSource and Tokens
    private readonly CancellationTokenSource internalCancellationTokenSource = new CancellationTokenSource();
    private CancellationToken internalCancellationToken;
    private CancellationTokenSource linkedCancellationTokenSource;
    #endregion
    public FileSystemWatchersHostedService(
            // This service gets all the default injected services
            ILogger<FileSystemWatchersHostedService> logger,
            // todo: inject localizer
            IHostEnvironment hostEnvironment,
            IConfiguration hostConfiguration,
            IHostLifetime hostLifetime,
            IHostApplicationLifetime hostApplicationLifetime
      // Can the external CTS go here insteaad of in StartAsync?
      ) {
      this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
      this.stringLocalizer = null; // new StringLocalizer<FileSystemWatchersHostedService>();
      this.logger.LogInformation("{@ .ctor}{FileSystemWatchersHostedService} in .ctor");
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      this.logger.LogInformation("{@ .ctor}{FileSystemWatchersHostedService} leaving .ctor");
      // Initialize the Data structure
      fileSystemWatchersHostedServiceData = (IFileSystemWatchersHostedServiceData)new FileSystemWatchersHostedServiceData();
    }

    // public data structure for this service
    public IFileSystemWatchersHostedServiceData fileSystemWatchersHostedServiceData { get; private set; }


    public void Startup() {

      fileSystemWatchersHostedServiceData = new FileSystemWatchersHostedServiceData();
    }



    #region StartAsync and StopAsync methods as promised by IHostedService
    public Task StartAsync(CancellationToken externalCancellationToken) {
      #region CancellationToken creation and linking
      // Combine the cancellation tokens,so that either can stop this HostedService
      internalCancellationToken = internalCancellationTokenSource.Token;
      linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
      var linkedCancellationToken = linkedCancellationTokenSource.Token;
      #endregion
      #region Register actions with the CancellationToken (s)
      externalCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: externalCancellationToken has signalled stopping."));
      internalCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: internalCancellationToken has signalled stopping."));
      linkedCancellationToken.Register(() => logger.LogInformation("ConsoleMonitorBackgroundService: linkedCancellationToken has signalled stopping."));
      #endregion
      #region TBD
      // Register on that cancellationToken an Action that will call TrySetCanceled method on the _delayStart task.
      // This lets the cancellationToken passed into this method signal to the genericHost an overall request for cancellation
      //CancellationToken.Register(() => _delayStart.TrySetCanceled());
      #endregion
      // Register the methods defined in this class with the three CancellationToken properties found on the IHostApplicationLifetime instance passed to this class in it's .ctor
      hostApplicationLifetime.ApplicationStarted.Register(OnStarted);
      hostApplicationLifetime.ApplicationStopping.Register(OnStopping);
      hostApplicationLifetime.ApplicationStopped.Register(OnStopped);
      return Task.CompletedTask;
    }
    // StopAsync issued in both IHostedService and IHostLifetime interfaces
    // This IS called when the user closes the ConsoleWindow with the windows top right pane "x (close)" icon
    // This IS called when the user hits ctrl-C in the console window
    //  After Ctrl-C and after this method exits, the debugger
    //    shows an unhandled exception: System.OperationCanceledException: 'The operation was canceled.'
    // See also discussion of Stop async in the following attributions.
    // Attribution to  https://stackoverflow.com/questions/51044781/graceful-shutdown-with-generic-host-in-net-core-2-1
    // Attribution to https://stackoverflow.com/questions/52915015/how-to-apply-hostoptions-shutdowntimeout-when-configuring-net-core-generic-host for OperationCanceledException notes

    public Task StopAsync(CancellationToken cancellationToken) {
      //InternalCancellationTokenSource.Cancel();
      // Defer completion promise, until our application has reported it is done.
      // return TaskCompletionSource.Task;
      //Stop(); // would call the servicebase stop if this was a generic hosted service ??
      return Task.CompletedTask;
    }
    #endregion

    #region Event Handlers registered with the HostApplicationLifetime events
    // Registered as a handler with the HostApplicationLifetime.ApplicationStarted event
    private void OnStarted() {
      // Post-startup code goes here
    }

    // Registered as a handler with the HostApplicationLifetime.Application event
    // This is NOT called if the ConsoleWindows ends when the connected browser (browser opened by LaunchSettings when starting with debugger) is closed (not applicable to ConsoleLifetime generic hosts
    // This IS called if the user hits ctrl-C in the ConsoleWindow
    private void OnStopping() {
      // On-stopping code goes here
    }

    // Registered as a handler with the HostApplicationLifetime.ApplicationStarted event
    private void OnStopped() {
      // Post-stopped code goes here
    }

    // Called by base.Stop. This may be called multiple times by service Stop, ApplicationStopping, and StopAsync.
    // That's OK because StopApplication uses a CancellationTokenSource and prevents any recursion.
    // This IS called when user hits ctrl-C in ConsoleWindow
    //  This IS NOT called when user closes the startup auto browser
    // ToDo:investigate BrowserLink, and multiple browsers effect on this call
    //protected override void OnStop() {
    //  this.logger.LogInformation("FileSystemWatchersHostedService.OnStop method called.");
    //  HostApplicationLifetime.StopApplication();
    //  base.OnStop();
    //}
    #endregion

    public IFileSystemWatchersAsObservable Create(IEnumerable<IFileSystemWatcherArg> fileSystemWatcherArgs) {
      return new FileSystemWatchersAsObservable(fileSystemWatcherArgs);
    }

      #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls

    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          fileSystemWatchersHostedServiceData.Dispose();
        }
        disposedValue = true;
      }
    }

    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion
  }

}
