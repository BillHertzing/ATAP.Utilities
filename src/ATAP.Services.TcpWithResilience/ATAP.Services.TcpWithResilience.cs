using System;
using System.Linq;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Reactive;
using System.Reactive.Concurrency;
using System.Reactive.Linq;
using System.Reactive.Subjects;
using ATAP.Utilities.ETW;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;
using Polly;
/*using ATAP.Utilities.HostedServices.Resilience; */

namespace ATAP.Utilities.HostedServices.TcpWithResilienceHostedService {
    
    public class TcpWithResilience 
    {
        //
        // ToDo: Move into a TCP configuration section
        public static int defaultMaxResponseBufferSize = 1024;
        // ToDo: move into a resilience policy repository
        public static int maxRetryAttempts = 3;
        public static TimeSpan pauseBetweenFailures = TimeSpan.FromSeconds(2); 
        public static Policy retryPolicy = Policy
          .WaitAndRetryAsync(maxRetryAttempts, i => pauseBetweenFailures);

        public static async Task<byte[]> FetchAsync(string host, int port, string tcpRequestMessage, Encoding encoding = default, Policy policy = default, int maxResponseBufferSize = default, CancellationToken cancellationToken = default)
        {
            Encoding _encoding;
            if (encoding == default) {_encoding = new System.Text.UTF8Encoding();} else {_encoding = encoding;}
            Policy _policy;
            if (policy == default) {_policy = retryPolicy;} else {_policy = policy;}
            int _maxResponseBufferSize;
            if (maxResponseBufferSize == default) {_maxResponseBufferSize = defaultMaxResponseBufferSize;} else {_maxResponseBufferSize = maxResponseBufferSize;}
            CancellationToken _cancellationToken ;
            if (cancellationToken == default) {_cancellationToken = CancellationToken.None;} else {_cancellationToken = cancellationToken;}
            return await policy.FetchAsync(async() =>
            {
                // let every exception in this method bubble up
                // assume the tcpRequestMessage encoding supports converting to a byte array 
                // ToDo: add try catch to ensure the encoding passed will support conversion to a byte-array
                var data = _encoding.GetBytes(tcpRequestMessage);
                // ToDo: Add try/catch for the exception that gets thrown if there is no listener on this host/port combination
                var socket = new TcpClient(host, port);
                var stream = socket.GetStream();
                // write the request async 
                // ToDo: exception handling, and possibly a resilience policy?  
                await stream.WriteAsync(data, 0, data.Length, _cancellationToken);
                // The write has returned at this point, and no exception, so go and await to read the response.
                byte[] rawReadBuffer = new byte[_maxResponseBufferSize];
                // read the response async  
                int numBytesRead = await stream.ReadAsync(rawReadBuffer, 0, _maxResponseBufferSize, _cancellationToken);
                // ToDo: figure out how to read responses that are larger than maxResponseBufferSize, or at least indicate to the calling program that there may be more data remaining
                byte[] responseBuffer = new byte[numBytesRead];
                // return just the number of bytes read from the stream
                Buffer.BlockCopy(rawReadBuffer, 0, responseBuffer, 0, numBytesRead);
                return responseBuffer;
            });
        }
    }
    
#if TRACE
  [ETWLogAttribute]
#endif
  public class TcpWithResilienceHostedServiceData : IDisposable {
    public TcpWithResilience TcpWithResilience;
    public void Dispose() {
      GC.SuppressFinalize(this);
    }

  }
#if TRACE
  [ETWLogAttribute]
#endif
  public class TcpWithResilienceHostedService : IHostedService, IDisposable, ITcpWithResilienceHostedService {
    #region Common Constructor-injected fields
    private readonly ILogger<TcpWithResilienceHostedService> logger;
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
    public TcpWithResilienceHostedService(
            // This service gets all the default injected services
            ILogger<TcpWithResilienceHostedService> logger,
            // todo: inject localizer
            IHostEnvironment hostEnvironment,
            IConfiguration hostConfiguration,
            IHostLifetime hostLifetime,
            IHostApplicationLifetime hostApplicationLifetime
      // Can the external CTS go here instead of in StartAsync?
      ) {
      this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
      this.stringLocalizer = null; // new StringLocalizer<TcpWithResilienceHostedService>();
      this.hostEnvironment = hostEnvironment ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostApplicationLifetime = hostApplicationLifetime ?? throw new ArgumentNullException(nameof(hostApplicationLifetime));
      this.hostLifetime = hostLifetime ?? throw new ArgumentNullException(nameof(hostEnvironment));
      this.hostConfiguration = hostConfiguration ?? throw new ArgumentNullException(nameof(hostConfiguration));
    }

    // public data structure for this service
    // a collection of TCP connection points
    public TcpWithResilienceHostedServiceData HostedServiceTCPWithResilienceData;

    public void Startup() {
      //HostedServiceTCPWithResilienceData = new TcpWithResilienceHostedServiceData();
      //HostedServiceTCPWithResilienceData.timer = new ObservableResetableTimer(new TimeSpan(0, 0, 1));

    }


    // method to add a Tcp connection to the collection
    //   if hot start it
    //   if cold just allocate it

    // method to remove a Tcp connection from the collection


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
