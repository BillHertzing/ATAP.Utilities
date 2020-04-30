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

namespace ATAP.Utilities.HostedServices.ConsoleSourceHostedService {

#if TRACE
  [ETWLogAttribute]
#endif
  public class ConsoleSourceHostedService : IHostedService, IDisposable, IConsoleSourceHostedService {
    #region Common Constructor-injected Auto-Implemented Properties
    // These properties can only be set in the class constructor.
    // Class constructor for a BackgroundService is called from the GenericHost and the DI-injected services are referenced
    ILoggerFactory loggerFactory { get; }
    ILogger<ConsoleSourceHostedService> logger { get; }
    IStringLocalizerFactory stringLocalizerFactory { get; }
    IHostEnvironment hostEnvironment { get; }
    IConfiguration hostConfiguration { get; }
    IHostLifetime hostLifetime { get; }
    IConfiguration appConfiguration { get; }
    IHostApplicationLifetime hostApplicationLifetime { get; }
    #endregion
    #region Internal and Linked CancellationTokenSource and Tokens
    CancellationTokenSource internalCancellationTokenSource { get; } = new CancellationTokenSource();
    CancellationToken internalCancellationToken { get; }
    // Set in the ExecuteAsync method
    CancellationTokenSource linkedCancellationTokenSource { get; set; }
    // Set in the ExecuteAsync method
    CancellationToken linkedCancellationToken { get; set; }
    #endregion
    public ConsoleSourceHostedService(ILoggerFactory loggerFactory, IStringLocalizerFactory stringLocalizerFactory, IHostEnvironment hostEnvironment,
  IConfiguration hostConfiguration, IHostLifetime hostLifetime, IHostApplicationLifetime hostApplicationLifetime
  // Can the external CTS go here instead of in StartAsync?
  ) {
      this.stringLocalizerFactory = stringLocalizerFactory ?? throw new ArgumentNullException(nameof(stringLocalizerFactory));
      //exceptionLocalizer = stringLocalizerFactory.Create(nameof(Resources), "ATAP.Utilities.ConsoleSourceHostedService");
      //debugLocalizer = stringLocalizerFactory.Create(nameof(Resources), "AService01");
      this.loggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
      this.logger = loggerFactory.CreateLogger<ConsoleSourceHostedService>();
      logger.LogDebug("ConsoleSourceHostedService", ".ctor");
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
      internalCancellationToken = internalCancellationTokenSource.Token;
    }

    #region StartAsync and StopAsync methods as promised by IHostedService
    public Task StartAsync(CancellationToken cancellationToken) {
      #region CancellationToken creation and linking
      // Combine the cancellation tokens,so that either can stop this HostedService
      linkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, cancellationToken);
      linkedCancellationToken = linkedCancellationTokenSource.Token;
      #endregion
      #region Register actions with the CancellationToken (s)
      cancellationToken.Register(() => logger.LogDebug(String.Format("{0} {1} cancellationToken has signalled stopping.", "ConsoleSinkHostedService", "externalCancellationToken")));  //debugLocalizer["{0} {1} externalCancellationToken has signalled stopping."], "ConsoleSinkHostedService", "externalCancellationToken"));
      //externalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} externalCancellationToken has signalled stopping."], "ConsoleSinkHostedService", "externalCancellationToken"));
      //internalCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} internalCancellationToken has signalled stopping."], "ConsoleSinkHostedService", "internalCancellationToken"));
      //linkedCancellationToken.Register(() => logger.LogDebug(debugLocalizer["{0} {1} linkedCancellationToken has signalled stopping."], "ConsoleSinkHostedService", "linkedCancellationToken"));
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
              .FromAsync(() => Console.In.ReadLineAsync()) // This is actually a BLOCKING operation, see ?? for workaround
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
