using System;
using System.Collections.Generic;
using System.Reactive;
using System.Reactive.Concurrency;
using System.Reactive.Linq;
using System.Reactive.Subjects;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

using ATAP.Utilities.ETW;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;

namespace ATAP.Utilities.HostedServices {

#if TRACE
  [ETWLogAttribute]
#endif
  public class ObservableResetableTimer {
    // https://stackoverflow.com/questions/54309176/how-to-extend-the-Duration-time-of-observable-timer-in-rx-net

    public TimeSpan Duration { get; set; }
    public Subject<Unit> ResetSignal { get; set; }
    public List<Action> ActionList { get; set; }
    IScheduler MyScheduler { get; set; }

    public ObservableResetableTimer(TimeSpan duration, IScheduler scheduler = null) : this(duration, new Subject<Unit>(), new List<Action>() { new Action(() => { }) }, scheduler) { }
    public ObservableResetableTimer(TimeSpan duration, Action DoSomething, IScheduler scheduler = null) : this(duration, new Subject<Unit>(), new List<Action>() { DoSomething }, scheduler) { }
    public ObservableResetableTimer(TimeSpan duration, Subject<Unit> resetSignal, Action DoSomething, IScheduler scheduler = null) : this(duration, resetSignal, new List<Action>() { DoSomething }, scheduler) { }
    public ObservableResetableTimer(TimeSpan duration, Subject<Unit> resetSignal, List<Action> ThingsToDo, IScheduler scheduler = null) {
      Duration = duration;
      ResetSignal = resetSignal ?? throw new ArgumentNullException(nameof(resetSignal));
      ActionList = ThingsToDo;
      MyScheduler = scheduler ?? Scheduler.Default;
      ResetSignal
        .Select(_ => Observable.Timer(duration))
        .Switch()
        .ObserveOn(MyScheduler);
      foreach (var somethingToDo in ThingsToDo) {
        ResetSignal.Subscribe(_ => somethingToDo());
      }
    }
  }

#if TRACE
  [ETWLogAttribute]
#endif
  public class ObservableResetableTimersHostedServiceData : IDisposable {
    //public ObservableResetableTimer timer { get; set; }
    public Dictionary<string, ObservableResetableTimer> TimerDisposeHandles { get; set; }
    public ObservableResetableTimersHostedServiceData() : this(new Dictionary<string, ObservableResetableTimer>()) { }
    public ObservableResetableTimersHostedServiceData(Dictionary<string, ObservableResetableTimer> timerDisposeHandles) {
      TimerDisposeHandles = timerDisposeHandles ?? throw new ArgumentNullException(nameof(timerDisposeHandles));
    }

    // to reset or start a ObservableResetableTimer:
    //HostedServiceObservableResetableTimersData.TimerDisposeHandles[key].ResetSignal.OnNext(Unit.Default);


    // methods to add a ObservableResetableTimer to the collection
    public void AddTimer(string key, bool hot, TimeSpan duration,  Action somethingToDo, IScheduler scheduler = null) {
      AddTimer(key, hot, duration, new Subject<Unit>(), new List<Action>() { somethingToDo }, Scheduler.Default);
    }
    public void AddTimer(string key, bool hot, TimeSpan duration, Subject<Unit> resetSignal, Action somethingToDo, IScheduler scheduler = null) {
      AddTimer(key, hot, duration, resetSignal, new List<Action>() { somethingToDo }, Scheduler.Default);
    }

    public void AddTimer(string key, bool hot, TimeSpan duration, Subject<Unit> resetSignal, List<Action> thingsToDo, IScheduler scheduler = null) {
      TimerDisposeHandles[key] = new ObservableResetableTimer(duration, resetSignal, thingsToDo, scheduler);
      //   if cold just allocate it but don't start it,  if hot, start it,
      if (hot) { TimerDisposeHandles[key].ResetSignal.OnNext(Unit.Default); }
    }

    // method to remove a ObservableResetableTimer from the collection



    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls
    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          // dispose of the TimerDisposeHandle collection
          //GetEnumerator
          foreach (var timerName in TimerDisposeHandles.Keys) {
            TimerDisposeHandles.Remove(timerName);
          }
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
  public class ObservableResetableTimersHostedService : IHostedService, IDisposable, IObservableResetableTimersHostedService {
    #region Common Constructor-injected fields
    private readonly ILogger<ObservableResetableTimersHostedService> logger;
    private readonly IConfiguration hostConfiguration;
    private readonly IStringLocalizer stringLocalizer;
    private readonly IHostEnvironment hostEnvironment;
    private readonly IHostApplicationLifetime hostApplicationLifetime;
    private readonly IHostLifetime hostLifetime;
    #endregion
    #region cancellationtokens
    private CancellationToken externalCancellationToken;
    private CancellationTokenSource internalCancellationTokenSource = new CancellationTokenSource();
    private CancellationToken internalCancellationToken;
    private CancellationToken linkedCancellationToken;
    private CancellationTokenSource linkedCancellationTokenSource;
    #endregion
    public ObservableResetableTimersHostedService(
            // This service gets all the default injected services
            ILogger<ObservableResetableTimersHostedService> logger,
            // todo: inject localizer
            IHostEnvironment hostEnvironment,
            IConfiguration hostConfiguration,
            IHostLifetime hostLifetime,
            IHostApplicationLifetime hostApplicationLifetime
      // Can the external CTS go here instead of in StartAsync?
      ) {
      this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
      this.stringLocalizer = null; // new StringLocalizer<ObservableResetableTimersHostedService>();
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
    }

    // public data structure for this service
    // collection of timers
    public ObservableResetableTimersHostedServiceData HostedServiceObservableResetableTimersData { get; set; }

    public void Startup() {
      HostedServiceObservableResetableTimersData = new();
      //HostedServiceObservableResetableTimersData.timer = new ObservableResetableTimer(new TimeSpan(0, 0, 1));
      HostedServiceObservableResetableTimersData.TimerDisposeHandles = new();
    }

    #region StartAsync and StopAsync methods as promised by IHostedService
    public Task StartAsync(CancellationToken externalCancellationToken) {
      // Store away the externalCancellationToken passed as an argument, create an internal token, and combine them
      this.externalCancellationToken = externalCancellationToken;
      this.internalCancellationToken = internalCancellationTokenSource.Token;
      linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken);
      #region TBD LinkedCancellation
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

    public Task StopAsync(CancellationToken externalCancellationToken) {
      //Stop(); // would call the servicebase stop if this was a generic hosted service ??
      return Task.CompletedTask;
    }
    #endregion

    #region Event Handlers registered with the HostApplicationLifetime events
    // Registered as a handler with the HostApplicationLifetime.ApplicationStarted event
    private void OnStarted() {
      // Post-startup code goes here
    }

    // Registered as a handler with the HostApplicationLifetime.ApplicationStopping event
    // This is NOT called if the ConsoleWindows ends when the connected browser (browser opened by LaunchSettings when starting with debugger) is closed (not applicable to ConsoleLifetime generic hosts
    // This IS called if the user hits ctrl-C in the ConsoleWindow
    private void OnStopping() {
      // On-stopping code goes here
    }

    // Registered as a handler with the HostApplicationLifetime.ApplicationStopped event
    private void OnStopped() {
      // Post-stopped code goes here
    }

    // Called by base.Stop. This may be called multiple times by service Stop, ApplicationStopping, and StopAsync.
    // That's OK because StopApplication uses a CancellationTokenSource and prevents any recursion.
    // This IS called when user hits ctrl-C in ConsoleWindow
    //  This IS NOT called when user closes the startup auto browser
    // ToDo:investigate BrowserLink, and multiple browsers effect on this call
    //  this.logger.LogInformation("GenericHostAsServiceLifetimeLynchpin.OnStop method called.");
    //  HostApplicationLifetime.StopApplication();
    //  base.OnStop();
    //}

    // All the other ServiceBase's virtual methods could be overridden here as well, to log them
    #endregion


    // Dispose must dispose of the internalCancellationTokenSource and the linkedCancellationTokenSource
    // Dispose must dispose of all timers in the collection and the linkedCancellationTokenSource
    public void Dispose() {
      // ToDo: dispose of the internalCancellationTokenSource and the linkedCancellationTokenSource
      GC.SuppressFinalize(this);
    }

  }

}
