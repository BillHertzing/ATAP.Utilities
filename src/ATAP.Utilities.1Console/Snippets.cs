using System;
using System.Collections.Generic;
using System.Linq;

namespace ATAP.Utilities.AConsole01 {

  

  //public class MyServiceA : BackgroundService {
  //  public MyServiceA(ILoggerFactory loggerFactory) {
  //    Logger = loggerFactory.CreateLogger<MyServiceA>();
  //  }

  //  public ILogger Logger { get; }

  //  protected override async Task ExecuteAsync(CancellationToken stoppingToken) {
  //    Logger.LogInformation("MyServiceA is starting.");

  //    stoppingToken.Register(() => Logger.LogInformation("MyServiceA is stopping."));

  //    string inputLineString;
  //    while (!stoppingToken.IsCancellationRequested) {
  //      inputLineString = Console.ReadLine();
  //      Logger.LogInformation("MyServiceA read {0}", inputLineString);

  //      await Task.Delay(TimeSpan.FromSeconds(1), stoppingToken).ConfigureAwait(false);
  //    }

  //    Logger.LogInformation("MyServiceA background task is stopping.");
  //  }
  //}

  //public class MyServiceB : IHostedService, IDisposable {
  //  private bool _stopping;
  //  private Task _backgroundTask;

  //  public MyServiceB(ILoggerFactory loggerFactory) {
  //    Logger = loggerFactory.CreateLogger<MyServiceB>();
  //  }

  //  public ILogger Logger { get; }

  //  public Task StartAsync(CancellationToken cancellationToken) {
  //    Logger.LogInformation("MyServiceB is starting.");
  //    _backgroundTask = BackgroundTask();
  //    return Task.CompletedTask;
  //  }

  //  private async Task BackgroundTask() {
  //    while (!_stopping) {
  //      await Task.Delay(TimeSpan.FromSeconds(1)).ConfigureAwait(false);
  //      Logger.LogInformation("MyServiceB is writing to ConsoleOut.");
  //      Console.WriteLine("MyServiceB is writing to ConsoleOut!");
  //    }

  //    Logger.LogInformation("MyServiceB background task is stopping.");
  //  }

  //  public async Task StopAsync(CancellationToken cancellationToken) {
  //    Logger.LogInformation("MyServiceB is stopping.");
  //    _stopping = true;
  //    if (_backgroundTask != null) {
  //      // TODO: cancellation
  //      await _backgroundTask.ConfigureAwait(false);
  //    }
  //  }

  //  public void Dispose() {
  //    Logger.LogInformation("MyServiceB is disposing.");
  //    GC.SuppressFinalize(this);

  //  }
  //}

  //public class WriteToConsole : IHostedService, IDisposable {
  //  private bool _stopping;
  //  private Task _backgroundTask;

  //  public WriteToConsole(ILoggerFactory loggerFactory) {
  //    Logger = loggerFactory.CreateLogger<WriteToConsole>();
  //  }

  //  public ILogger Logger { get; }

  //  public class Results {
  //    public Results(bool success, Exception? e) {
  //      Success = success;
  //      this.e = e;
  //    }

  //    bool Success { get; set; }
  //    Exception? e { get; set; }
  //  }
  //  public Task StartAsync(CancellationToken cancellationToken) {
  //    Logger.LogInformation("WriteToConsole is starting.");
  //    _backgroundTask = BackgroundTask(cancellationToken);
  //    return Task.CompletedTask;
  //  }


  //  private async Task BackgroundTask(CancellationToken cancellationToken) {
  //    while (!_stopping) {
  //      // wait async for a line(string) to be presented on stdin, continue on any thread
  //      string inputString;

  //      // ToDo: Merge the cancellationToken of the GenericHost with this one

  //      //static async Task<Results> writeToConsoleTaskAsync(string outstr, CancellationToken cancellationToken) {
  //      //  Results ret = new Results(false,null);
  //      //  try {
  //      //    Console.WriteLine(outstr);
  //      //  }
  //      //  catch (IOException e) {
  //      //    // capture the exception and send it back to the consumer
  //      //    ret = new Results(false, e);
  //      //  }
  //      //  return ret;
  //      //}

  //      //try {
  //      //  Func<Task<Results>> run = (outstr, cancellationToken) => { writeToConsoleTaskAsync(outstr, cancellationToken)
  //      //    };
  //      //  Results results = await run.Invoke().ConfigureAwait(false);
  //      //}
  //      //catch (Exception) {
  //      //  // record the exception (trace or log)
  //      //  // rethrow it
  //      //  throw;
  //      //}
  //      //finally {
  //      //  cancellationTokenSource.Dispose();
  //      //}

  //      //Func<string, int, Task<string>> func = waitForStringTaskBuilder;
  //      //Task<string> waitForStringTask = waitForStringTaskBuilder("", 0);

  //      //public static async Task<string> LoadAsync(string message, int count) {
  //      //  await Task.Delay(1500);

  //      //  var countOutput = count == 0 ? string.Empty : count.ToString();
  //      //  var output = $"{message} {countOUtput}Exceuted Successfully !";
  //      //  Console.WriteLine(output);

  //      //  return "Finished";
  //      //}
  //      //Func<string, Task<string>> Builder = new Func<string, Task<string>>(() => { }
  //      //Task<string> waitForStringTask = new Task<string>(async () => {

  //      //});

  //      //try {
  //      //  Func<Task<ConvertFileSystemToGraphResult>> run = () => StaticExtensions.ConvertFileSystemToGraphAsyncTask(rootstring, asyncFileReadBlockSize, convertFileSystemToGraphProgress, null, cancellationToken);
  //      //  convertFileSystemToGraphResult = await run.Invoke().ConfigureAwait(false);
  //      //}
  //      //catch (Exception) {
  //      //  throw;
  //      //}
  //      //finally {
  //      //  cancellationTokenSource.Dispose();
  //      //}

  //      //    Task<string> oldwaitForStringTask = new Task<string>(async () => {
  //      //      string ret;
  //      //      await Task.Delay(TimeSpan.FromSeconds(1));
  //      //      ret = "abc";
  //      //      return ret;
  //      //    });

  //      //    inputString = waitForStringTask.Result;
  //      //    Logger.LogInformation("WriteToConsole is writing {0} to ConsoleOut.", inputString);
  //      //    Console.WriteLine(inputString);
  //      //  }

  //      //  Logger.LogInformation("MyServiceB background task is stopping.");
  //      //}
  //      //Func<string, int, Task<string>> func = LoadAsync;
  //      //Task<string> task = func("", 0); // pass parameters you want

  //      //var result = await task; // later in async method
  //    }
  //  }

  //  public async Task StopAsync(CancellationToken cancellationToken) {
  //    Logger.LogInformation("MyServiceB is stopping.");
  //    _stopping = true;
  //    if (_backgroundTask != null) {
  //      // TODO: cancellation
  //      await _backgroundTask.ConfigureAwait(false);
  //    }
  //  }

  //  public void Dispose() {
  //    Logger.LogInformation("MyServiceB is disposing.");
  //    GC.SuppressFinalize(this);
  //  }
  //}

  // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
  //public void Configure(IApplicationBuilder app, IHostEnvironment hostEnvironment) {

  //  var localHostEnvironment = hostEnvironment;
  //  //app.UseServiceStack(new SSAppHost(hostEnvironment) {
  //  //  AppSettings = new NetCoreAppSettings(Configuration)
  //  //});

  //  //// The supplied lambda becomes the final handler in the HTTP pipeline
  //  //app.Run(async (context) => {
  //  //  Log.Debug("Last HTTP Pipeline handler, cwd = {0}; ContentRootPath = {1}", Directory.GetCurrentDirectory(), HostEnvironment.ContentRootPath);
  //  //  context.Response.StatusCode = 404;
  //  //  await Task.FromResult(0);
  //  //});
  //}
  //}


  //internal class SimpleDelayLoop : IHostedService, IDisposable {
  //  private ILogger<SimpleDelayLoop> Logger { get; }
  //  private CancellationTokenSource CancellationTokenSource { get; } = new CancellationTokenSource();
  //  private TaskCompletionSource<bool> TaskCompletionSource { get; } = new TaskCompletionSource<bool>();
  //  public SimpleDelayLoop(ILogger<SimpleDelayLoop> logger) {
  //    Logger = logger;
  //  }
  //  public Task StartAsync(CancellationToken cancellationToken) {
  //    // Start our application code.
  //    Task.Run(() => DoWorkTask(CancellationTokenSource.Token));
  //    return Task.CompletedTask;
  //  }
  //  public Task StopAsync(CancellationToken cancellationToken) {
  //    CancellationTokenSource.Cancel();
  //    // Defer completion promise, until our application has reported it is done.
  //    return TaskCompletionSource.Task;
  //  }
  //  public async Task DoWorkTask(CancellationToken cancellationToken) {
  //    while (!cancellationToken.IsCancellationRequested) {
  //      Logger.LogInformation("in SimpleDelayLoop: doing DoWorkTask until cancellationToken.IsCancellationRequested");
  //      await Task.Delay(1000).ConfigureAwait(false);
  //    }
  //  }
  //  public void Dispose() {
  //    GC.SuppressFinalize(this);
  //  }

  //}

  //internal class SimpleDelayLoopWithSharedCancellationToken : IHostedService, IDisposable {
  //  private ILogger<SimpleDelayLoopWithSharedCancellationToken> Logger { get; }
  //  private CancellationTokenSource InternalCancellationTokenSource { get; } = new CancellationTokenSource();
  //  private CancellationToken internalCancellationToken;
  //  private TaskCompletionSource<bool> TaskCompletionSource { get; } = new TaskCompletionSource<bool>();
  //  public SimpleDelayLoopWithSharedCancellationToken(ILogger<SimpleDelayLoopWithSharedCancellationToken> logger) {
  //    Logger = logger;
  //  }
  //  public Task StartAsync(CancellationToken cancellationToken) {
  //    // Start our application code.
  //    Task.Run(() => DoWorkTask(InternalCancellationTokenSource.Token));
  //    return Task.CompletedTask;
  //  }
  //  public Task StopAsync(CancellationToken cancellationToken) {
  //    InternalCancellationTokenSource.Cancel();
  //    // Defer completion promise, until our application has reported it is done.
  //    return TaskCompletionSource.Task;
  //  }
  //  public async Task DoWorkTask(CancellationToken externalCancellationToken) {
  //    this.internalCancellationToken = InternalCancellationTokenSource.Token;
  //    using (CancellationTokenSource linkedCts =
  //            CancellationTokenSource.CreateLinkedTokenSource(internalCancellationToken, externalCancellationToken)) {
  //      try {
  //        Logger.LogInformation("in SimpleDelayLoopWithSharedCancellationToken:  DoWorkTask is awaiting DoWorkInternalTask");
  //        await DoWorkInternalTask(linkedCts.Token).ConfigureAwait(false);
  //      }
  //      catch (OperationCanceledException) {
  //        if (internalCancellationToken.IsCancellationRequested) {
  //          Logger.LogInformation("in SimpleDelayLoopWithSharedCancellationToken: InternalCancellationOccurred (originated inside this class) ");
  //        }
  //        else if (externalCancellationToken.IsCancellationRequested) {
  //          Logger.LogInformation("in SimpleDelayLoopWithSharedCancellationToken: ExternalCancellationOcurred (originated outside this class) ");
  //          externalCancellationToken.ThrowIfCancellationRequested();
  //        }
  //      }
  //    }
  //    TaskCompletionSource.SetResult(true);
  //  }

  //  private async Task DoWorkInternalTask(CancellationToken cancellationToken) {

  //    while (!cancellationToken.IsCancellationRequested) {
  //      Logger.LogInformation("in SimpleDelayLoopWithSharedCancellationToken: doing DoWorkInternalTask until cancellationToken.IsCancellationRequested");
  //      await Task.Delay(1000).ConfigureAwait(false);
  //    }
  //    TaskCompletionSource.SetResult(true);
  //  }
  //  public void Dispose() {
  //    GC.SuppressFinalize(this);
  //  }

  //}


  //internal class SimpleConsole : IHostedService, IDisposable {
  //  private ILogger<SimpleConsole> Logger { get; }
  //  private CancellationTokenSource CancellationTokenSource { get; } = new CancellationTokenSource();
  //  private TaskCompletionSource<bool> TaskCompletionSource { get; } = new TaskCompletionSource<bool>();
  //  public SimpleConsole(ILogger<SimpleConsole> logger) {
  //    Logger = logger;
  //  }
  //  public Task StartAsync(CancellationToken cancellationToken) {
  //    // Start our application code.
  //    Task.Run(() => DoSimpleConsoleTask(CancellationTokenSource.Token));
  //    return Task.CompletedTask;
  //  }
  //  public Task StopAsync(CancellationToken cancellationToken) {
  //    CancellationTokenSource.Cancel();
  //    // Defer completion promise, until our application has reported it is done.
  //    return TaskCompletionSource.Task;
  //  }
  //  public async Task DoSimpleConsoleTask(CancellationToken cancellationToken) {
  //    while (!cancellationToken.IsCancellationRequested) {
  //      Logger.LogInformation("in SimpleConsole: doing DoSimpleConsoleTask until cancellationToken.IsCancellationRequested");
  //      var input = Console.ReadLine();
  //      Console.WriteLine(input);
  //    }
  //    TaskCompletionSource.SetResult(true);
  //  }
  //  public void Dispose() {
  //    GC.SuppressFinalize(this);
  //  }
  //}


}

