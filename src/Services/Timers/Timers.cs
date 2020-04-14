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

  [ETWLogAttribute]
  public class ObservableResetableTimer {
    // https://stackoverflow.com/questions/54309176/how-to-extend-the-duration-time-of-observable-timer-in-rx-net

    public TimeSpan duration;
    public Subject<Unit> resetSignal;
    //Scheduler scheduler; figure this out for testing

    public ObservableResetableTimer(TimeSpan duration) : this(duration, new Subject<Unit>()) { } // for testing?, Scheduler.Default)

    public ObservableResetableTimer(TimeSpan duration, Subject<Unit> resetSignal) {//, Scheduler scheduler) {
      this.duration = duration;
      this.resetSignal = resetSignal ?? throw new ArgumentNullException(nameof(resetSignal));
      //this.scheduler = scheduler ?? throw new ArgumentNullException(nameof(scheduler));
      var DoNothing = new Action(() => { });
      resetSignal
        .Select(_ => Observable.Timer(duration))
        .Switch()
        .ObserveOn(Scheduler.Default) // Figure out how topass in a scheduler for testing
        .Subscribe(_ => DoNothing());
    }
  }

#if TRACE
  [ETWLogAttribute]
#endif
  public class ObservableResetableTimersHostedServiceData : IDisposable {
    public ObservableResetableTimer timer;
    public void Dispose() {
      GC.SuppressFinalize(this);
    }

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
    public ObservableResetableTimersHostedServiceData HostedServiceObservableResetableTimersData;

    public void Startup() {
      HostedServiceObservableResetableTimersData = new ObservableResetableTimersHostedServiceData();
      HostedServiceObservableResetableTimersData.timer = new ObservableResetableTimer(new TimeSpan(0, 0, 1));

    }


    // to reset or start a ObservableResetableTimer:
    //HostedServiceObservableResetableTimersData.timer.resetSignal.OnNext(Unit.Default);


    // method to add a ObservableResetableTimer to the collection
    //   if hot start it
    //   if cold just allocate it

    // method to remove a ObservableResetableTimer from the collection


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
    //  this.logger.LogInformation("GenericHostAsServiceLifetimeLynchpin.OnStop method called.");
    //  HostApplicationLifetime.StopApplication();
    //  base.OnStop();
    //}

    // All the other ServiceBase's virtual methods could be overridden here as well, to log them
    #endregion


    // Dispose must dispose of the internalCancellationTokenSource and the linkedCancellationTokenSource
    // Dispose must dispose of all timers in the collection and the linkedCancellationTokenSource
    public void Dispose() {
      GC.SuppressFinalize(this);
    }

  }

}
