using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

using System.Reflection;
using System.Resources;
using System.Threading;

using System.Threading.Tasks;
using ATAP.Console.Console01.Properties;
using ATAP.Utilities.ComputerInventory.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Software;
//using ATAP.Utilities.ETW;
//using ATAP.Utilities.LongRunningTasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;
using Serilog;
//Required for Serilog.SelfLog
using Serilog.Debugging;
//  using the .Dump static method inside of Log.Debug
using ServiceStack.Text;


namespace ATAP.Console.Console01.Complicated {

  
 

  //    // Validate the value of SupportedKindsOfHostBuilders from the genericHostConfigurationRoot is one that is supported by this program
  //    SupportedKindsOfHostBuilders kindOfHostBuilderToBuild;
  //    var kindOfHostBuilderToBuildString = genericHostConfigurationRoot.GetValue<string>(StringConstants.KindOfHostBuilderToBuildConfigRootKey, StringConstants.KindOfHostBuilderToBuildStringDefault);
  //    if (!Enum.TryParse<SupportedKindsOfHostBuilders>(kindOfHostBuilderToBuildString, out kindOfHostBuilderToBuild)) {
  //      throw new InvalidDataException(String.Format(exceptionResourceManager.GetString("InvalidKindOfHostBuilderToBuildString"), kindOfHostBuilderToBuildString));
  //    }

  //    // If the value of kindOfHostBuilderToBuild is one that needs subsequent lower-level HostBuilders,
  //    // then validate the value of the lower-level HostBuildersToBuild from the genericHostConfigurationRoot is one that is supported by this program
  //    switch (kindOfHostBuilderToBuild) {
  //      case SupportedKindsOfHostBuilders.ConsoleHostBuilder:
  //        // ToDo: expand this if there ever come into existence different kinds of ConsoleHosts
  //        break;
  //      case SupportedKindsOfHostBuilders.WebHostBuilder:
  //        var webHostBuilderName = genericHostConfigurationRoot.GetValue<string>(StringConstants.WebHostBuilderToBuildConfigRootKey, StringConstants.WebHostBuilderToBuildStringDefault);
  //        SupportedWebHostBuilders webHostBuilderToBuild;
  //        if (!Enum.TryParse<SupportedWebHostBuilders>(webHostBuilderName, out webHostBuilderToBuild)) {
  //          throw new InvalidDataException(String.Format(exceptionResourceManager.GetString("InvalidWebHostBuilderToBuildString"), webHostBuilderName));
  //        }
  //        Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("WebHostBuilderToBuild"), webHostBuilderToBuild));
  //        // The webHostBuilderName string parsed into an enumeration, make sure it is a supported value
  //        switch (webHostBuilderToBuild) {
  //          case SupportedWebHostBuilders.IntegratedIISInProcessWebHostBuilder:
  //            break;
  //          case SupportedWebHostBuilders.KestrelAloneWebHostBuilder:
  //            break;
  //          default:
  //            throw new NotSupportedException(String.Format(exceptionResourceManager.GetString("UnsupportedWebHostBuilderToBuild"), webHostBuilderToBuild));
  //        }
  //        break;
  //      default:
  //        // The kindOfHostBuilderToBuildName string parsed into an enumeration, but it is not a supported value
  //        throw new NotSupportedException(String.Format(exceptionResourceManager.GetString("UnsupportedKindOfHostBuilderToBuild"), kindOfHostBuilderToBuild));
  //    }

  //    // Validate the value of GenericHostLifetime from the genericHostConfigurationRoot is one that is supported by this program
  //    SupportedGenericHostLifetimes genericHostLifetime;
  //    var genericHostLifetimeString = genericHostConfigurationRoot.GetValue<string>(StringConstants.GenericHostLifetimeConfigRootKey, StringConstants.GenericHostLifetimeStringDefault);
  //    if (!Enum.TryParse<SupportedGenericHostLifetimes>(genericHostLifetimeString, out genericHostLifetime)) {
  //      throw new InvalidDataException(String.Format(exceptionResourceManager.GetString("InvalidGenericHostLifetimeString"), genericHostLifetimeString));
  //    }
  //    if (!(genericHostLifetime == SupportedGenericHostLifetimes.ConsoleLifetime || genericHostLifetime == SupportedGenericHostLifetimes.ServiceLifetime)) {
  //      // The supportedGenericHostLifetimes string parsed into an enumeration, but it is not a supported value
  //      throw new NotSupportedException(String.Format(exceptionResourceManager.GetString("UnsupportedGenericHostLifetime"), genericHostLifetime));
  //    }

  //    // During Development and Debugging, a genericHost usually runs as a ConsoleHost.
  //    // In Development standalone and in Production a genericHost can run as a ConsoleHost, a WebHost, a Service running a Console Host, or a Service running a WebHost.
  //    // A GenericHost, when running as a Service, can be a Windows Service or a Linux *nix daemon
  //    // Before creating the GenericHostBuilder, we need to know the lifetime of this specific GenericHost
  //    // The lifetime is a ConsoleHost if any of the followiing three conditions re met:
  //    //  if a debugger is attached at this point in the program's execution
  //    //  if command line args contains --console or -console or -c
  //    //  if the ConfigurationRoot for the GenericHost specifies a ConsoleAppLifetime
  //    //  we added a switchMappings to the CommandlineArgs configuration provider so the genericHost's ConfigurationRoot provides information for two of those conditions
  //    var consoleHostFromCommandLineBool = genericHostConfigurationRoot.GetValue<string>(StringConstants.ConsoleAppConfigRootKey) != null;
  //    // combine all three conditions
  //    bool isConsoleHost = Debugger.IsAttached || (genericHostLifetime == SupportedGenericHostLifetimes.ConsoleLifetime) || consoleHostFromCommandLineBool;
  //    //  A class that encapsulates information about the kind of HostedApp and the OS
  //    RuntimeKind runtimeKind = new RuntimeKind(isConsoleHost);
  //    // ToDo: Need to expand runtTimeKind into its string representation. Will need a serializer selected in order to do this
  //    Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("RunTimeKindDetails"), runtimeKind));

  //    // Attach the appropriate ServiceLifetime structures to the GenericHostBuilder, build the host, and run it async
  //    if (!runtimeKind.IsConsoleApplication) {
  //      // This program is a GenericHost configured to run as a service
  //      // insert a singleton implementation of IHostLifetime into the genericHost's DI container, and any options needed by the IHostLifetime instance
  //      /*
  //      Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("AddingAnIHostLifetimeToGenericHostDI"), typeof(GenericHostAsServiceILifetimeImplementation)));
  //      genericHostBuilder.ConfigureServices((hostContext, servicesGenericHostBuilder) => {
  //        servicesGenericHostBuilder.AddSingleton<IHostLifetime, GenericHostAsServiceILifetimeImplementation>();
  //        // add Host options here if needed
  //        // Extend the generic host timeout to thecvalue specified in the configuration, in seconds, to give all running process time to do a graceful shutdown
  //        // Ensure that the string value specified in the ConfigurationRoot can be converted to a double
  //        String shutDownTimeoutInSecondsString = genericHostConfigurationRoot.GetValue<string>(StringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownConfigKey, StringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownStringDefault);
  //        Double shutDownTimeoutInSecondsDouble;
  //        if (!Double.TryParse(shutDownTimeoutInSecondsString, out shutDownTimeoutInSecondsDouble)) {
  //          // ToDo: convert to resource
  //          throw new InvalidCastException(String.Format(StringConstants.CannotConvertShutDownTimeoutInSecondsToDoubleExceptionMessage, shutDownTimeoutInSecondsString));
  //        }
  //        servicesGenericHostBuilder.AddOptions<HostOptions>().Configure(opts => opts.ShutdownTimeout = TimeSpan.FromSeconds(shutDownTimeoutInSecondsDouble));
  //      });
  //      // Build generic host as a service/daemon
  //      // Attribution to https://www.stevejgordon.co.uk/running-net-core-generic-host-applications-as-a-windows-service
  //      // Attribution to https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/windows-service?view=aspnetcore-3.0
  //      Log.Debug("in Program.Main: create genericHost by calling .Build() on the genericHostBuilder");
  //      var genericHost = genericHostBuilder.Build();
  //      //Log.Debug("in Program.Main: genericHost.Dump() = {@genericHost}", genericHost);

  //      // Start the generic host
  //      //Log.Debug("in Program.Main: webHost created, starting RunAsync and awaiting it");
  //      // Attribution to https://stackoverflow.com/questions/52915015/how-to-apply-hostoptions-shutdowntimeout-when-configuring-net-core-generic-host for OperationCanceledException notes
  //      // ToDo: further investigation to ensure OperationCanceledException should be ignored in all cases (service or console host, kestrel or IntegratedIISInProcessWebHost)
  //      try {
  //        // Note that RunAsync method only exists on a genericHost instance having a DI container instance that resolves a IHostLifetime
  //        await genericHost.RunAsync(genericHostCancellationToken);
  //      }
  //      catch (OperationCanceledException e) {
  //        ; // Just ignore OperationCanceledException to suppress  it from bubbling upwards if the main program was cancelledOperationCanceledException
  //          // The Exception should be shown in the ETW trace
  //          //ToDo: Add Error level or category to ATAPUtilitiesETWProvider, and make OperationCanceled one of the catagories
  //          // Specificly log the 
  //          //ATAPUtilitiesETWProvider.Log.Information($"Exception in Program.Main: {e.Exception.GetType()}: {e.Exception.Message}");
  //      } // Other kinds of exceptions bubble up to the facility that started this main program

  //      // The IHostLifetime instance methods take over now
  //      // Log Program finishing to ETW if it happens to resume execution here for some reason(as of 06/2019, ILWeaving this assembly results in a thrown invalid CLI Program Exception
  //      // ATAP.Utilities.ETW.ATAPUtilitiesETWProvider.Log("> Program.Main");

  //*/
  //    }
  //    else {
  //      // This program is GenericHost configured to run as a ConsoleApp
  //      Log.Debug("{DebugMessage}", string.Format(debugResourceManager.GetString("AddingConsoleLifetimeTogenericHostBuilder")));
  //      // Define the services this Console application will provide
  //      // Add them to the genericHostBuilder
  //      // ConsoleLifetime implements IHostLifetime. IHostLifetime is responsible for controlling when the application shuts down
  //      genericHostBuilder.ConfigureServices((context, collection) => collection.AddSingleton<IHostLifetime, ConsoleLifetime>());
  //      //genericHostBuilder.ConfigureServices((context, collection) => collection.AddSingleton<SimpleConsole>());
  //      // Build the genericHost
  //      var genericHost = genericHostBuilder.Build();
  //      //Log.Debug("in Program.Main: genericHost.Dump() = {@genericHost}", genericHost);

  //      // call the 
  //      genericHost.Run();
  //      // Calling UseConsoleLifetime builds the host and runs it
  //      //genericHostBuilder.UseConsoleLifetime();

  //    }

  //    // Override
  //  }
  //}
  ////#if TRACE
  ////  [ETWLogAttribute]
  ////#endif
  //public class Startup {
  //  public IConfiguration Configuration { get; }

  //  public IHostEnvironment HostEnvironment { get; }

  //  public Startup(IConfiguration configuration, IHostEnvironment hostEnvironment) {
  //    Configuration = configuration;
  //    HostEnvironment = hostEnvironment;
  //  }

  //  // This method gets called by the runtime. Use this method to add servicesGenericHostBuilder to the container.
  //  public void ConfigureServices(IServiceCollection services) {
  //  }

  //  //      .ConfigureServices((hostContext, servicesGenericHostBuilder) =>
  //  //{
  //  //      servicesGenericHostBuilder.AddHostedService<LifetimeEventsHostedService>();
  //  //      servicesGenericHostBuilder.AddHostedService<TimedHostedService>();
  //  //    })


  //  // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
  //  //public void Configure(IApplicationBuilder app, IHostEnvironment hostEnvironment) {

  //  //  var localHostEnvironment = hostEnvironment;
  //  //  //app.UseServiceStack(new SSAppHost(hostEnvironment) {
  //  //  //  AppSettings = new NetCoreAppSettings(Configuration)
  //  //  //});

  //  //  //// The supplied lambda becomes the final handler in the HTTP pipeline
  //  //  //app.Run(async (context) => {
  //  //  //  Log.Debug("Last HTTP Pipeline handler, cwd = {0}; ContentRootPath = {1}", Directory.GetCurrentDirectory(), HostEnvironment.ContentRootPath);
  //  //  //  context.Response.StatusCode = 404;
  //  //  //  await Task.FromResult(0);
  //  //  //});
  //  //}
  //}

 
}
