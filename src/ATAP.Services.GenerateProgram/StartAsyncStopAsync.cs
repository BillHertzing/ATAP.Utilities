using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;

namespace ATAP.Services.GenerateCode {
  public partial class GenerateProgramHostedService : IHostedService, IDisposable, IGenerateProgramHostedService {
    #region StartAsync and StopAsync methods as promised by IHostedService when IHostLifetime is ConsoleLifetime  // ToDo:, see if this is called by service and serviced
    /// <summary>
    /// Called to start the service.
    /// </summary>
    /// <param name="genericHostsCancellationToken"></param> Used to signal FROM the GenericHost TO this IHostedService a request for cancelllation
    /// <returns></returns>
    public async Task StartAsync(CancellationToken externalCancellationToken) {

      #region create linkedCancellationSource and token
      // Combine the cancellation tokens,so that either can stop this HostedService
      LinkedCancellationTokenSource = CancellationTokenSource.CreateLinkedTokenSource(InternalCancellationToken, externalCancellationToken);

      #endregion
      #region Register actions with the CancellationToken (s)
      externalCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer["{0} {1} externalCancellationToken has signalled stopping."], "GenerateProgramHostedService", "externalCancellationToken"));
      InternalCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer["{0} {1} InternalCancellationToken has signalled stopping."], "GenerateProgramHostedService", "InternalCancellationToken"));
      LinkedCancellationToken.Register(() => Logger.LogDebug(DebugLocalizer["{0} {1} LinkedCancellationToken has signalled stopping."], "GenerateProgramHostedService", "LinkedCancellationToken"));
      #endregion
      #region register local event handlers with the IHostApplicationLifetime's events
      // Register the methods defined in this class with the three CancellationToken properties found on the IHostApplicationLifetime instance passed to this class in it's .ctor
      HostApplicationLifetime.ApplicationStarted.Register(OnStarted);
      HostApplicationLifetime.ApplicationStopping.Register(OnStopping);
      HostApplicationLifetime.ApplicationStopped.Register(OnStopped);
      #endregion
      // Wait to be connected to the stdIn observable
      //return Task.CompletedTask;
    }

    // StopAsync issued in both IHostedService and IHostLifetime interfaces
    // This IS called when the user closes the ConsoleWindow with the windows top right pane "x (close)" icon
    // This IS called when the user hits ctrl-C in the console window
    //  After Ctrl-C and after this method exits, the debugger
    //    shows an unhandled exception: System.OperationCanceledException: 'The operation was canceled.'
    // See also discussion of Stop async in the following attributions.
    // Attribution to  https://stackoverflow.com/questions/51044781/graceful-shutdown-with-generic-host-in-net-core-2-1
    // Attribution to https://stackoverflow.com/questions/52915015/how-to-apply-hostoptions-shutdowntimeout-when-configuring-net-core-generic-host for OperationCanceledException notes

    public async Task StopAsync(CancellationToken cancellationToken) {
      //Logger.LogDebug(DebugLocalizer["{0} {1}  StopAsync ."], "GenerateProgramHostedService", "StopAsync");
      //InternalCancellationTokenSource.Cancel();
      // Defer completion promise, until our application has reported it is done.
      // return TaskCompletionSource.Task;
      //Stop(); // would call the servicebase stop if this was a generic hosted service ??
      //return Task.CompletedTask;
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

  }
}
