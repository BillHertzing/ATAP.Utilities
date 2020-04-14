using System;
using System.Collections.Generic;
using System.IO;
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
  public class ConsoleSourceHostedService : IHostedService, IDisposable, IConsoleSourceHostedService {
    #region Common Constructor-injected fields from the GenericHost
    private readonly ILogger<ConsoleSourceHostedService> logger;
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
    public ConsoleSourceHostedService(
            // This service gets all the default injected services
            ILogger<ConsoleSourceHostedService> logger,
            // todo: inject localizer
            IHostEnvironment hostEnvironment,
            IConfiguration hostConfiguration,
            IHostLifetime hostLifetime,
            IHostApplicationLifetime hostApplicationLifetime
      // Can the external CTS go here instead of in StartAsync?
      ) {
      this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
      this.stringLocalizer = null; // new StringLocalizer<ConsoleSourceHostedService>();
      this.logger.LogInformation("{@ .ctor}{ConsoleSourceHostedService} in .ctor");
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
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
      externalCancellationToken.Register(() => logger.LogInformation("GenerateProgramBackgroundService: externalCancellationToken has signalled stopping."));
      internalCancellationToken.Register(() => logger.LogInformation("GenerateProgramBackgroundService: internalCancellationToken has signalled stopping."));
      linkedCancellationToken.Register(() => logger.LogInformation("GenerateProgramBackgroundService: linkedCancellationToken has signalled stopping."));
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
    //  HostApplicationLifetime.StopApplication();
    //  base.OnStop();
    //}
    #endregion

    public IObservable<string> ConsoleReadLineAsyncAsObservable() {
      return
          Observable
              .FromAsync(() => Console.In.ReadLineAsync())
              .Repeat()
              .Publish()
              .RefCount()
              .SubscribeOn(Scheduler.Default);
    }


    // ToDo: Figure this out, the below is not right yet
    // Useage
    // IDisposable ConsoleReadLineAsyncAsObservableDisposableHandle = ConsoleReadLineAsyncAsObservable().TakeMany(
    //  inputString => Action<string> ((inputString) => {DoSomething(inputstring);})).Subscribe(
    //  () => ConsoleReadLineAsyncAsObservableDisposableHandle.Dispose());
    //   c => Console.WriteLine(c.ToString()),
    //() => end.Dispose());

    public void Dispose() {
      GC.SuppressFinalize(this);
    }

  }

}
