
# Intersting Links to study and incorporate

## Coding Information for the Common Language Runtime (CLR)

[What Every CLR Developer Must Know Before Writing Code](https://github.com/dotnet/coreclr/blob/master/Documentation/coding-guidelines/clr-code-guide.md) Old but a must-read for understanding safe coding practices in managed code

## Icons

[Icons for everything](https://thenounproject.com/)
[File Icons](https://github.com/madskristensen/FileIcons) a bunch of free file icons for many types of files

## ASP NET Core Generic Host

[generic-host-builder-in-asp-net-core](https://wakeupandcode.com/generic-host-builder-in-asp-net-core/)

https://github.com/aspnet/AspNetCore.Docs/blob/master/aspnetcore/fundamentals/host/generic-host/samples/2.x/GenericHostSample/Program.cs

[Running async tasks on app startup in ASP.NET Core 3.0](https://andrewlock.net/running-async-tasks-on-app-startup-in-asp-net-core-3/) Good stuff on running a hostedservice's startasync method to perform stuff before the webserver (including SS)starts handling requests

[Task asynchronous programming model](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/async/task-asynchronous-programming-model) Top-level doc from Microsoft

[Process asynchronous tasks as they complete (C#)](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/async/start-multiple-async-tasks-and-process-them-as-they-complete)

[Understanding Control Flow with Async and Await in C#](https://www.pluralsight.com/guides/understand-control-flow-async-await)

### Issues in Generic Host builder
IsDev environment   https://github.com/aspnet/AspNetCore/issues/4150

## Console Application in a Generic Host

https://garywoodfine.com/ihost-net-core-console-applications/

## Hosting Environment in a Generic Host

https://docs.microsoft.com/en-us/aspnet/core/fundamentals/environments?view=aspnetcore-3.0

https://docs.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.hosting.ihostingenvironment.environmentname?view=aspnetcore-2.2

https://aspnetcore.readthedocs.io/en/stable/fundamentals/hosting.html (2.x, pertaining to IWebHosts)
https://jmezach.github.io/2017/10/29/having-fun-with-the-.net-core-generic-host/ (2.x, old info about CreateDefaultBuilder for WebHost)

## Configuration in a Generic Host

https://docs.microsoft.com/en-us/aspnet/core/fundamentals/configuration/?view=aspnetcore-3.0

https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/generic-host?view=aspnetcore-3.0&WT.mc_id=-blog-scottha#configurehostconfiguration

https://davidpine.net/blog/asp-net-core-configuration/ (binding to classes)

## Environment-specific Configuration in a Generic Host

https://stackoverflow.com/questions/46364293/automatically-set-appsettings-json-for-dev-and-release-environments-in-asp-net-c

https://www.c-sharpcorner.com/article/net-core-load-environment-specific-custom-config-file/

[FileConfigurationExtensions.SetFileLoadExceptionHandler(IConfigurationBuilder, Action<FileLoadExceptionContext>) Method](https://docs.microsoft.com/en-us/dotnet/api/microsoft.extensions.configuration.fileconfigurationextensions.setfileloadexceptionhandler?view=dotnet-plat-ext-3.1&viewFallbackFrom=netstandard-2.1#Microsoft_Extensions_Configuration_FileConfigurationExtensions_SetFileLoadExceptionHandler_Microsoft_Extensions_Configuration_IConfigurationBuilder_System_Action_Microsoft_Extensions_Configuration_FileLoadExceptionContext__) How to handle problems loading and external configuration file

## Dependency Injection in a Generic Host

[Understanding How Assemblies Load in C# .NET](https://michaelscodingspot.com/assemblies-load-in-dotnet/) Good overview article
[How to resolve .NET reference and NuGet package version conflicts](https://michaelscodingspot.com/how-to-resolve-net-reference-and-nuget-package-version-conflicts/)
[Dynamically Loading Assemblies for Dependency Injection in .Net Core](http://codebuckets.com/2020/05/29/dynamically-loading-assemblies-for-dependency-injection-in-net-core/)
[How to load assemblies located in a folder in .net core console app](https://stackoverflow.com/questions/37895278/how-to-load-assemblies-located-in-a-folder-in-net-core-console-app)

### Ninject

[Dependency Injection Using Ninject in .NET](https://www.c-sharpcorner.com/UploadFile/4d9083/dependency-injection-using-ninject-in-net/) Net 4.x tool but works with core
[How to Refactor for Dependency Injection, Part 6: Binding by Convention](https://visualstudiomagazine.com/articles/2014/10/01/binding-by-convention.aspx) dynaic assembly loading and di BINDING

## Assembly binding and loading

[.Net Framework NuGet Packages - Solving Assembly Redirection From Package vs Assembly Versioning, Dependency Resolution, and Strong-Naming](
https://www.softwaremeadows.com/posts/net_framework_nuget_packages_-_versioning__dependency_resolution__and/)

## Web Server Hosting Models

Good Pictures of the three models(https://stackoverflow.com/questions/53688154/host-restapi-inside-iis) https://stackoverflow.com/questions/53688154/host-restapi-inside-iis

## Hosting a Web Server in a GenericHost under Windows Service Sample/Program

https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/windows-service?view=aspnetcore-3.0

## Specifying the IP or Host that ASP.Net Core ListensOn

https://josephwoodward.co.uk/2017/02/many-different-ways-specifying-host-port-asp-net-core

## Validation of Configuration objects-comparer-to-compare-complex-objects

https://andrewlock.net/adding-validation-to-strongly-typed-configuration-objects-in-asp-net-core/

## Using Options pattern with configuration

https://stackoverflow.com/questions/39231951/how-do-i-access-configuration-in-any-class-in-asp-net-core (see comments)

## Data Protection and security in configuration

https://docs.microsoft.com/en-us/aspnet/core/security/data-protection/introduction?view=aspnetcore-2.1

# Security

[ASP.NET CORE UNIT TESTING FOR SECURITY ATTRIBUTES](https://davidpine.net/blog/asp-net-core-security-unit-testing/ )
[OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/index.html) Large project with many ways to address a lot of security flaws and problems

## Logging

### General logging guidelines

[Java Best Practices for Smarter Application Logging & Exception Handling](https://stackify.com/java-logging-best-practices/) https://stackify.com/java-logging-best-practices/

[30 best practices for logging at scale](https://www.loggly.com/blog/30-best-practices-logging-scale/) https://www.loggly.com/blog/30-best-practices-logging-scale/

[How to Log a Log: Application Logging Best Practices](https://logz.io/blog/logging-best-practices/) https://logz.io/blog/logging-best-practices/

[Tips on Logging Microservices](https://logz.io/blog/logging-microservices/) (See Also Commercial LogZ package below)

[.NET Logging Tools and Libraries, The definitive directory and guide to .NET logging tools, frameworks and article](http://www.dotnetlogging.com/)

### Logging in ASP.Net Core

[Logging in ASP.NET Core](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/logging/?view=aspnetcore-3.0)

https://wakeupandcode.com/logging-in-asp-net-core/

[ASP.NET Core Logging Tutorial – What Still Works and What Changed?] (https://stackify.com/asp-net-core-logging-what-changed/)

[Using ETW tracing on Windows 10 IoT Core] (https://gunnarpeipman.com/iot/iot-etw-trace/) https://gunnarpeipman.com/iot/iot-etw-trace/ Interesting hacks for IoT and the ETW tools

[Logging with ILogger in .NET: Recommendations and best practices] (https://blog.rsuter.com/logging-with-ilogger-recommendations-and-best-practices/) Good stuff here
[How to create a LoggerFactory with a ConsoleLoggerProvider?(https://stackoverflow.com/questions/53690820/how-to-create-a-loggerfactory-with-a-consoleloggerprovider] one good point about LoggerFactory.Create
[How to unit test with ILogger in ASP.NET Core](https://stackoverflow.com/questions/43424095/how-to-unit-test-with-ilogger-in-asp-net-core) Unit testing Core methods that use an ILogger, how to moq or fake around it. Also discussion of NullLogger

### Windows ETW Event Logging facility

https://docs.microsoft.com/en-us/windows/desktop/ETW/event-tracing-portal

[Event Tracing for Windows: Reducing Everest to Pike's Peak](https://www.codeproject.com/Articles/1190759/Event-Tracing-for-Windows-Reducing-Everest-to-Pike)

https://www.fireeye.com/blog/threat-research/2019/03/silketw-because-free-telemetry-is-free.html (FireEye's silkETW tool for ETW data)

https://github.com/fireeye/SilkETW (FireEye's silkETW tool for ETW data)

[Reporting Metrics Using .Net (Core) EventSource and EventCounter](https://dev.to/expecho/reporting-metrics-using-net-core-eventsource-and-eventcounter-23dn)

[In-process CLR event listeners with .NET Core 2.2](https://medium.com/criteo-labs/c-in-process-clr-event-listeners-with-net-core-2-2-ef4075c14e87)

[Grab ETW Session, Providers and Events](http://labs.criteo.com/2018/07/grab-etw-session-providers-and-events/)

### Linux Event Logging Facility (tracing and big files)

https://lttng.org/

### Windows EventLog Logging

[Event Logging in a .NET Web Service](http://aspalliance.com/987_Event_Logging_in_a_NET_Web_Service.all) http://aspalliance.com/987_Event_Logging_in_a_NET_Web_Service.all (very old, installutil is "new", manual registry edits)

#### Security implications and permissions for writing to the Windows EventLog
[Event Logging in a .NET Web Service](http://aspalliance.com/987_Event_Logging_in_a_NET_Web_Service.all) http://aspalliance.com/987_Event_Logging_in_a_NET_Web_Service.all (Tags: Installer, )

### TraceLogging in Windows 10
[How to: Use TraceSource and Filters with Trace Listeners](https://docs.microsoft.com/en-us/dotnet/framework/debug-trace-profile/how-to-use-tracesource-and-filters-with-trace-listeners) https://docs.microsoft.com/en-us/dotnet/framework/debug-trace-profile/how-to-use-tracesource-and-filters-with-trace-listeners  Older, Good about net Framework V2.0

[What is the correct usage of TraceSource across a solution?](https://stackoverflow.com/questions/42681972/what-is-the-correct-usage-of-tracesource-across-a-solution) https://stackoverflow.com/questions/42681972/what-is-the-correct-usage-of-tracesource-across-a-solution Older, very simple, but shows what's needed for non-default configuration. Configuration in <system.diagnostics> section, not <logging>

[Simple and Easy Tracing in .NET](https://blog.stephencleary.com/2010/12/simple-and-easy-tracing-in-net.html) https://blog.stephencleary.com/2010/12/simple-and-easy-tracing-in-net.html older, references getting TraceLogging from other .Net builtin libraries, e.g.  System.Net.Sockets

### Diagnsotics Logging
https://andrewlock.net/logging-using-diagnosticsource-in-asp-net-core/

[Using and extending System.Diagnostics trace logging](https://github.com/sgryphon/essential-diagnostics) https://github.com/sgryphon/essential-diagnostics (2 years old)

## TraceEvent (ETW)

[The TraceEvent Library Programmers Guide(https://github.com/Microsoft/dotnet-samples/blob/master/Microsoft.Diagnostics.Tracing/TraceEvent/docs/TraceEvent.md) https://github.com/Microsoft/dotnet-samples/blob/master/Microsoft.Diagnostics.Tracing/TraceEvent/docs/TraceEvent.md (goof Quickstart)
## Windows software trace preprocessor (WPP)
[WPP Software Tracing](https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/wpp-software-tracing) https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/wpp-software-tracing tracing specifically for debugging code during development

[Tampering with Windows Event Tracing: Background, Offense, and Defense](https://medium.com/palantir/tampering-with-windows-event-tracing-background-offense-and-defense-4be7ac62ac63) https://medium.com/palantir/tampering-with-windows-event-tracing-background-offense-and-defense-4be7ac62ac63

[In-process CLR event listeners with .NET Core 2.2](https://medium.com/criteo-labs/c-in-process-clr-event-listeners-with-net-core-2-2-ef4075c14e87) https://medium.com/criteo-labs/c-in-process-clr-event-listeners-with-net-core-2-2-ef4075c14e87

[Monitoring and Observability in the .NET Runtime](https://mattwarren.org/2018/08/21/Monitoring-and-Observability-in-the-.NET-Runtime/) https://mattwarren.org/2018/08/21/Monitoring-and-Observability-in-the-.NET-Runtime/ good cross platform overview great list of follow on articles

[.NET Cross-Plat Performance and Eventing Design](
https://github.com/dotnet/coreclr/blob/master/Documentation/coding-guidelines/cross-platform-performance-and-eventing.md) https://github.com/dotnet/coreclr/blob/master/Documentation/coding-guidelines/cross-platform-performance-and-eventing.md

[TraceLogging](https://docs.microsoft.com/en-us/windows/desktop/tracelogging/trace-logging-portal) https://docs.microsoft.com/en-us/windows/desktop/tracelogging/trace-logging-portal - New Windows 10 tracing framework extends ETW

[.NET Tracelogging Examples](https://docs.microsoft.com/en-us/windows/desktop/tracelogging/tracelogging-net-examples)  used in first testing/

[TraceLogging Managed Quick Start](https://docs.microsoft.com/en-us/windows/desktop/tracelogging/tracelogging-managed-quick-start) https://docs.microsoft.com/en-us/windows/desktop/tracelogging/tracelogging-managed-quick-start

[Record and View TraceLogging Events](https://docs.microsoft.com/en-us/windows/desktop/tracelogging/tracelogging-record-and-display-tracelogging-events) https://docs.microsoft.com/en-us/windows/desktop/tracelogging/tracelogging-record-and-display-tracelogging-events  Windows Performance Recorder (WPR)

[How to Download and Install Windows Performance Toolkit in Windows 10] (https://www.tenforums.com/tutorials/117625-download-install-windows-performance-toolkit-windows-10-a.html) https://www.tenforums.com/tutorials/117625-download-install-windows-performance-toolkit-windows-10-a.html - WPA tool for viewing ETL files

[What's New in the Windows Performance Toolkit](https://docs.microsoft.com/en-us/windows-hardware/test/wpt/whats-new-in-the-windows-performance-toolkit)  2017 article, explains WPA

[Windows Performance Toolkit Technical Reference](https://docs.microsoft.com/en-us/windows-hardware/test/wpt/windows-performance-toolkit-technical-reference)

[Windows Performance Analyzer](https://docs.microsoft.com/en-us/windows-hardware/test/wpt/windows-performance-analyzer)  How to use the Traceloogin data collected by a WPR

[Download and install the Windows ADK](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install) Windows ADK has both teh WPR and WPF tools

[Windows 10 ADK versions and download links](https://www.prajwaldesai.com/windows-10-adk-versions/) download reference for the windows ADK

[Event Tracing](https://docs.microsoft.com/en-us/windows/desktop/ETW/event-tracing-portal) highest level overview

[Windows Event Log](https://docs.microsoft.com/en-us/windows/desktop/WES/windows-event-log) Good Overview

[CoreClr Event Logging Design](https://github.com/dotnet/coreclr/blob/master/Documentation/coding-guidelines/EventLogging.md) Short and very high-level

[Writing an Instrumentation Manifest](https://docs.microsoft.com/en-us/windows/desktop/WES/writing-an-instrumentation-manifest)

[coreclr/src/vm/ClrEtwAll.man](https://github.com/dotnet/coreclr/blob/master/src/vm/ClrEtwAll.man) A full list of all ETW events define for the CLR

[Microsoft.Diagnostics.EventFlow](https://github.com/Azure/diagnostics-eventflow) The EventFlow library suite allows applications to define what diagnostics data to collect,

[System.Diagnostics.Tracing Namespace](https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.tracing)

[ET4W](https://github.com/ohadschn/ET4W/blob/master/README.md#et4w) ET4W is a T4 Text Template code generator for C# ETW (Event Tracing for Windows) classes.

[EventSource User’s Guide](https://github.com/microsoft/dotnet-samples/blob/master/Microsoft.Diagnostics.Tracing/EventSource/docs/EventSource.md#eventsource-users-guide)

[Event Tracing for Windows](https://www.magicsplat.com/book/event_tracing.html)  targeted towards TCL language-understanding-intelligent-service-luis/

[Proposal: Expand supported Caller Info Attributes #87](https://github.com/dotnet/csharplang/issues/87) https://github.com/dotnet/csharplang/issues/87 c# language issue to expand the CallerInfo class to include a property with the full type name. If implemented, will make tracing easier to log the fully qualified method name, instead of just the method name, with no type info.

[A Look at ETW – Part 3](https://aroundtuitblog.wordpress.com/2014/11/03/a-look-at-etw-part-3/) ETW tracing using AOP and requires PostSharp for AOP processing

[Visualize EventSource events as markers](https://docs.microsoft.com/en-us/visualstudio/profiling/visualizing-eventsource-events-as-markers?view=vs-2019) a debugging tool eventually

# Extending Logging for Method Entry and Exit

[Logging Method Entry and Exit Points Dynamically](https://www.codeproject.com/Articles/859035/Logging-Method-Entry-and-Exit-Points-Dynamically) about extending a MLE ILogger, same idea may be good for WPP

## SQL Server Logging

[Integrated Logging with the Integration Services Package Log Providers](https://www.mssqltips.com/sqlservertip/4070/integrated-logging-with-the-integration-services-package-log-providers/) 2015, Logging to a SQL  Server table, both SQL Server details, and also from an external C# method using the DTS.Log method)

## High performance logging

[High-performance logging with LoggerMessage in ASP.NET Core](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/logging/loggermessage?view=aspnetcore-3.1) built-in for windows net cacheable delegates for logging, in place of LogDebug

### Specific Logging Frameworks and commercial tools

#### LogZ.io

[Machine data analytics built on ELK and Grafana] (https://logz.io/product/) https://logz.io/product/

[LogZ Community Edition](https://logz.io/pricing/) https://logz.io/pricing/

[The Complete Guide to the ELK Stack] (https://logz.io/learn/complete-guide-elk-stack/#intro) https://logz.io/learn/complete-guide-elk-stack/#intro

#### Stackify

[Stackify Retrace] (https://stackify.com/why-stackify/) https://stackify.com/why-stackify/ Log File hosting and analysis

#### Serilog

[Serilog Tutorial for .NET Logging: 16 Best Practices and Tips](https://stackify.com/serilog-tutorial-net-logging/)

#### NLog

[Structured Logging with NLog 4.5](https://blog.datalust.co/nlog-4-5-structured-logging/) https://blog.datalust.co/nlog-4-5-structured-logging/

### Log Viewing and analysis

Stackify Prefix[] (https://stackify.com/prefix/) https://stackify.com/prefix/

[visuallogparser](https://archive.codeplex.com/?p=visuallogparser) https://archive.codeplex.com/?p=visuallogparser = older, free tool to query (SQL query) across log file(s) or other log source

[SEQ](https://datalust.co/seq) https://datalust.co/seq  centralizing, searching, and alerting on structured application logs.

[NLog configuration for SEQ](https://docs.datalust.co/docs/using-nlog) https://docs.datalust.co/docs/using-nlog Configuring NLog to write to SEQ

# Home of all the microsoft .Extension classes

[.NET Extensions](https://github.com/dotnet/extensions) .NET Extensions is an open-source, cross-platform set of APIs for commonly used programming patterns and utilities, such as dependency injection, logging, and app configuration. This the OSS source code for all this stuff owned by Microsoft

[Z.ExtensionMethods/cheat-sheet/cheat-sheet.pdf](https://github.com/zzzprojects/Z.ExtensionMethods/blob/master/cheat-sheet/cheat-sheet.pdf) opensource community for extensions

## Cross-platform debugging

[Debugging .NET Core on Linux with LLDB](https://www.raydbg.com/2018/Debugging-Net-Core-on-Linux-with-LLDB/)

## Net Core Generic Host App as a Windows Console Service

[Get started with .NET Generic Host](https://snede.net/get-started-with-net-generic-host/) Good overview of program startup
[USING HOSTBUILDER AND THE GENERIC HOST IN .NET CORE MICROSERVICES](https://www.stevejgordon.co.uk/using-generic-host-in-dotnet-core-console-based-microservices) 2018 and 2.11 but nice on overview
[Generic Host Builder in ASP .NET Core 3.1](https://wakeupandcode.com/generic-host-builder-in-asp-net-core-3-1/) Explanation of Functional Style in BUilder, and great snippets for

## Hosting a web server in a Generic Host

https://docs.microsoft.com/en-us/aspnet/core/fundamentals/host/web-host?view=aspnetcore-3.0

## Configuring a web server in a Generic Host

[Host ASP.NET Core on Windows with IIS](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/iis/?view=aspnetcore-3.0)

## Implementing a ServiceLifetime Interface in a Generic Host that is hosting a Web Server

[Graceful shutdown with Generic Host in .NET Core 2.1] (https://stackoverflow.com/questions/51044781/graceful-shutdown-with-generic-host-in-net-core-2-1)

## CancellationTokens

[Recommended patterns for CancellationToken](https://devblogs.microsoft.com/premier-developer/recommended-patterns-for-cancellationtoken/)

[Cancellation in Managed Threads](https://docs.microsoft.com/en-us/dotnet/standard/threading/cancellation-in-managed-threads)

[How to: Cancel a Task and Its Children](https://docs.microsoft.com/en-us/dotnet/standard/parallel-programming/how-to-cancel-a-task-and-its-children)

[cancel-asynchronous-operation-in-csharp](https://johnthiriet.com/cancel-asynchronous-operation-in-csharp/#)

https://stackoverflow.com/questions/18760252/timeout-an-async-method-implemented-with-taskcompletionsource

https://stackoverflow.com/questions/25985416/how-can-i-set-a-timeout-for-an-async-function-that-doesnt-accept-a-cancellation/25987969#25987969

## NET Core Generic Host App as a Windows Service

https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/windows-service?view=aspnetcore-3.0

https://www.stevejgordon.co.uk/running-net-core-generic-host-applications-as-a-windows-service

https://dejanstojanovic.net/aspnet/2015/november/debugging-windows-service-application-with-console-in-c/

[NetCore 2.1 Generic Host as a service](https://stackoverflow.com/questions/50848141/netcore-2-1-generic-host-as-a-service)

## NET Core Generic Host App as a Windows Service and Linux daemon

https://dejanstojanovic.net/aspnet/2018/june/clean-service-stop-on-linux-with-net-core-21/

https://dejanstojanovic.net/aspnet/2018/august/creating-windows-service-and-linux-daemon-with-the-same-code-base-in-net/

https://dejanstojanovic.net/aspnet/2018/may/the-fastest-way-to-setup-net-core-2-on-debian-or-ubuntu-linux-distro/

## ASP Net Core HTTP Response Generation tips

https://www.strathweb.com/2019/03/elegant-way-of-producing-http-responses-in-asp-net-core-outside-of-mvc-controllers/

## Handling Exceptions during request processing

https://docs.microsoft.com/en-us/aspnet/core/fundamentals/error-handling?view=aspnetcore-2.2#developer-exception-page

## Git and GitHub tricks and tips

https://www.hanselman.com/blog/CarriageReturnsAndLineFeedsWillUltimatelyBiteYouSomeGitTips.aspx

## ASP Net Core 2.1

https://docs.microsoft.com/en-us/aspnet/core/migration/20_21?view=aspnetcore-2.2

https://www.hanselman.com/blog/ASPNETCoreArchitectDavidFowlersHiddenGemsIn21.aspx

## HTTPS and Self-Signed Certs in development

https://www.hanselman.com/blog/DevelopingLocallyWithASPNETCoreUnderHTTPSSSLAndSelfSignedCerts.aspx

https://www.hanselman.com/blog/SecuringAnAzureAppServiceWebsiteUnderSSLInMinutesWithLetsEncrypt.aspx

https://docs.microsoft.com/en-us/aspnet/core/security/enforcing-ssl?view=aspnetcore-3.0

## Blazor-Specific tips

### Route Navigation in Blazor

https://learn-blazor.com/pages/router/

https://visualstudiomagazine.com/articles/2019/02/01/navigating-in-blazor.aspx

[Routing in ASP.NET Core](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/routing?view=aspnetcore-3.0) https://docs.microsoft.com/en-us/aspnet/core/fundamentals/routing?view=aspnetcore-3.0

[Routing in ASP.NET Core](https://medium.com/quick-code/routing-in-asp-net-core-c433bff3f1a4) https://medium.com/quick-code/routing-in-asp-net-core-c433bff3f1a4

## Visual Studio Tips

https://efficientuser.com/2017/07/06/browser-link-option-in-visual-studio/

https://marketplace.visualstudio.com/items?itemName=MadsKristensen.BrowserReloadonSave

https://marketplace.visualstudio.com/items?itemName=MadsKristensen.WebEssentials2019

## AppVeyor

https://www.appveyor.com/docs/build-configuration/#time-limitations

https://www.appveyor.com/docs/deployment/environment/

https://www.appveyor.com/docs/deployment/azure-cloud-service/

## Cross-Platform Development tips

https://www.brianketelsen.com/my-cross-platform-dev-setup-on-surface-laptop/


## Scripts written in C#
https://www.strathweb.com/2017/11/c-script-runner-for-net-core-2-0/

https://www.strathweb.com/2018/04/dotnet-script-now-available-as-net-core-sdk-2-1-global-tool/

https://github.com/filipw/dotnet-script

## DotNet Core downloads pages/router/https://dotnet.microsoft.com/download/dotnet-core/3.0

## C# 3rd party libraries
[All C# Extension Methods](https://www.extensionmethod.net/csharp) Huge library of c# extensions projects

## c# libraries for object comparison

https://dzone.com/articles/using-objects-comparer-to-compare-complex-objects

## Andriod Native:
https://blogs.msdn.microsoft.com/vsappcenter/guest-blog-fixing-disasters-asap-with-instant-updates/

https://visualstudio.microsoft.com/app-center/faq/

# C\# Language Tips and tricks

##async operations
[writelineasync-with-cancellation](https://stackoverflow.com/questions/35395275/writelineasync-with-cancellation) sample code for cancelling async write, but says it can't be done, yet, offers workaround

## Lambda expressions
C# 6.0 cookbook

[Why can I use a lambda expression in place of a callback delegate?](https://stackoverflow.com/questions/4487454/why-can-i-use-a-lambda-expression-in-place-of-a-callback-delegate)

## LINQ

https://www.codingame.com/playgrounds/213/using-c-linq---a-practical-overview/combined-exercise-1

[how-to-await-a-list-of-tasks-asynchronously-using-linq](https://stackoverflow.com/questions/21868087/how-to-await-a-list-of-tasks-asynchronously-using-linq) https://stackoverflow.com/questions/21868087/how-to-await-a-list-of-tasks-asynchronously-using-linq

## Serialization

[Common Newtonsoft.Json options in System.Text.Json](https://makolyte.com/common-newtonsoft-json-options-in-system-text-json/)
[Example of substituting JSON serializers](https://github.com/kiyote/RiftDrive/blob/master/src/RiftDrive.Client.Service/ExtensionMethods.cs)
[ServiceStack Json type converters] (https://forums.servicestack.net/t/how-to-create-jsonconverter-with-servicestack/5152/2) How to customize the Json that gets emitted from ServiceStack
[ServiceStack Json type converters source on github](https://github.com/ServiceStack/ServiceStack.Examples/blob/master/src/Docs/text-serializers/json-serializer.md} Source for the ServiceStack Json serializer
[System.Text.Json and new built-in JSON support in .NET Core](https://www.hanselman.com/blog/SystemTextJsonAndNewBuiltinJSONSupportInNETCore.aspx)
[.NET Serialization Benchmark 2019 Roundup](https://aloiskraus.wordpress.com/2019/09/29/net-serialization-benchmark-2019-roundup/)
[Deserialize nested JSON Response with JSON.NET](https://dotnetfiddle.net/dpzXc3) JSON and Nested classes, a Fiddle example
[JSON serialization and deserialization (marshalling and unmarshalling) in .NET - overview](https://docs.microsoft.com/en-us/dotnet/standard/serialization/system-text-json-overview) how to use the new JSON librarys in Core System.Text.Json
[Working with JSON in .NET Core 3](https://codeburst.io/working-with-json-in-net-core-3-2fd1236126c1)
[JsonSerializerOptions Class](https://docs.microsoft.com/en-us/dotnet/api/system.text.json.jsonserializeroptions?view=net-5.0) System.text.Json options
[Serialize Interface Instances With System.Text.Json](https://khalidabuhakmeh.com/serialize-interface-instances-system-text-json) workarounds for serializing Interfaces, not objects
[Using C# 9 records as strongly-typed ids](https://thomaslevesque.com/2020/10/30/using-csharp-9-records-as-strongly-typed-ids/) Thomas Levesque - great article on strongly typed IDs, and serialization
[An introduction to strongly-typed entity IDs](https://andrewlock.net/using-strongly-typed-entity-ids-to-avoid-primitive-obsession-part-1/) Andrew Lock - great article on strongly typed IDs, and serialization
[Deserialization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html) Security considerations when Deserializing

# Polly (Resilience policies)

[Using Execution Context in Polly](http://www.thepollyproject.org/2017/05/04/putting-the-context-into-polly/) Sharing mutable information throughout an execution using Context
[Implementing retry and circuit breaker pattern using Polly](https://codingcanvas.com/implementing-retry-and-circuit-breaker-pattern-using-polly/) Retry and Circuit Break example
[Check string content of response before retrying with Polly](https://stackoverflow.com/questions/50835992/check-string-content-of-response-before-retrying-with-polly) requires using two, nested, policies
[Polly WaitAndRetryAsync hangs after one retry](https://stackoverflow.com/questions/56769241/polly-waitandretryasync-hangs-after-one-retry) Don't use Polly within HttpClient
[https://stackoverflow.com/questions/44466072/understanding-the-semantics-of-polly-policies-when-separating-policy-definition/44467225#44467225](https://stackoverflow.com/questions/44466072/understanding-the-semantics-of-polly-policies-when-separating-policy-definition/44467225#44467225)
[How to limit number of async IO tasks to database?](https://stackoverflow.com/questions/62288411/how-to-limit-number-of-async-io-tasks-to-database) Example of how to throttle execution of a list of async tasks
[How to execute multiple async calls in parallel efficiently in C#?](https://stackoverflow.com/questions/61961349/how-to-execute-multiple-async-calls-in-parallel-efficiently-in-c/61964471) example of multiple parallel async calls
[Implementing the retry pattern in c sharp using Polly](https://alastaircrabtree.com/implementing-the-retry-pattern-using-p) another example of a simple retry polly policy
[Retry and fallback policies in C# with Polly](https://blog.duijzer.com/posts/polly-refit/)another example of a simple retry polly policy combined with a fallback , also unittesting
[PolicyRegistry]](https://github.com/App-vNext/Polly/wiki/PolicyRegistry) Creating a Di injected Registry (container) of multiple pre-defined policies
[Using Polly with HttpClient factory from ASPNET Core 2.1 onwards](https://github.com/App-vNext/Polly/wiki/Polly-and-HttpClientFactory) Combining Polly with the  new IHttpClientFactory
[Retry failed network requests with Polly](https://www.jerriepelser.com/blog/retry-network-requests-with-polly/) includes example of using Fiddler to insert faults in the response data coming form a webserver
[Policybuilder<TO> does not contain a definition for circuit Breaker Async #529](https://github.com/App-vNext/Polly/issues/529) the overloads change from exception-handling only, to also handling results (as you are using), we rename the parameters accordingly
[Authoring a reactive Polly policy (Custom policies Part III)](http://www.thepollyproject.org/2019/02/13/authoring-a-reactive-polly-policy-custom-policies-part-iii-2/) the policy will log any exception or fault and then just rethrow or bubble it outwards.  a flexible logging construct that can be injected into any position in a PolicyWrap, also notes on context

## Progress Reporting in Async

[The Task-based Asynchronous Pattern](https://talagozis.com/net/the-task-based-asynchronous-pattern) Blog about TAP with info on reporting progress. Good big writeup
[Reporting Progress from Async Tasks](https://blog.stephencleary.com/2012/02/reporting-progress-from-async-tasks.html) Stephen Cleary on Progress events and async tasks, includes reference to an Observer Progress Reporter Implementation
[An Improved Stream.CopyToAsync() that Reports Progress](https://www.codeproject.com/Tips/5274597/An-Improved-Stream-CopyToAsync-that-Reports-Progre) good recent (2020) example
[Reporting Progress in Async Method](https://bytelanguage.net/2018/07/14/reporting-progress-in-async-method/) good clear simple example
[Add cancellation token to an async task with progress](https://stackoverflow.com/questions/49769187/add-cancellation-token-to-an-async-task-with-progress)
[Is it safe to update IProgress from multiple threads?](https://stackoverflow.com/questions/59838642/is-it-safe-to-update-iprogress-from-multiple-threads)
[IProgress<T> synchronization](https://stackoverflow.com/questions/17982555/iprogresst-synchronization)

# Database access tips

[select query helper for nolock and no change tracking](https://codereview.stackexchange.com/questions/132931/select-query-helper-for-nolock-and-no-change-tracking) h77  (SOLID principle)

[https://visualstudiomagazine.com/articles/2019/05/24/core-sql-server.aspx](https://visualstudiomagazine.com/articles/2019/05/24/core-sql-server.aspx) https://visualstudiomagazine.com/articles/2019/05/24/core-sql-server.aspx


# Code Weaving

[.NET IL Weaving for those who know nothing about .NET IL Weaving] (https://medium.com/@heytherewill/net-il-weaving-for-those-who-know-nothing-about-net-il-weaving-c0f7e461ef47) https://medium.com/@heytherewill/net-il-weaving-for-those-who-know-nothing-about-net-il-weaving-c0f7e461ef47

[Fody/Fody](https://github.com/Fody/Fody) https://github.com/Fody/Fody Github home of Fody

## IL disassembly / viewing

[ILDasm with .Net Core](https://intellitect.com/ildasm-with-net-core/) https://intellitect.com/ildasm-with-net-core/ How to install another dotnet tool , ILDasm, and have it available on dotnet CLI

ILSpy vsix

## Fody / Anotar for injecting logging boilerplate

[Simplifies logging through a static class and some IL manipulation](https://github.com/Fody/Anotar) https://github.com/Fody/Anotar

[Fody Async MethodDecorator to Handle Exceptions](https://stackoverflow.com/questions/35120430/fody-async-methoddecorator-to-handle-exceptions) https://stackoverflow.com/questions/35120430/fody-async-methoddecorator-to-handle-exceptionsIn-depth article on Fody with Async exception handling.

[MethodBoundaryAspect.Fody](https://github.com/vescon/MethodBoundaryAspect.Fody) https://github.com/vescon/MethodBoundaryAspect.Fody well recommended fody add in for hooking into method start, stop, and exceptions

[AOP - Method and property interception in C#](https://www.codeproject.com/Articles/1223461/AOP-Method-and-property-interception-in-Csharp) how to use Cauldron.Interception.Fody, another way to decorate methods. Also has examples for PropertyChanged event decration for a property setter

[Welcome to the Cauldron wiki!](https://github.com/Capgemini/Cauldron/wiki) https://github.com/Capgemini/Cauldron/wiki
[encapsulating addins with costura.fody](https://archi-lab.net/encapsulating-addins-with-costura-fody/) Bundle DLLs into one, good for PLugins

# SQLServer

## SQL Server extensions for Visual Studio Code (VSC)

[mssql extension for Visual Studio Code](https://github.com/microsoft/vscode-mssql/wiki) Extension for VSC that bring Intellisense to writing SQL
[Use Visual Studio Code to create and run Transact-SQL scripts](https://docs.microsoft.com/en-us/sql/tools/visual-studio-code/sql-server-develop-use-vscode?view=sql-server-ver15) MS documentation on how to use the mssql extension
[Visual Studio Code (VS Code) for SQL Server development](https://www.sqlshack.com/visual-studio-code-vs-code-for-sql-server-development/) Overview and Snippets

## Monitor SQL Server health

[Database File Changes](https://jasonbrimhall.info/2019/06/25/database-file-changes/)  good example of a Session and logging file size changes

## SQL database migration and version controller

[Flyway Community edition]()

# Reactive Rx Framework (Progress Typos)

[Introduction to Rx](Testable timers with Reactive Extensions for .Net) overview and introductory material
[101 Rx Samples - a work in progress](http://rxwiki.wikidot.com/101samples#toc25) good overview of receipes for Rx
[Reporting Progress from Async Tasks](https://blog.stephencleary.com/2012/02/reporting-progress-from-async-tasks.html) Stephen Cleary on Progress events and async tasks, includes reference to an Observer Progress Reporter Implementation
[Testing and Debugging Observable Sequences](https://docs.microsoft.com/en-us/previous-versions/dotnet/reactive-extensions/hh242967(v=vs.103)) Testing Rx
[Reactive Extensions Observables Versus Regular .NET Events Part 2]*https://markheath.net/post/reactive-extensions-observables-versus_24
[Testable timers with Reactive Extensions for .Net](Testable timers with Reactive Extensions for .Net) - better way for timers that generate a stream
[Response has good ideas for parser based on rx](https://social.msdn.microsoft.com/Forums/en-US/193e65d2-29d7-4548-bbc5-5c95c99e23d9/how-do-i-process-an-observable-with-multiple-subscribers-in-sequence?forum=rx) splitting an individual sequence into sequential sub-aggregations and projections, and combining them into a final projection.
[Async / Await with IObserver<T>](https://github.com/dotnet/reactive/issues/459) very good explanation of FromAsync and why to us it instead of ToObservable
[Console.ReadLine() passed to C# event](https://stackoverflow.com/questions/31376721/console-readline-passed-to-c-sharp-event) Sample implementation of Console ReadlineAsync to an IObservable
[Testing and Debugging Observable Sequences](https://reactiveui.net/reactive-extensions/testing/testing) From the ReactiveUI project
[Observable Cancellation and passing state to observables](http://introtorx.com/Content/v1.0.10621.0/15_SchedulingAndThreading.html#Cancellation) Advanced topics for observable cancellation (uses schedulers), and passing state

# Code Generation From Expression Trees

[Dave Sexton's Blog](https://www.davesexton.com/blog/) Theory on Monads, CoMonads, Iobservable, Ienumerable, and Rx. Underpinning of LINQ queries across both enumerables and observables, entrance amd exit. WOW!
[Using Code Analysis with Visual Studio 2019 to Improve Code Quality](https://azuredevopslabs.com/labs/devopsserver/codeanalysi) overview of Visual Studio  Analysis tools
[Explore code with the Roslyn syntax visualizer in Visual Studio](https://docs.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/syntax-visualizer?tabs=csharp) includes installation instructions
[Overview of code analysis for managed code in Visual Studio](https://docs.microsoft.com/en-us/visualstudio/code-quality/static-code-analysis-for-managed-code-overview?view=vs-2019) How to enable CLI code analysis
[Expressions](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/expressions#default-value-expressions)c# language reference on "Expressions" - big doc, long read, detailed
[Write Better Code Faster with Roslyn Analyzers](https://devblogs.microsoft.com/dotnet/write-better-code-faster-with-roslyn-analyzers/) overview of the analyzers
[Creating Code Using the Syntax Factory](https://johnkoerner.com/csharp/creating-code-using-the-syntax-factory/) Code syntax visualizer
[Splitting the Expression statements with Roslyn](https://stackoverflow.com/questions/27860876/splitting-the-expression-statements-with-roslyn) Example of Roslyn code gen
[Get started with syntax analysis](https://docs.microsoft.com/en-us/dotnet/csharp/roslyn-sdk/get-started/syntax-analysis) How to setup visualstudio to provide the syntax visualizer and see a file
[Expression Tree Visualizer](https://github.com/zspitz/ExpressionTreeVisualizer) addin library for Visual Studio
[Expression Tree To String](https://github.com/zspitz/ExpressionTreeToString) Provides a ToString extension method which returns a string representation of an expression tree
[Reactive Testing Helper methods ](https://www.nuget.org/packages/Microsoft.Reactive.Testing/)
[Testing Reactive Extension code using the TestScheduler](https://putridparrot.com/blog/testing-reactive-extension-code-using-the-testscheduler/)  also mentions Throttle as a way to only pickup user's typeing  after they pause for a period (for typeahead), or slecting in a multiselect (prefetching info about selected items if the user pauses
[Testing Rx](http://introtorx.com/Content/v1.0.10621.0/16_TestingRx.html) more about testing Rx , and the Rx TestScheduler pattern

# Graphviz for visualizing graph data structures

[WebGraphviz is Graphviz in the Browser](http://www.webgraphviz.com/) Online digraph visualizer

# Graph Libraries

[Working With Graph Data Structures (In .Net)](http://blog.boxofbolts.com/dotnet/graphs/2015/08/31/working_with_graph_data_structures_dot_net/)
[The list of graph visualization libraries](https://www.experfy.com/blog/the-list-of-graph-visualization-libraries)
[QuickGraph, Graph Data Structures And Algorithms for .NET](https://archive.codeplex.com/?p=quickgraph)
[QuickGraph](https://github.com/YaccConstructor/QuickGraph) Latest Quickgraph project

# Graph Databases

[Create a graph database and run some pattern matching queries using T-SQL](https://docs.microsoft.com/en-us/sql/relational-databases/graphs/sql-graph-sample?view=sql-server-ver15)
[Integration Testing with Neo4j using C#](https://dzone.com/articles/integration-testing-with-neo4j-using-c)
[Introduction to SQL Server 2017 Graph Databases] (https://prog.world/introduction-to-sql-server-2017-graph-databases/) Introductory material for Graph DB
[How to track data lineage with SQL Server Graph Tables – Part 1 Create Nodes and Edges](https://anthonypresents.blog/2020/01/19/how-to-track-data-lineage-with-sql-server-graph-tables-part-1-create-nodes-and-edges/) Tracking Data Lineage (Provenance) from multiple sources to a final data analysis/display system
[How to track data lineage with SQL Server Graph Tables – Part 2 Create Database Procedures](https://anthonypresents.blog/2020/01/26/how-to-track-data-lineage-with-sql-server-graph-tables-part-2-create-database-procedures/) stored procedures
[How to track data lineage with SQL Server Graph Tables – Part 3 Populate Graph Tables](https://anthonypresents.blog/2020/02/02/how-to-track-data-lineage-with-sql-server-graph-tables-part-3-populate-graph-tables/) populate the tables based on data flow between systems
[How to track data lineage with SQL Server Graph Tables – Part 4 Querying the Graph Tables](https://anthonypresents.blog/2020/05/17/how-to-track-data-lineage-with-sql-server-graph-tables-part-4-querying-the-graph-tables/) query to determine every downstream place/process/field a particular source field impacts

# Testing

[Testing and Debugging Observable Sequences](https://docs.microsoft.com/en-us/previous-versions/dotnet/reactive-extensions/hh242967(v=vs.103)) Testing Rx

# Unit Testing with XUnit

[Wrap test Framework in an outer Framework](https://stackoverflow.com/questions/13829737/run-code-once-before-and-after-all-tests-in-xunit-net) interesting way to wrap up existing tests and run code before and after
[Running xUnit.net tests in MSBuild](https://xunit.net/docs/running-tests-in-msbuild) Run multiple test assemblies as the MSBuild <xUnit> task in the Project File
[Configure unit tests by using a .runsettings file](https://docs.microsoft.com/en-us/visualstudio/test/configure-unit-tests-by-using-a-dot-runsettings-file?branch=release-16.4&view=vs-2019) includes setting a runtime identifier
[Build Quality Checks](https://marketplace.visualstudio.com/items?itemName=mspremier.BuildQualityChecks) MSBuild Tasks for testing the quality of a build, good for azure too
[Run unit tests with Test Explorer](https://docs.microsoft.com/en-us/visualstudio/test/run-unit-tests-with-test-explorer?view=vs-2019) basic explanation of the test explorer in Visual Studio
[Is it possible to use Dependency Injection with xUnit?](https://stackoverflow.com/questions/39131219/is-it-possible-to-use-dependency-injection-with-xunit) Dependency injection with xUint
[Dependency Injection](http://xunitpatterns.com/Dependency%20Injection.html) another example of xUnit DI
[Using embedded resources in xUnit tests](https://www.patriksvensson.se/2017/11/using-embedded-resources-in-xunit-tests)
[Creating your own XUnit Extension](https://blog.benhall.me.uk/2008/01/creating-your-own-xunit-extension/) Very old, but explains how to get stuff before and after a test, and get a test name from inside the test

# Testing in VS Code and other testing tools

[.Net Core Unit Test and Code Coverage with Visual Studio Code]() also references some other testing tip and libraries

# Docker and Containers

[Deliver your development environment in a Docker Container](https://www.freecodecamp.org/news/put-your-dev-env-in-github/) How to use Visual Studio Code to create a Docker container that has your development environment configuration information. AKA VS Code and Remote-Containers

# UnitsNet

[How to use UnitsNet Structures as bound values in a MVC View / controller (custom binder)](https://stackoverflow.com/questions/53401720/unitsnet-how-to-use-it-in-mvc) Good info on creating a custom binder for Temperature

# Benchmarking and Profiling

[BenchmarkDotNet](https://github.com/dotnet/BenchmarkDotNet) Library for benchmarking code
[Measure application performance by analyzing CPU usage](https://docs.microsoft.com/en-us/visualstudio/profiling/beginners-guide-to-performance-profiling?view=vs-2019) Basics of profiling in Visual studio
[List of .Net Profilers: 3 Different Types and Why You Need All of Them](https://stackify.com/three-types-of-net-profilers/) Stackify's Free Prefix tool and where it is useful-svg-editor/
[Understand what your code is doing and find bugs you didn’t even know existed.](https://stackify.com/prefix/) Stackify product page for Prefix profiler

# Positioning and Interacting with a Console Window on Windows

[How to use Windows API and PInvoke to position a small console window to the bottom left of a screen](https://stackoverflow.com/questions/27715004/position-a-small-console-window-to-the-bottom-left-of-the-screen) Full working example

# Database

## Output Clause in a Query

[OUTPUT Clause (Transact-SQL)](https://docs.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql?view=sql-server-ver15) How to get back data after selects and inserts

## Database Repository Pattern for IDbConnection

[Repository Pattern and db connections](https://forums.servicestack.net/t/repository-pattern-and-db-connections/5243/12) Applies to

## ServiceStack ORM

[Using multiple databases in a ServiceStack project](https://docs.servicestack.net/multitenancy) declaratively specify which database a Service should be configured to use,
[MultiTennantAppHostTests.cs](https://github.com/ServiceStack/ServiceStack/blob/master/tests/ServiceStack.WebHost.Endpoints.Tests/MultiTennantAppHostTests.cs) example show IDbConnectionFactory and DBConnection

## Using PowerShell and Databases

[Test connectivity to SQL Server](https://octopus.com/blog/sql-server-powershell)
[How To Quickly Test a SQL Connection with PowerShell](https://mcpmag.com/articles/2018/12/10/test-sql-connection-with-powershell.aspx) Adam Bertram article, Cmdlet should be in my toolbox
[Connecting SQL Database Using Windows Powershell](https://github.com/ServiceStack/ServiceStack/blob/master/tests/ServiceStack.WebHost.Endpoints.Tests/MultiTennantAppHostTests.cs) also shows how to fill a dataset in powershell (complicated!)

## Hierarchy ID in SQL Server

[How to Use SQL Server HierarchyID Through Easy Examples](https://codingsight.com/how-to-use-sql-server-hierarchyid-through-easy-examples/) hierarchyID is a built-in data type designed to represent trees

## Identity Column

[SQL Server Identity Insert to Keep Tables Synchronized](https://www.mssqltips.com/sqlservertip/1061/sql-server-identity-insert-to-keep-tables-synchronized/) Like tables in two different tables need to keep the Idenity value synchronized

## Connection Strings

[Network Protocol for SQL Server Connection](https://www.connectionstrings.com/define-sql-server-network-protocol/) How to force TCP  protocol a the connection string
[SQL Server Connection Strings](https://www.connectionstrings.com/sql-server/) Many examples of connection strings for various providerss, clits (MSDataShape, SQLClient .Net Framework, etc)

#Object-Object mapper
[Why use Threenine.Map](https://threeninemap.readthedocs.io/en/latest/Getting-started.html)  Library on top of auto-mapper

# Build and Package

[Sharing MSBuild Tasks as NuGet Packages with](https://channel9.msdn.com/Shows/Code-Conversations/Sharing-MSBuild-Tasks-as-NuGet-Packages-with-Nate-McMaster)
[How to suppress specific MSBuild warning](https://stackoverflow.com/questions/1023858/how-to-suppress-specific-msbuild-warning) But the technique doesn't seem to work :-(
[dotnet-tools](https://github.com/natemcmaster/dotnet-tools) A list of tool extensions for .NET Core Command Line (dotnet CLI), aka '.NET Core global tools'.
[Forcing NuGet Package Usage in Visual Studio/MSBuild](https://developertown.com/forcing-nuget-package-usage-in-visual-studio-msbuild) article on some gotchas ensuring that packages are found on both developer and on build machines
[FastUpdateCheck: how to add inputs implicitly added by an imported targets file](https://github.com/dotnet/project-system/issues/3444) discussion on how to tell if a project will need to be built
[MSBuild Structured Log: record and visualize your builds](https://www.hanselman.com/blog/msbuild-structured-log-record-and-visualize-your-builds) overview on structured build logging
[MSBuilder : Reusable Build Blocks](https://github.com/MobileEssentials/MSBuilder/tree/master/src) Building Blocks for adding additional MSBuild capabilities

# Code Analysis tools

[MSBuildWorkspace](https://gist.github.com/DustinCampbell/32cd69d04ea1c08a16ae5c4cd21dd3a3) older article on MSBuildWorkspace for Framework projects
[Improving C# Source Generation Performance with a Custom Roslyn Workspace](https://jaylee.org/archive/2019/03/04/custom-roslyn-msbuild-workspace.html)
[Example code for MSBuildWorkspace](https://gitter.im/dotnet/roslyn?at=5de83da9c3d6795b9f242541) Down a bit in the gitter discussion someone posted their working example code
[How to use MSBuildWorkspace on Ubuntu](https://www.gitmemory.com/issue/dotnet/roslyn/35766/498215179)

# Task scheduling

[Coraval](https://github.com/jamesmh/coravel) Near-zero config .NET Core micro-framework that makes advanced application features like Task Scheduling, Caching, Queuing, Event Broadcasting, and more a breeze!

# Hashing Algorithms

[HashLib](https://archive.codeplex.com/?p=hashlib) library of hash algorithm implementations

# C# Parser

[Pidgin](https://github.com/benjamin-hodgson/Pidgin) C#'s fastest parser combinator library, developed at Stack Overflow

# Build tools for .Net and for "Visual studio code"

[Tools for Net Development](https://oz-code.com/blog/net-c-tips/top-10-open-source-nuget-tools-net-development) Good tools for building and net test coverage, GitVersion (SemVer), static code analysis
[GitVersion](https://gitversion.net/) Create and auto-update SemVer information for projects
[XUnit](https://www.nuget.org/packages/xunit.runner.utility/) xunit.runner.utility
[Bundling .NET build tools in NuGet](https://natemcmaster.com/blog/2017/11/11/build-tools-in-nuget/) How to bundle/distribute/share a build tool among several .NET Framework or .NET Core projects
[Basic Editing](https://code.visualstudio.com/Docs/editor/codebasics#:~:text=VS%20Code%20has%20great%20support,)%20%2D%20Format%20the%20selected%20text) VSC Basics
[Integrate with External Tools via Tasks](https://code.visualstudio.com/docs/editor/tasks) Create additional tasks to be run by keyboard shortcuts

# NuGet

[Managing the global packages, cache, and temp folders](https://docs.microsoft.com/en-us/nuget/consume-packages/managing-the-global-packages-and-cache-folders)

# Visual Studio Code Tips

[Hidden features of OmniSharp and C# extension for VS Code](https://www.strathweb.com/2020/02/hidden-features-of-omnisharp-and-c-extension-for-vs-code/)
[NXunit Test Explorer](https://marketplace.visualstudio.com/items?itemName=wghats.vscode-nxunit-test-adapter) VSC extension for xunit tests

# Powershell

https://www.itprotoday.com/powershell/powershell-one-liner-getting-local-environment-variables

https://stackoverflow.com/questions/43732061/how-to-check-whether-port-is-open-in-powershell

https://www.itprotoday.com/powershell/windows-powershell-range-operator-tricks

## Powershell packages and distribution

[Creating a portable and embedded Chocolatey Package](https://weblog.west-wind.com/posts/2017/jan/29/creating-a-portable-and-embedded-chocolatey-package)
[Creating Reusable PowerShell Modules with PsGet and Chocolatey](https://patrickhuber.github.io/2015/03/17/creating-reusable-powershell-modules-with-psget-and-chocolatey.html)

# HttpClient

[Singleton httpclient vs creating new httpclient request](https://stackoverflow.com/questions/48778580/singleton-httpclient-vs-creating-new-httpclient-request) Good stuff, using a single static instance of HttpClient doesn't respect DNS changes, so the solution is to use HttpClientFactory
[Use IHttpClientFactory to implement resilient HTTP requests](https://docs.microsoft.com/en-us/dotnet/architecture/microservices/implement-resilient-applications/use-httpclientfactory-to-implement-resilient-http-requests) explains socket exhaustion and DNS changes, how to use HTTPClientFactory, and Typed Clients

## ShouldProcess

[Everything you wanted to know about ShouldProcess](https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-shouldprocess?view=powershell-7.1) how to implemen/support the -WhatIf Common argument

# Globalization and Lcalization
[Workaround for client-side Blazor localization with .resx](https://gametorrahod.com/workaround-for-client-side-blazor-localization-with-resx/)
[How to: Build a project that has resources](https://docs.microsoft.com/en-us/visualstudio/msbuild/how-to-build-a-project-that-has-resources?view=vs-2019)
[Is there any visual editor for .resource files](https://stackoverflow.com/questions/59609373/is-there-any-visual-editor-for-resource-files)
[ResGen.exe - Download ](https://www.exefiles.com/en/exe/resgen-exe/) also https://www.pconlife.com/viewfileinfo/resgen-exe/ can download a standalone resex..exe, but buyer beware
[Resgen.exe (Resource File Generator)](https://docs.microsoft.com/en-us/dotnet/framework/tools/resgen-exe-resource-file-generator)
[Globalization and localization in ASP.NET Core](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/localization?view=aspnetcore-2.2) https://docs.microsoft.com/en-us/aspnet/core/fundamentals/localization?view=aspnetcore-2.2
[Adding Localisation to an ASP.NET Core application](https://andrewlock.net/adding-localisation-to-an-asp-net-core-application/) https://andrewlock.net/adding-localisation-to-an-asp-net-core-application/
[ASP.NET Core Localization Deep Dive] (https://joonasw.net/view/aspnet-core-localization-deep-dive) https://joonasw.net/view/aspnet-core-localization-deep-dive
[ServiceStack localized message text](https://stackoverflow.com/questions/17708978/servicestack-localized-message-text) https://stackoverflow.com/questions/17708978/servicestack-localized-message-text
[How can I properly localize Razor Views in ServiceStack](https://stackoverflow.com/questions/19683025/how-can-i-properly-localize-razor-views-in-servicestack) https://stackoverflow.com/questions/19683025/how-can-i-properly-localize-razor-views-in-servicestack
[Fluent Validation MVC inject localization service](https://stackoverflow.com/questions/35119724/fluent-validation-mvc-inject-localization-service) https://stackoverflow.com/questions/35119724/fluent-validation-mvc-inject-localization-service
[Commercial suite of tools for Localization] (https://www.soluling.com/) comprehensive but expensive

# DevOps Best Practices

[Measuring DevOps Success with Four Key Metrics](https://stelligent.com/2018/12/21/measuring-devops-success-with-four-key-metrics/)

# Github Pages for Blog

[Getting Started with GitHub Pages](https://guides.github.com/features/pages/) GitHubs own getting started guide
[How to Create a Blog Using Jekyll and GitHub Pages on Windows](https://www.kiltandcode.com/2020/04/30/how-to-create-a-blog-using-jekyll-and-github-pages-on-windows/) Good instructions
[Walktrough: How I am using Github for my blog comments](https://eiriksm.dev/walkthrough-github-comments) Uses Docker containers
[My blogging stack and publishing process](https://blog.frankel.ch/my-blogging-stack-publishing-process/) Very well explained toolchain and stack, many suggestions used in Bill's Blog
[Setting Up Comments.js with Jekyll and GitHub Pages in 5 Minutes Flat](https://zetabase.io/blog-post/setting-up-comments-on-jekyll-github-pages) Uses Zetabase cloud free service
[Comments.js:easy-setup comments for static sites](https://zetabase.io/comments-js) Uses Zetabase cloud free service
[The database for a new generation](https://zetabase.io/)

# Jekyll

[3 Simple steps to setup Jekyll Categories and Tags](https://blog.webjeda.com/jekyll-categories/) also how to create a category and tags page
[Getting started with schema.org using Microdata](https://schema.org/docs/gs.html) - syntax/structure vocabulary for search engine o add information to your Web content.
[World Leaders in Research-Based User Experience](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/) research this site for ideas in user-experience
[How I reduced my Jekyll build time by 61%](https://forestry.io/blog/how-i-reduced-my-jekyll-build-time-by-61/) - tips to speed up site build time
[Cache-busting in Jekyll, GitHub pages](https://ultimatecourses.com/blog/cache-busting-jekyll-github-pages) - add a datetime to an assets URL, so new releases force users to refetch asset
[Jekyll Resize](https://github.com/MichaelCurrin/jekyll-resize#readme) Simple image resizing filter for Jekyll 3 and 4
[CloudCannon](https://github.com/CloudCannon?q=&type=&language=&sort=) The Cloud CMS for Jekyll
[CloudCannon Snippets Monorepo](https://github.com/CloudCannon/cloudcannon-snippets)  Generic snippets used internally at CloudCannon and instructions for making a Jekyll snippet in VSC includes media query
[Create your own snippets](https://code.visualstudio.com/docs/editor/userdefinedsnippets#_create-your-own-snippets)
[Image caption implementation in Jekyll site using Liquid syntax](https://heiswayi.nrird.com/image-caption-using-liquid-syntax) good post on how to insert a image url along with a caption into a post

# Favicon

[Favicon Generator](https://realfavicongenerator.net/) also has site checker use for tests, too

# DocFx

[Use DocFx to Generate a Documentation Web Site and Publish it to GitHub Pages](https://www.codeproject.com/Articles/5259812/Use-DocFx-to-generate-a-documentation-web-site-and)
[Data structure for manifest file generated by docfx build](https://dotnet.github.io/docfx/spec/docfx_build_manifest_file.html) - use groups
[DocFX Companion Tools](https://github.com/Ellerbach/docfx-companion-tools) - TOC generator, link checker, Language Translator
[DocFX TOC Generator](https://github.com/systemgroupnet/docfx-toc-generator) - TOC generator

# Chrome Bookmarks
[Export Chrome Bookmarks to CSV file using PowerShell](https://stackoverflow.com/questions/47345612/export-chrome-bookmarks-to-csv-file-using-powershell)


## VoiceAttack
[Using Voice Dictation for In-Game Chatting with VoiceAttack & Google](https://forum.il2sturmovik.com/topic/61552-using-voice-dictation-for-in-game-chatting-with-voiceattack-google/)
# To Be sorted


[MiniProfiler](https://miniprofiler.com/)https://miniprofiler.com/ A simple mini code profiler

[Error handling in Server-Side Blazor](https://gist.github.com/SteveSandersonMS/9451f3b5497ce2b5ad16b0d07ad73539) https://gist.github.com/SteveSandersonMS/9451f3b5497ce2b5ad16b0d07ad73539

https://developer.mozilla.org/en-US/docs/Web/HTML/Element Good for knowing what eh (often unexpected) defaults are for HTML element attributes

https://tailwindcss.com/ A CSS utility framework for building CSS

https://www.toptal.com/dot-net/bootstrap-and-create-dot-net-projects good article on structureing a solution, and adding validation checks, also github badges

https://stackoverflow.com/questions/49343380/hosting-net-core-app-on-ubuntu Good article on setting up a service on ubuntu

https://www.erlang.org/downloads

https://www.rabbitmq.com/install-windows.html

https://code.visualstudio.com/docs/remote/wsl

https://www.dotnetcatch.com/2017/04/23/debugging-net-core-from-vs2017-on-windows-subsystem-for-linux/

https://weblog.west-wind.com/posts/2017/apr/13/running-net-core-apps-under-windows-subsystem-for-linux-bash-for-windows - Good!

https://docs.microsoft.com/en-us/windows/wsl/interop

[Templated components](https://docs.microsoft.com/en-us/aspnet/core/blazor/components?view=aspnetcore-3.0#templated-components) https://docs.microsoft.com/en-us/aspnet/core/blazor/components?view=aspnetcore-3.0#templated-components

[Introducing WebAssembly Interfaces](https://medium.com/wasmer/introducing-webassembly-interfaces-bb3c05bc671) https://medium.com/wasmer/introducing-webassembly-interfaces-bb3c05bc671

[Authentication](https://github.com/dotnet-presentations/blazor-workshop/blob/master/docs/06-authentication-and-authorization.md) https://github.com/dotnet-presentations/blazor-workshop/blob/master/docs/06-authentication-and-authorization.md

[Introduction to Authentication with server-side Blazor](https://chrissainty.com/securing-your-blazor-apps-introduction-to-authentication-with-blazor/) https://chrissainty.com/securing-your-blazor-apps-introduction-to-authentication-with-blazor/

[Authentication and Authorization](https://gist.github.com/SteveSandersonMS/175a08dcdccb384a52ba760122cd2eda) https://gist.github.com/SteveSandersonMS/175a08dcdccb384a52ba760122cd2eda

[EXPLORING AUTHENTICATION IN BLAZOR](https://www.oqtane.org/Resources/Blog/PostId/527/exploring-authentication-in-blazor) https://www.oqtane.org/Resources/Blog/PostId/527/exploring-authentication-in-blazor

[Validate Your Blazor Form Using EditForm](https://www.c-sharpcorner.com/article/validate-your-blazor-form-using-the-editform/) https://www.c-sharpcorner.com/article/validate-your-blazor-form-using-the-editform/

[TypeConverter Class](https://docs.microsoft.com/en-us/dotnet/api/system.componentmodel.typeconverter?view=netstandard-2.0) https://docs.microsoft.com/en-us/dotnet/api/system.componentmodel.typeconverter?view=netstandard-2.0

[FileIO helpers in standard and core](https://www.filehelpers.net/examples/) https://www.filehelpers.net/examples/

[For DLR, a Fast library for member aceess (may be old now)] (https://blog.marcgravell.com/2012/01/playing-with-your-member.html) https://blog.marcgravell.com/2012/01/playing-with-your-member.html

[For value types, you need to perform the boxing explicitly (i.e. convert to Object)](https://stackoverflow.com/questions/9860620/creating-dynamic-expressionfunct-y) https://stackoverflow.com/questions/9860620/creating-dynamic-expressionfunct-y

[Cool lambda and expression Func trick](https://stackoverflow.com/questions/17738499/create-dynamic-funct-tresult-from-object)

[Blazor Pretty Code](https://chanan.github.io/BlazorPrettyCode/)

[Create a Trimmed Self-Contained Single Executable in .NET Core 3.0](https://www.talkingdotnet.com/create-trimmed-self-contained-executable-in-net-core-3-0/)

[Creating A Step-By-Step End-To-End Database Server-Side Blazor Application](http://lightswitchhelpwebsite.com/Blog/tabid/61/EntryId/4318/Server-Side-Blazor-Reading-And-Inserting-Data-Into-A-Database-End-To-End.aspx)

[How to resize animated GIF with HTML/CSS?](https://stackoverflow.com/questions/34331351/how-to-resize-animated-gif-with-html-css)

[Scaling Responsive Animations](https://css-tricks.com/scaling-responsive-animations/)  Good CSS Tricks, nice looking site

[SASS: @import](https://sass-lang.com/documentation/at-rules/import)

[How to override get accessor of a dynamic object's property](https://stackoverflow.com/questions/29923280/how-to-override-get-accessor-of-a-dynamic-objects-property) https://stackoverflow.com/questions/29923280/how-to-override-get-accessor-of-a-dynamic-objects-property

[Blazor: Working with Events](https://visualstudiomagazine.com/articles/2018/10/01/blazor-event-handling.aspx)

[dynamic nested example?](https://gist.github.com/pbdesk/1771028) https://gist.github.com/pbdesk/1771028

https://stackoverflow.com/questions/54496040/is-it-safe-to-call-statehaschanged-from-an-arbitrary-thread

[UI Design Blog Posts by Peter Vodel](https://blog.learningtree.com/tag/ui/page/3/)

https://docs.microsoft.com/en-us/dotnet/api/system.dynamic.expandoobject?view=netcore-3.0

https://stackoverflow.com/questions/29923280/how-to-override-get-accessor-of-a-dynamic-objects-property

[Boxy SVG: A Fast, Simple, Insanely Useful, FREE SVG Editor](https://www.sitepoint.com/boxy-svg-a-fast-simple-insanely-useful-svg-editor/)

[Constraints on type parameters (C# Programming Guide)](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/generics/constraints-on-type-parameters)

[The C# WebScraping Library](https://ironsoftware.com/csharp/webscraper/)

[General DynamicObject Proxy and Fast Reflection Proxy](https://www.codeproject.com/Articles/109868/General-DynamicObject-Proxy-and-Fast-Reflection-Pr)

https://social.msdn.microsoft.com/Forums/vstudio/en-US/2b855369-a721-4010-9e33-72d699960994/how-to-fix-missing-compiler-member-error-microsoftcsharpruntimebindercsharpargumentinfocreate?forum=visualstudiogeneral

https://docs.microsoft.com/en-us/dotnet/api/system.dynamic.dynamicobject?view=netcore-3.0

https://weblog.west-wind.com/posts/2018/Jun/16/Explicitly-Ignoring-Exceptions-in-C

https://weblog.west-wind.com/posts/2016/Dec/12/Loading-NET-Assemblies-out-of-Seperate-Folders

https://weblog.west-wind.com/posts/2016/Dec/19/Visual-Studio-Debugging-and-64-Bit-NET-Applications

https://weblog.west-wind.com/categories/.NET/

https://github.com/machine/machine.specifications

https://www.codeproject.com/Articles/832189/List-vs-IEnumerable-vs-IQueryable-vs-ICollection-v

https://www.dotnetcurry.com/csharp/1481/linq-query-execution-performance

https://michaelscodingspot.com/avoid-gc-pressure/

http://joelabrahamsson.com/getting-property-and-method-names-using-static-reflection-in-c/

https://www.codeproject.com/Articles/832189/List-vs-IEnumerable-vs-IQueryable-vs-ICollection-v

https://docs.microsoft.com/en-us/aspnet/core/security/app-secrets?view=aspnetcore-3.0&tabs=windows

https://stackoverflow.com/questions/52344035/wix-installer-with-modern-look-and-feel

http://woshub.com/powershell-commands-history/

https://www.stevejgordon.co.uk/running-net-core-generic-host-applications-as-a-windows-service

https://www.stevejgordon.co.uk/using-generic-host-in-dotnet-core-console-based-microservices

https://github.com/aspnet/Hosting/blob/2a98db6a73512b8e36f55a1e6678461c34f4cc4d/samples/GenericHostSample/ServiceBaseLifetime.cs

https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-3.0

https://docs.microsoft.com/en-us/dotnet/core/deploying/

https://github.com/aspnet/AspNetCore.Docs/blob/master/aspnetcore/host-and-deploy/windows-service/samples/3.x/AspNetCoreService/Services/ServiceA.cs

https://www.nuget.org/packages/Microsoft.Extensions.Hosting.WindowsServices/3.0.0-preview5.19227.9

https://blog.stephencleary.com/2012/02/creating-tasks.html

https://github.com/aspnet/Hosting/blob/2a98db6a73512b8e36f55a1e6678461c34f4cc4d/samples/GenericHostSample/ServiceBaseLifetime.cs

https://docs.microsoft.com/en-us/dotnet/api/microsoft.extensions.hosting.ihostlifetime?view=aspnetcore-3.0

https://docs.microsoft.com/en-us/dotnet/api/microsoft.extensions.hosting.ihostlifetime?view=aspnetcore-2.2

https://stackoverflow.com/questions/32548948/how-to-get-the-development-staging-production-hosting-environment-in-configurese

https://stackoverflow.com/questions/45885615/asp-net-core-access-configuration-from-static-class

http://michaco.net/blog/EnvironmentVariablesAndConfigurationInASPNETCoreApps

https://www.loggly.com/blog/30-best-practices-logging-scale/

https://en.wikipedia.org/wiki/Reliable_Event_Logging_Protocol

https://logz.io/

https://docs.logz.io/api/

https://msdn.microsoft.com/en-us/magazine/mt694089.aspx

http://www.dotnetlogging.com/

https://stackify.com/prefix/

https://github.com/fireeye/SilkETW

https://docs.microsoft.com/en-us/iis/get-started/whats-new-in-iis-85/logging-to-etw-in-iis-85

https://docs.microsoft.com/en-us/windows/desktop/etw/configuring-and-starting-an-event-tracing-session

https://www.simba.com/products/SEN/doc/development_guides/sql/content/productize/etwlogging.htm



https://docs.microsoft.com/en-us/previous-versions/windows/hardware/previsioning-framework/ff545650(v=vs.85)

https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/wpp-software-tracing

https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/software-tracing-faq

https://merbla.com/2018/04/05/exploring-serilog-v2---configuration/

https://github.com/serilog/serilog

https://github.com/serilog/serilog-sinks-file

https://github.com/serilog/serilog-sinks-console

https://github.com/serilog/serilog-settings-configuration

https://github.com/serilog/serilog-settings-configuration/blob/dev/sample/Sample/appsettings.json

https://nblumhardt.com/2016/03/reading-logger-configuration-from-appsettings-json/

https://github.com/serilog/serilog-aspnetcore

https://itnext.io/loggly-in-asp-net-core-using-serilog-dc0e2c7d52eb

https://jacksowter.net/serilog-config/

https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/tools-for-software-tracing

https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/tools-for-software-tracing#when-should-i-use-wpp-software-tracing-or-the-event-tracing-for-windows-etw-api

https://en.wikipedia.org/wiki/Windows_software_trace_preprocessor

https://www.mgtek.com/traceview/backgrounder

https://www.tutorialdocs.com/article/aspnet-core-log-components.html

[ConfD User guide](http://66.218.245.39/doc/html/index.html) -Tail-f's ConfD is a device configuration toolkit meant to be integrated as a management sub-system in network devices

https://stackoverflow.com/questions/2031163/when-to-use-the-different-log-levels

https://stackify.com/serilog-tutorial-net-logging/

https://archive.codeplex.com/?p=visuallogparser

https://github.com/serilog/serilog-sinks-async

https://github.com/serilog/serilog/issues/1111

https://github.com/FantasticFiasco/serilog-sinks-http-sample-dotnet-core/blob/master/sample/Program.cs

https://blog.datalust.co/nlog-4-5-structured-logging/

https://datalust.co/seq

https://github.com/datalust/nlog-targets-seq/blob/dev/appveyor.yml

https://docs.datalust.co/docs/using-nlog

https://github.com/FantasticFiasco/serilog-sinks-udp

https://github.com/serilog/serilog-sinks-trace

https://github.com/serilog/serilog/issues/725

https://stackoverflow.com/questions/50679571/how-do-i-interpret-serilog-configuration-in-asp-net-core-2-1/50680201#50680201

https://nblumhardt.com/2017/08/use-serilog/

https://github.com/serilog/serilog-sinks-file/blob/dev/example/Sample/Program.cs

https://nblumhardt.com/2017/06/ansi-console/

http://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html

https://github.com/serilog/serilog-aspnetcore/issues/68

https://stackify.com/serilog-tutorial-net-logging/

https://github.com/serilog/serilog-aspnetcore

https://github.com/serilog/serilog-settings-configuration

https://nblumhardt.com/2016/07/serilog-2-write-to-logger/

https://github.com/serilog/serilog/wiki/Lifecycle-of-Loggers

https://github.com/serilog/serilog/wiki/Structured-Data

https://blog.datalust.co/serilog-tutorial/

https://mcguirev10.com/2018/02/07/serilog-dependency-injection-easy-ip-logging.html

https://stackoverflow.com/questions/47702581/using-asp-net-core-2-injection-for-serilog-with-multiple-projects

https://stackoverflow.com/questions/51345161/should-i-take-ilogger-iloggert-iloggerfactory-or-iloggerprovider-for-a-libra

https://docs.microsoft.com/en-us/dotnet/api/microsoft.extensions.logging.iloggingbuilder?view=aspnetcore-3.0

https://andrewlock.net/logging-using-diagnosticsource-in-asp-net-core/

https://lttng.org/docs/v2.10/#doc-nuts-and-bolts

https://www.azureserviceprofiler.com/help/faq-asp-net-core

https://docs.microsoft.com/en-us/azure/azure-monitor/app/profiler-overview

https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.diagnosticlistener?view=netcore-2.2

https://weblog.west-wind.com/posts/2018/Dec/31/Dont-let-ASPNET-Core-Default-Console-Logging-Slow-your-App-down

https://wakeupandcode.com/logging-in-asp-net-core/

https://www.c-sharpcorner.com/article/logging-framework-in-asp-net-core-2-0/

https://www.codeproject.com/Articles/859035/Logging-Method-Entry-and-Exit-Points-Dynamically

https://github.com/Suchiman/SerilogAnalyzer

https://github.com/nblumhardt/autofac-serilog-integration

https://github.com/Fody/Anotar

https://weblog.west-wind.com/posts/2018/Feb/18/Accessing-Configuration-in-NET-Core-Test-Projects

https://docs.datalust.co/docs/using-aspnet-core

https://lostechies.com/jimmybogard/2012/10/08/favor-query-objects-over-repositories/

http://codingcanvas.com/query-objects/

http://codingcanvas.com/introduction-to-language-understanding-intelligent-service-luis/

https://raw.githubusercontent.com/Fody/Fody/master/SampleWeaver.Fody/ModuleWeaver.cs

https://intellitect.com/creating-fody-addin/

https://www.hanselman.com/blog/CommentView.aspx?guid=0b5da3d4-99cb-4b30-88af-cc1aee40adcb#commentstart

https://github.com/Keboo/ExampleFodyWeaver/blob/master/Example.Fody/Example.Fody.csproj

http://putridparrot.com/blog/my-first-fody-moduleweaver/

https://github.com/nicolo-ottaviani/Xamarin.BindableProperty.Fody/issues/5

https://stackoverflow.com/questions/56048565/error-fody-no-weavers-found-add-the-desired-weavers-via-their-nuget-package

https://github.com/Fody/Anotar/issues/114

https://github.com/Fody/Fody/#usage

https://github.com/Fody/Anotar/blob/master/Serilog/Tests/SerilogTests.cs

https://docs.particular.net/components/#community-run-projects

[How can Fody be used to weave compiled dll's without using msbuild?](https://stackoverflow.com/questions/29576019/how-can-fody-be-used-to-weave-compiled-dlls-without-using-msbuild) https://stackoverflow.com/questions/29576019/how-can-fody-be-used-to-weave-compiled-dlls-without-using-msbuild

[AAATrafic/Fody.StandAlone](https://github.com/AAATrafic/Fody.StandAlone) https://github.com/AAATrafic/Fody.StandAlone

[Creating Fody Extensions](https://onedrive.live.com/view.aspx?cid=0077f3f8ce7788de&page=view&resid=77F3F8CE7788DE!412634&parId=77F3F8CE7788DE!412632&authkey=!APbXr_cN4N4KSs4&app=Word) https://onedrive.live.com/view.aspx?cid=0077f3f8ce7788de&page=view&resid=77F3F8CE7788DE!412634&parId=77F3F8CE7788DE!412632&authkey=!APbXr_cN4N4KSs4&app=Word additional reference links

https://nugetmusthaves.com/Tag/fody?page=2

[Fody Addins List](https://github.com/Fody/Home/blob/master/pages/addins.md) https://github.com/Fody/Home/blob/master/pages/addins.md

[Fody Addin Discovery](https://github.com/Fody/Home/blob/master/pages/addin-discovery.md) https://github.com/Fody/Home/blob/master/pages/addin-discovery.md

https://nugetmusthaves.com/Package/Equals.Fody

https://nugetmusthaves.com/Package/MethodBoundaryAspect.Fody
[Tracing and logging rewriter using Fody](https://github.com/csnemes/tracer) https://github.com/csnemes/tracer

https://www.reddit.com/r/csharp/comments/bah93m/proper_tracinglogging_tracesource_vs_eventsource/

https://docs.microsoft.com/en-us/dotnet/framework/debug-trace-profile/how-to-use-tracesource-and-filters-with-trace-listeners

https://stackoverflow.com/questions/51386660/trace-log-to-file-using-tracesource

https://www.nuget.org/packages/Microsoft.Extensions.Logging.TraceSource/

https://www.nuget.org/packages/Microsoft.Extensions.Logging.eventSource/

https://github.com/Microsoft/perfview

https://github.com/microsoft/perfview/releases/tag/P2.0.42

https://www.prajwaldesai.com/windows-10-adk-versions/

https://www.tenforums.com/tutorials/117625-download-install-windows-performance-toolkit-windows-10-a.html

https://docs.microsoft.com/en-us/windows-hardware/test/wpt/windows-performance-analyzer

https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install

https://docs.microsoft.com/en-us/windows-hardware/test/wpt/

[Windows Performance Analyzer step-by-step guide](https://docs.microsoft.com/en-us/windows-hardware/test/wpt/wpa-step-by-step-guide) https://docs.microsoft.com/en-us/windows-hardware/test/wpt/wpa-step-by-step-guide - good intro

[dnSpy is a debugger and .NET assembly editor](https://github.com/0xd4d/dnSpy) https://github.com/0xd4d/dnSpy

[EventManifest Schema](https://docs.microsoft.com/en-us/windows/desktop/WES/eventmanifestschema-schema) https://docs.microsoft.com/en-us/windows/desktop/WES/eventmanifestschema-schema

[File nesting in Solution Explorer](https://docs.microsoft.com/en-us/visualstudio/ide/file-nesting-solution-explorer?view=vs-2019) https://docs.microsoft.com/en-us/visualstudio/ide/file-nesting-solution-explorer?view=vs-2019

[Publish ASP.NET Core directory structure](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/directory-structure?view=aspnetcore-3.0) https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/directory-structure?view=aspnetcore-3.0

[ASP.NET Core Module](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/aspnet-core-module?view=aspnetcore-3.0#enhanced-diagnostic-logs) https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/aspnet-core-module?view=aspnetcore-3.0#enhanced-diagnostic-logs

[Microsoft.NET.Sdk.Web](https://github.com/aspnet/websdk) https://github.com/aspnet/websdk

[HTTP.sys web server implementation in ASP.NET Core](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/servers/httpsys?view=aspnetcore-3.0) https://docs.microsoft.com/en-us/aspnet/core/fundamentals/servers/httpsys?view=aspnetcore-3.0

[Find and Replace Strings in Multiple Files](https://powershell.org/forums/topic/find-and-replace-strings-in-multiple-files/) https://powershell.org/forums/topic/find-and-replace-strings-in-multiple-files/

[NuGet packages location in .Net Core](https://stackoverflow.com/questions/7018913/where-does-nuget-put-the-dll)  C:\Users\[User]\.nuget\packages

[Useful ServiceStack Path utilities, and MapHost methods](https://github.com/ServiceStack/ServiceStack.Text/blob/master/src/ServiceStack.Text/PathUtils.cs) https://github.com/ServiceStack/ServiceStack.Text/blob/master/src/ServiceStack.Text/PathUtils.cs

[Dual Mode Blazor](https://github.com/Suchiman/BlazorDualMode/blob/master/BlazorDualMode.Server/Startup.cs) https://github.com/Suchiman/BlazorDualMode/blob/master/BlazorDualMode.Server/Startup.cs from Robin Sue @Suchiman

[Service Stack Virtual File System](https://docs.servicestack.net/virtual-file-system) https://docs.servicestack.net/virtual-file-system

[ServiceStack plugins](https://docs.servicestack.net/plugins) https://docs.servicestack.net/plugins

[ServiceStack Web Apps](http://templates.servicestack.net/docs/web-apps) http://templates.servicestack.net/docs/web-apps  SS's approach to new web application development

[ServiceStack's dotnet-app master blob](https://github.com/ServiceStack/dotnet-app/tree/master/src/apps) https://github.com/ServiceStack/dotnet-app/tree/master/src/apps lots of examples of the latest SS stuff

[Lambdas in powerShell](https://stackoverflow.com/questions/10995667/lambda-expression-in-powershell) Scriptblocks are Powershell's lambdas

[Please, everyone, put your entire development environment in Github](https://www.freecodecamp.org/news/put-your-dev-env-in-github/)

[Solution examples for crossplatform building a stylecop rules](https://github.com/dotnet/iot/tree/master/eng) Good Information for building solutions and stylecop analyzers
[Enumerable.Empty() vs new ‘IEnumerable’()](https://agirlamonggeeks.com/2019/03/22/enumerable-empty-vs-new-ienumerable-whats-better/) nitty gritty on creating an empty IEnumerable<T>
[Example Build.ps for using Cake Build tool](https://github.com/oldrev/Sandwych.QuickGraph/blob/master/build.ps1) Example powershell build.ps for bootstrapping Cake build
[Property Graphs Explained-The Universal Data Model Paradigm](http://graphdatamodeling.com/Graph%20Data%20Modeling/GraphDataModeling/page/PropertyGraphs.html) Graph data structures
[Consuming the Task-based Asynchronous Pattern](https://docs.microsoft.com/en-us/dotnet/standard/asynchronous-programming-patterns/consuming-the-task-based-asynchronous-pattern) how to call async tasks
[Using Generic Extension Methods](https://www.codeproject.com/Articles/29079/Using-Generic-Extension-Methods) how to use AS in generic extensions
[Abstract class with constructor, force inherited class to call it](https://stackoverflow.com/questions/28568391/abstract-class-with-constructor-force-inherited-class-to-call-it) interesting about parameterless constructors in an abstract class
[invoking an async task on fluentassertion](https://stackoverflow.com/questions/51661681/invoking-an-async-task-on-fluentassertion) example of how to run an async task in fluentassertions
[Introducing diagnostics improvements in .NET Core 3.0](https://devblogs.microsoft.com/dotnet/introducing-diagnostics-improvements-in-net-core-3-0/) Study for improved tracing and dumping in Core 3

[Splat library](https://www.nuget.org/packages/Splat/) A library for crossplatform image display among other things
[Compare Packages Between Distributions](https://distrowatch.com/dwres.php?resource=compare-packages&firstlist=gentoo&secondlist=devuan&firstversions=0&secondversions=0&showall=yes) Linux tool to compare packages between two *nix distros
[Nerdbank.GitVersioning](https://github.com/dotnet/Nerdbank.GitVersioning) A better versiooning tool than mine?
[.NET Foundation Projects](https://dotnetfoundation.org/projects) some massive OSS projects for .Net, need to inspect and review these
[ReactiveUI] (https://github.com/reactiveui) >Net version of UI builder based on Reactive, along with many other libraries
[Wyam](https://wyam.io/) A HIGHLY MODULAR AND EXTREMELY CONFIGURABLE STATIC CONTENT GENERATOR AND TOOLKIT.
[The Task-based Asynchronous Pattern](https://talagozis.com/net/the-task-based-asynchronous-pattern) Blog about TAP with info on reporting progress. Good big writeup

[Hi, I am Nima](https://www.nimaara.com/) excellent writer andposts about performance increasing, threads, locking, etc., also good looking blog design. Counting lines the smart way
[Cool WSL (Windows Subsystem for Linux) tips and tricks you (or I) didn't know were possible](https://www.hanselman.com/blog/CoolWSLWindowsSubsystemForLinuxTipsAndTricksYouOrIDidntKnowWerePossible.aspx) Overview of WSL on Windows
[Stuff on multiple assembly loading](https://stackoverflow.com/questions/2500280/invalidcastexception-for-two-objects-of-the-same-type/30623970)
[Adaptive Library Logging with Microsoft.Extensions.Logging](https://www.nexmo.com/blog/2020/02/10/adaptive-library-logging-with-microsoft-extensions-logging-dr) good stuff on logging
[good stuff on loggin]
[Notion.so](https://www.notion.so/product)seems like a good online "project notebook" for teams to keep organized
[SQL Backup Master](https://www.sqlbackupmaster.com/Content/static/Help/HTML/index.html) possible solution to keeping databases available in dropbox or any cloud storage location
[ASP.NET Core 3.0 Configuration Factsheet](https://www.red-gate.com/simple-talk/dotnet/net-development/asp-net-core-3-0-configuration-factsheet/) Dino Exposito on IConfiguration. Good explanation / example  on run-time reloading configuration from changed json files
[Gui.cs - Terminal UI toolkit for .NET](https://github.com/migueldeicaza/gui.cs) GUI over curses for terminals windows and linux
[Cool article on JWT Tokens, and general cryptogrtaphic functions to encryupt, and validate] https://blog.thea.codes/building-a-stateless-api-proxy/
[more on Lazy and using it in a GHHS](https://thomaslevesque.com/2020/03/18/lazily-resolving-services-to-fix-circular-dependencies-in-net-core/)

## Security stuff
[Pentesting Notes](https://github.com/picheljitsu/pentestnotes)


//#if TRACE
//  [ETWLogAttribute]
//#endif
