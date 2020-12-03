using System;
using System.Reactive.Concurrency;
using System.Reactive.Linq;
using System.Threading.Tasks;
using ATAP.Utilities.ETW;


namespace ATAP.Utilities.Reactive {
#if TRACE
  [ETWLogAttribute]
#endif
  #region helper methods for async observers // https://github.com/dotnet/reactive/issues/459
  public static partial class Extensions { // https://github.com/dotnet/reactive/issues/459
    public static IDisposable SubscribeAsync<T>(this IObservable<T> source, Func<T, Task> onNextAsync) =>
        source
            .Select(number => Observable.FromAsync(() => onNextAsync(number)))
            .Concat()
            .Subscribe();

    public static IDisposable SubscribeAsyncConcurrent<T>(this IObservable<T> source, Func<T, Task> onNextAsync) =>
        source
            .Select(number => Observable.FromAsync(() => onNextAsync(number)))
            .Merge()
            .Subscribe();

    public static IDisposable SubscribeAsyncConcurrent<T>(this IObservable<T> source, Func<T, Task> onNextAsync, int maxConcurrent) =>
        source
            .Select(number => Observable.FromAsync(() => onNextAsync(number)))
            .Merge(maxConcurrent)
            .Subscribe();

    #endregion
    #region Constraining a stream of events in Rx to a maximum rate (http://www.zerobugbuild.com/?p=323)
      public static IDisposable RateConstrained<T>(this IObservable<T> source, Func<T, Task> onNextAsync, TimeSpan interval) =>
      source
        .Select(i => Observable.Empty<T>()
        .Delay(interval)
        .StartWith(i))
        .Concat()
        .Subscribe();
    #endregion
    #region FileWatcher

    #endregion
  }

}

  /* this implementation waiting on QueueBackgroundWorkItem  to be implemented in Dot Net Core 3.x
  #region Scoped Service for Background task
  internal interface IScopedProcessingService {
    Task DoWork(CancellationToken stoppingToken);
  }

  internal class ScopedProcessingService : IScopedProcessingService {
    private int executionCount = 0;
    private readonly ILogger _logger;

    public ScopedProcessingService(ILogger<ScopedProcessingService> logger) {
      _logger = logger;
    }

    public async Task DoWork(CancellationToken stoppingToken) {
      while (!stoppingToken.IsCancellationRequested) {
        executionCount++;

        _logger.LogInformation(
            "Scoped Processing Service is working. Count: {Count}", executionCount);

        await Task.Delay(10000, stoppingToken);
      }
    }
  }

  public class ConsumeScopedServiceHostedService : BackgroundService {
    private readonly ILogger<ConsumeScopedServiceHostedService> _logger;

    public ConsumeScopedServiceHostedService(IServiceProvider services,
        ILogger<ConsumeScopedServiceHostedService> logger) {
      Services = services;
      _logger = logger;
    }

    public IServiceProvider Services { get; }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken) {
      _logger.LogInformation(
          "Consume Scoped Service Hosted Service running.");

      await DoWork(stoppingToken);
    }

    private async Task DoWork(CancellationToken stoppingToken) {
      _logger.LogInformation(
          "Consume Scoped Service Hosted Service is working.");

      using (var scope = Services.CreateScope()) {
        var scopedProcessingService =
            scope.ServiceProvider
                .GetRequiredService<IScopedProcessingService>();

        await scopedProcessingService.DoWork(stoppingToken);
      }
    }

    public override async Task StopAsync(CancellationToken stoppingToken) {
      _logger.LogInformation(
          "Consume Scoped Service Hosted Service is stopping.");

      await Task.CompletedTask;
    }

    public class QueuedHostedService : BackgroundService {
      private readonly ILogger<QueuedHostedService> _logger;

      public QueuedHostedService(IBackgroundTaskQueue taskQueue,
          ILogger<QueuedHostedService> logger) {
        TaskQueue = taskQueue;
        _logger = logger;
      }

      public IBackgroundTaskQueue TaskQueue { get; }

      protected override async Task ExecuteAsync(CancellationToken stoppingToken) {
        _logger.LogInformation(
            $"Queued Hosted Service is running.{Environment.NewLine}" +
            $"{Environment.NewLine}Tap W to add a work item to the " +
            $"background queue.{Environment.NewLine}");

        await BackgroundProcessing(stoppingToken);
      }

      private async Task BackgroundProcessing(CancellationToken stoppingToken) {
        while (!stoppingToken.IsCancellationRequested) {
          var workItem =
              await TaskQueue.DequeueAsync(stoppingToken);

          try {
            await workItem(stoppingToken);
          }
          catch (Exception ex) {
            _logger.LogError(ex,
                "Error occurred executing {WorkItem}.", nameof(workItem));
          }
        }
      }

      public override async Task StopAsync(CancellationToken stoppingToken) {
        _logger.LogInformation("Queued Hosted Service is stopping.");

        await base.StopAsync(stoppingToken);
      }
    }
  }


  public class MonitorLoop {
    private readonly IBackgroundTaskQueue _taskQueue;
    private readonly ILogger _logger;
    private readonly CancellationToken _cancellationToken;

    public MonitorLoop(IBackgroundTaskQueue taskQueue,
        ILogger<MonitorLoop> logger,
        IHostApplicationLifetime applicationLifetime) {
      _taskQueue = taskQueue;
      _logger = logger;
      _cancellationToken = applicationLifetime.ApplicationStopping;
    }

    public void StartMonitorLoop() {
      _logger.LogInformation("Monitor Loop is starting.");

      // Run a console user input loop in a background thread
      Task.Run(() => Monitor());
    }

    public void Monitor() {
      while (!_cancellationToken.IsCancellationRequested) {
        var keyStroke = Console.ReadKey();

        if (keyStroke.Key == ConsoleKey.W) {
          // Enqueue a background work item
          _taskQueue.QueueBackgroundWorkItem(async token =>
          {
            // Simulate three 5-second tasks to complete
            // for each enqueued work item

            int delayLoop = 0;
            var guid = Guid.NewGuid().ToString();

            _logger.LogInformation(
                "Queued Background Task {Guid} is starting.", guid);

            while (!token.IsCancellationRequested && delayLoop < 3) {
              try {
                await Task.Delay(TimeSpan.FromSeconds(5), token);
              }
              catch (OperationCanceledException) {
                // Prevent throwing if the Delay is cancelled
              }

              delayLoop++;

              _logger.LogInformation(
                  "Queued Background Task {Guid} is running. " +
                  "{DelayLoop}/3", guid, delayLoop);
            }

            if (delayLoop == 3) {
              _logger.LogInformation(
                  "Queued Background Task {Guid} is complete.", guid);
            }
            else {
              _logger.LogInformation(
                  "Queued Background Task {Guid} was cancelled.", guid);
            }
          });
        }
      }
    }
  }

  /*
  // The services are registered in IHostBuilder.ConfigureServices(Program.cs). The hosted service is registered with the AddHostedService extension method:
  services.AddSingleton<MonitorLoop>();
  services.AddHostedService<QueuedHostedService>();
  services.AddSingleton<IBackgroundTaskQueue, BackgroundTaskQueue>();

  // MontiorLoop is started in Program.Main:
  var monitorLoop = host.Services.GetRequiredService<MonitorLoop>();
  monitorLoop.StartMonitorLoop();
  #endregion Scoped Service for Background task
  */


