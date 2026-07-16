# Plugin Architecture initial creation prompt

> **Archived 2026-07-06** (Sprint 0012 Task 12.45.e, documentation reorganization per
> `PlanDocumentationReorganization.md`). Superseded by `GenericPluginArchitecture.md`.
> Retained as decision/analysis history; do not update.

You are an expert in the latest version of the C# language, the latest versions of the dotnet SDK and dotnet runtime, and the latest versions of the Roslyn compiler
ToDo: engage the CONTEXT7 mcp server to access the latest documentation on these subjects

the following paragraphs

- how the packages in ATAP.Utilities should be consumed.
- how AceCommander should be able to consume the packages
- how to create ATAP.Console families of projects that can consume ATAP.Utilities.package

1. The 'customary' consumption of packages either by project reference (for projects that are in the same solution) or by package reference (from a ProGet feed)
2. The loadable and hot-swappable consumption of packages via a dynamic appdomain or similar approach, for loading, swapping, or removing a package at runtime (we call this the plugin architecture)

We want to write at least one new Console app in ATAP.Utilities that demonstrates both mechanism for consuming packages.

Not all packages have to be able to be consumed via dynamic loading. the ATP.Utilities packages and package families that will eventually support dynamic loading include:

ATAP.Utilities.Secrets
ATAP.Utilities.Secrets.Bitwarden
ATAP.Utilities.Secrets.KeePass

ATAP.Utilities.MessageQueue
MessageQueue.Shim.RabbitMQ
MessageQueue.Shim.TPL

ATAP.Utilities.Serializer (this is the family of packages that is nearest to completion of the plugin architecture)
Serializer.Shim.Newtonsoft
Serializer.Shim.ServiceStack
Serializer.Shim.SystemTextJson
ATAP.Utilities.Serializer.Shim.Plugin

ATAP.Utilities.Testing (this family is also well along towards being a plugin )
ATAP.Utilities.Testing.DI
ATAP.Utilities.Testing.DI.Fixture.Serialization
ATAP.Utilities.Testing.Fixture.Database
ATAP.Utilities.Testing.Fixture.Serialization
ATAP.Utilities.Testing.Fixture.Serialization.Shim.Plugin
ATAP.Utilities.Testing.Fixture.Serialization.Shim.ServiceStack
ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson

-- and others that use this pattern --

In the plugin architecture:

- there are multiple packages that can implement a specific family of plugin (Serializers is one such family, as are Secrets, and testingFixtures)
- there is an interface that all members of the plugin family will implement
- consumers of the plugin family call a generic implementation of the interface
- the plugin loader takes care of finding the appropriate .dll, loading it into an appdomain, and conencting the call site of the generic to the specific call site of the implementation
- all plugin packages come with a shim assembly that facilitates the loader loading and wiring the specific instance
- all plugin packages build their own iAppSettings from the ATAP.Utilities.Configuration family, the generic version of which is populated first when the application loads, and then again when a specific plugin loads
- Redis is one possible solution for Config keys. It is not the only possible solution, explore other FOSS options, including SQL Server Community Edition for the property pattern where getters/setters are pass-through to ICacheClient. Suggest multiple solutions for this area, along with Pros and Cons of each approach
- include folder probing to find packages that meet the interfaces necessary to be a part of a specific family of plugins
- the folder C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items\src\ATAP.Utilities.Loader implements a dynamic loader using a specific FOSS library 'McMaster.NETCore.Plugins'. Determine if that library is still in active development, and the pros and cons of using that library, versus writing its equivalent from scratch in C# and dotnet. Evaluate the feasibility of rewriting the critical path features from the FOSS library directly into ATAP.Utilities.Loader.

Years ago, the solution at C:\Dropbox\whertzing\GitHub\Ace attempted to do something similar, using ServiceStack
I want you to design the major pieces of the generic plugin architecture that will support the goals as outlined above.
Look at C:\Dropbox\whertzing\GitHub\Ace\Doc\PluginArchitecture.md and at the code in the folder C:\Dropbox\whertzing\GitHub\Ace to inform how this earlier solution attempted the plugin architecture
The solution should be based on only dotnet libraries. in particular, ServiceStack should NOT be used in the solution. However the best available FOSS solution for ConcurrentObservableDictionary can be selected. Report the Pros and Cons of various implementations for concurrent observabledictionary. likewise 'McMaster.NETCore.Plugins' and alternative FOSS dynamic loaders. It is entirely possible that the best solution is to pick and chose the best features of various implementations, and incorporate them into dedicated ATAP.Utilities packages.

Notice in Ace that the plugins do not just provide call sites for methods and properties, they also explose a specialized collection that implement the IDATA interface. This IData collection exposes selected data structures the plugin uses, and exposes them in a standrad way that can be DI-injected into the consuming host. This allows the consuming host to be made aware of changes in the data in the plugin.

Security is always important. the package should be opaque to the callingprocess - no way for a malicious caller to modify any of the executingable or executing code. Other than the IDAtA structure, the callingprocess may not take any references to the objects within the plugin. Data from the plug that is returned to the consuming process should used agreed-upon DTO structures, and these should be deep-copies of the data created by the plugin.

The plugins should be garbage-collected "soon" after they are released, and any sensitive data in the plugin should be zero'd when a plugin is unloaded.

Your task is to create 1 document that lays out the architecture for the plugin feature in genreal
then create a second document that specifies the files needed to create access to the Bitwearden vault to get secrets, by secret name and secret field name, in a (set of) projects that make ATAP.Utilities.Secrets plugion-capable (and also referencable by package or project)
The documents created in task 1 and 2 go into the folder C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-94-sprint-0004-work-items\SolutionDocumentation
your third task is to layout a plan of action to create the plugin-and-project-reference-capable ATAP.Utilities.Secrets, and any other needed modules like ATAP.Utilities.Loader
your fourth task is to create a plan of action to create ATAP.Console.PLuginDemo, which will demonstrate using the plugin loader to access secrets in Bitwarden

The generic plugin interface for a plugin family, and the actual implementation, should follow the code stanrads and project layout of other mature ATAP.utilities packages - a Facade project, with StringConstants, DefaultConfiguration, Enumerations, Interfaces, and Models as subprojects. in addition to the standard, plugin families also include the generic 'Shim' project, which is used to connect the specific implementation packages to the loader. Each family may have one shim or one shim per instantiation, depending on the needs of the plugin

You have permission to read any file(s) in C:\Dropbox\whertzing\GitHub\Ace

Bonus - design the architecture and write the packages so they can easily be consumed by Powershell modules.
Double Bonus - write the powershell code needed to dynamically bind a plugin at runtime.
