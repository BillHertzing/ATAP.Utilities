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
  public static partial class ObservableExtensions { // https://github.com/dotnet/reactive/issues/459
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
    }
    #endregion

    #region RobertDyball/ObservableExtensions.cs https://gist.github.com/RobertDyball/e4bc7b2914d201ad3db9

    /// <summary>
    /// Regulate extension method is from John Rayner, http://sharpfellows.com/post/Rx-Controlling-frequency-of-events.aspx
    /// </summary>
    public static partial class ObservableExtensions {
      public static IObservable<T> Regulate<T>(this IObservable<T> observable, TimeSpan duration) {
        return Regulate(observable, duration, TaskPoolScheduler.Default);
      }

      public static IObservable<T> Regulate<T>(this IObservable<T> observable, TimeSpan duration, IScheduler scheduler) {
        var regulator = new ObservableRegulator<T>(duration, scheduler);

        return Observable.Create<T>(observer => observable.Subscribe(obj => regulator.ProcessItem(obj, observer)));
      }

      private class ObservableRegulator<T> {
        private DateTimeOffset _lastEntry = DateTimeOffset.MinValue;
        private readonly object _lastEntryLock = new object();

        private readonly TimeSpan _duration;
        private readonly IScheduler _scheduler;

        public ObservableRegulator(TimeSpan duration, IScheduler scheduler) {
          _duration = duration;
          _scheduler = scheduler;
        }

        public void ProcessItem(T val, IObserver<T> observer) {
          var canBroadcastNow = false;
          var nexEntryTime = DateTimeOffset.MaxValue;
          lock (_lastEntryLock) {
            var now = DateTimeOffset.Now;
            if (now.Subtract(_lastEntry) > _duration) {
              _lastEntry = now;
              canBroadcastNow = true;
            }
            else {
              _lastEntry = _lastEntry.Add(_duration);
              nexEntryTime = _lastEntry;
            }
          }

          if (canBroadcastNow) {
            observer.OnNext(val);
          }
          else {
            _scheduler.Schedule(nexEntryTime, () => observer.OnNext(val));
          }

        }
      }
    }
  }

  #endregion
 


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


