<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# You are an expert on dotnet classes. In addition to the standard Microsoft libraries, you are expert in the NuGet packages and wget packages that come from large OSS software projects. You are an expert in MIT-licensed dotnet packages (.dlls) from github. Find me a library that includes an object , similar to the URLBuilder class, that builds Microsoft SQL Server connection objects. Give preference to packages that use the connection object /type in powershell scripts. give preference to objects that can alos create JDBC driver connection strings. Give me at least 5 such libraries

The best fit for what you describe is dbatools’ connection-string builder plus a handful of multi‑DB wrappers that expose both ADO.NET and JDBC‑style URL construction. Here are at least five libraries/tools that match your preferences, with emphasis on PowerShell usage and, where available, JDBC URL support.

## 1. dbatools (New-DbaConnectionStringBuilder)

- **What it is**: Large OSS PowerShell module for SQL Server administration; MIT‑licensed on GitHub and distributed via the PowerShell Gallery.[^1_1][^1_2]
- **Relevant object**: `New-DbaConnectionStringBuilder` returns a `Microsoft.Data.SqlClient.SqlConnectionStringBuilder` instance that you can manipulate like a strongly typed URL builder for SQL Server connection strings.[^1_1]
- **PowerShell usage**:
  - Designed to be called directly from scripts: you pass server, database, authentication, encryption flags, and it returns a builder/connection string suitable for `Microsoft.Data.SqlClient.SqlConnection`.[^1_2][^1_1]
  - Widely used in PowerShell‑only workflows (no external .exe) and plays nicely with your existing Microsoft.Data.SqlClient usage.
- **JDBC aspect**: Focused on .NET; doesn’t emit JDBC URLs itself, but pairs well if you want to programmatically keep ADO.NET and JDBC strings in sync in one script (dbatools for ADO.NET, simple string template for JDBC).

## 2. DatabaseWrapper (jchristn/DatabaseWrapper)

- **What it is**: C\# database wrapper for SQL Server, MySQL, PostgreSQL, and SQLite; exposes simple methods for creating connections and performing CRUD without manually handling raw connection strings.[^1_3]
- **Connection building**:
  - Provides strongly typed configuration objects (server, database, user, password, port, SSL, etc.) and internally builds the ADO.NET connection strings for multiple engines, including SQL Server.[^1_3]
  - Acts like a higher‑level connection builder object instead of you directly using `SqlConnectionStringBuilder`.
- **PowerShell usage**:
  - Distributed as a .NET library, so you can load the .dll in PowerShell (`Add-Type` or `#r "nuget: …"`) and call its C\# APIs from scripts.
- **JDBC aspect**:
  - Does not generate JDBC URLs directly, but since it centralizes all parameters, it is straightforward to add a small helper around it that emits a `jdbc:sqlserver://...` string using the same configuration.

## 3. Aireforge SQL Server Connection String Generator

- **What it is**: Open‑source SQL Server connection string generator with support for both classic ADO.NET and JDBC connection URL formats.[^1_4]
- **Connection building**:
  - Provides a builder‑style UI and logic to generate SQL Server connection strings, including workstation ID and advanced options.[^1_4]
  - It explicitly shows how to produce JDBC SQL Server URLs as part of the same configuration surface (“jdbc:sqlserver://localhost …”).[^1_4]
- **PowerShell usage**:
  - Primarily a GUI/web tool, but the underlying builder logic can be reused or ported into a .NET library that your PowerShell scripts can call once you reference the compiled assembly.
- **JDBC aspect**:
  - Natively supports emitting `jdbc:sqlserver://` URLs with all standard parameters (server, port, databaseName, user, password, encryption, etc.).[^1_4]

## 4. Microsoft Elastic DB Tools for Java – SqlConnectionStringBuilder (Java)

- **What it is**: Part of Microsoft’s Elastic DB Tools for Java; includes a `SqlConnectionStringBuilder` class implemented in Java that builds `jdbc:sqlserver://` URLs and parses them.[^1_5]
- **Connection building**:
  - The Java `SqlConnectionStringBuilder` exposes properties for server, database, integrated security, user, password, and other options, and emits a valid SQL Server JDBC URL.[^1_5]
- **PowerShell usage**:
  - While this is Java‑side, it is useful if you have a mixed .NET/Java environment and want parity: it mirrors the .NET `SqlConnectionStringBuilder` pattern for JDBC.
- **JDBC aspect**:
  - Fully focused on JDBC URL construction; designed specifically to output `jdbc:sqlserver://…` strings in a safe, builder‑style manner.[^1_5]

## 5. Microsoft.Data.SqlClient.SqlConnectionStringBuilder (ADO.NET, used from PowerShell)

- **What it is**: The current SQL Server ADO.NET provider’s connection string builder; distributed as the `Microsoft.Data.SqlClient` NuGet package (MIT‑licensed).[^1_6]
- **Connection building**:
  - Strongly typed builder that constructs valid SQL Server connection strings from properties such as `DataSource`, `InitialCatalog`, `UserID`, `Password`, `Encrypt`, `TrustServerCertificate`, etc.[^1_7][^1_6]
- **PowerShell usage**:
  - In PowerShell 7+ you can do `#r "nuget: Microsoft.Data.SqlClient"` and then use `[Microsoft.Data.SqlClient.SqlConnectionStringBuilder]` to build connection strings, then pass them to `[Microsoft.Data.SqlClient.SqlConnection]` objects.[^1_7][^1_6]
  - This pattern is widely used in PowerShell scripts that connect to SQL Server, including in dbatools’ implementation.[^1_1]
- **JDBC aspect**:
  - Does not create JDBC URLs itself, but because the builder exposes all the relevant fields, you can easily derive a JDBC string in PowerShell/ C\# from the same property set (server, databaseName, user, password, encryption flags).

---

If you want a single starting point that is PowerShell‑friendly and opinionated around Microsoft.Data.SqlClient, dbatools’ `New-DbaConnectionStringBuilder` is the most ready‑to‑use option; pairing it with a small helper function that maps its builder properties to a `jdbc:sqlserver://` template will give you a dual ADO.NET/JDBC “URLBuilder‑style” object tailored to your environment.[^1_8][^1_6][^1_1]
<span style="display:none">[^1_10][^1_11][^1_12][^1_13][^1_14][^1_15][^1_16][^1_17][^1_18][^1_19][^1_20][^1_21][^1_22][^1_23][^1_24][^1_25][^1_26][^1_27][^1_28][^1_29][^1_30][^1_31][^1_32][^1_33][^1_34][^1_35][^1_36][^1_37][^1_9]</span>

<div align="center">⁂</div>

[^1_1]: https://dbatools.io/New-DbaConnectionStringBuilder/

[^1_2]: https://www.powershellgallery.com/packages/dbatools/1.1.54/Content/functions\New-DbaConnectionStringBuilder.ps1

[^1_3]: https://github.com/jchristn/DatabaseWrapper

[^1_4]: https://www.aireforge.com/tools/sql-server-connection-string-generator

[^1_5]: https://github.com/microsoft/elastic-db-tools-for-java/blob/master/elastic-db-tools/src/main/java/com/microsoft/azure/elasticdb/shard/sqlstore/SqlConnectionStringBuilder.java

[^1_6]: https://learn.microsoft.com/en-us/dotnet/api/microsoft.data.sqlclient.sqlconnectionstringbuilder?view=sqlclient-dotnet-core-6.1

[^1_7]: https://learn.microsoft.com/en-us/sql/connect/ado-net/connection-string-builders?view=sql-server-ver17

[^1_8]: https://www.beekeeperstudio.io/blog/jdbc-sql-server-connection-string

[^1_9]: https://stackoverflow.com/questions/78876660/multiple-nuget-packages-referencing-a-common-class-library-in-the-same-solution

[^1_10]: https://learn.microsoft.com/en-us/dotnet/standard/library-guidance/nuget

[^1_11]: https://www.youtube.com/watch?v=43o2TSF0x1k

[^1_12]: https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlconnectionstringbuilder?view=netframework-4.8.1

[^1_13]: https://www.youtube.com/watch?v=g8YD1xFCwoo

[^1_14]: https://github.com/mcdon-ron/SqlConnectionStringBuilder-UI

[^1_15]: https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/connection-string-builders

[^1_16]: https://github.com/nhibernate/fluent-nhibernate/issues/488

[^1_17]: https://www.connectionstrings.com/sql-server/

[^1_18]: https://stackoverflow.com/questions/25682703/connect-to-sql-server-database-from-powershell

[^1_19]: https://fluent.apryse.com/documentation/engine-guide/Fluent RESTful Engines/JDBCDriverConnectionStringsforJavaRESTfulEngine

[^1_20]: https://stackoverflow.com/questions/15631602/how-can-i-set-an-sql-server-connection-string

[^1_21]: https://github.com/sqlkata/querybuilder

[^1_22]: https://stackoverflow.com/questions/28992243/getting-ms-sql-server-connection-string-without-using-visual-studio

[^1_23]: https://stackoverflow.com/questions/43979704/using-sqlconnectionstringbuilder-for-ef-connection-string-throws-exception

[^1_24]: https://stackoverflow.com/questions/4804086/is-there-any-connection-string-parser-in-c

[^1_25]: https://github.com/dotnet/SqlClient/issues/3165

[^1_26]: https://stackoverflow.com/questions/185474/c-sharp-retrieving-correct-dbconnection-object-by-connection-string

[^1_27]: https://github.com/testcontainers/testcontainers-dotnet/discussions/828

[^1_28]: https://stackoverflow.com/questions/7900201/get-user-and-password-from-connectionstringsettings

[^1_29]: https://github.com/chucknorris/roundhouse/issues/343

[^1_30]: https://stackoverflow.com/questions/3910364/quick-ways-to-test-ole-db-connection-string

[^1_31]: https://github.com/dotnet/SqlClient/issues/2085

[^1_32]: https://stackoverflow.com/questions/434864/how-to-check-if-connection-string-is-valid

[^1_33]: https://github.com/dotnet/SqlClient/issues/31

[^1_34]: https://access1348.rssing.com/chan-8127163/all_p156.html

[^1_35]: https://community.ibm.com/community/user/discussion/upgrading-jdbc-driver-1261

[^1_36]: https://wenku.csdn.net/column/1y9zq7sso4

[^1_37]: https://github.com/npgsql/npgsql/issues/617

---

# give me powershell to test for the presnecew of the dbatools module, and inmport it

Use `Get-Module -ListAvailable` to test whether dbatools is installed, then `Import-Module` only if it exists:

```powershell
# Test for presence of dbatools, then import it
$module = Get-Module -ListAvailable -Name dbatools

if ($null -eq $module) {
    Write-Host "dbatools module is not installed. Install it with: Install-Module -Name dbatools"
}
else {
    Import-Module -Name dbatools -ErrorAction Stop
    Write-Host "dbatools module imported. Version: $((Get-Module dbatools).Version)"
}
```

If you also want to install it automatically when missing (from the PowerShell Gallery):

```powershell
$module = Get-Module -ListAvailable -Name dbatools

if ($null -eq $module) {
    Write-Host "dbatools not found; installing from PSGallery..."
    Install-Module -Name dbatools -Scope CurrentUser -Force
}

Import-Module -Name dbatools -ErrorAction Stop
Write-Host "dbatools module imported. Version: $((Get-Module dbatools).Version)"
```

This pattern matches the recommended `Install-Module dbatools` then `Import-Module dbatools` flow used in dbatools’ own installation guidance.[^2_1][^2_2]
<span style="display:none">[^2_10][^2_11][^2_12][^2_13][^2_14][^2_15][^2_16][^2_17][^2_18][^2_19][^2_20][^2_3][^2_4][^2_5][^2_6][^2_7][^2_8][^2_9]</span>

<div align="center">⁂</div>

[^2_1]: https://red9.com/blog/install-dbatools-powershell-guide/

[^2_2]: https://dbatools.io/soup2nutz/

[^2_3]: https://dbatools.io/getting-started/

[^2_4]: https://www.sqlshack.com/dbatools-powershell-module-for-sql-server/

[^2_5]: https://dbatools.io

[^2_6]: https://learn.microsoft.com/en-us/powershell/sql-server/download-sql-server-ps-module?view=sqlserver-ps

[^2_7]: https://dbatools.io/commands/

[^2_8]: https://blog.ordix.de/how-do-i-install-the-powershell-module-dbatools

[^2_9]: https://blog.robsewell.com/blog/how-to-import-dbatools-from-a-zip-file-from-the-github-release-into-azure-automation-modules-without-an-error/

[^2_10]: https://dbatools.readthedocs.io/en/stable/readme.html

[^2_11]: https://blog.ordix.de/installation-and-use-of-dbatools-on-a-computer-without-internet-connection

[^2_12]: https://dbatools.io/Get-DbaModule/

[^2_13]: https://www.powershelluniversal.com/gallery/PowerShellUniversal.API.dbatools

[^2_14]: https://www.reddit.com/r/PowerShell/comments/a3fg4r/issues_installing_dbatools_module_from_powershell/

[^2_15]: https://thomaslarock.com/2017/04/install-module-dbatools/

[^2_16]: https://forums.powershell.org/t/dbatools-and-sql-server-connection-and-query/25090

[^2_17]: https://blog.netnerds.net/2023/04/offline-install-of-dbatools-and-dbatools-library/

[^2_18]: https://www.youtube.com/watch?v=Nw16SOqe5bI

[^2_19]: https://www.reddit.com/r/PowerShell/comments/13rki91/cant_get_to_install_sql_module_because_a_file_is/

[^2_20]: https://dbatools.io/install/

---

# Import-Module -Name dbatools -ErrorAction Stop

Exception: Couldn't import C:\Program Files\WindowsPowerShell\Modules\dbatools.library\2025.12.4\core\lib\Microsoft.Data.SqlClient.dll | Could not load file or assembly 'Microsoft.Data.SqlClient, Version=6.0.0.0, Culture=neutral, PublicKeyToken=23ec7fc2d6eaa4a5'. Assembly with same name is already loaded

That error comes from a version clash between `Microsoft.Data.SqlClient` that is already loaded in the runspace and the copy that dbatools.library is trying to load. The fix is to avoid loading a competing SqlClient assembly, or to unload it before importing dbatools.

## 1. Quick check: are you loading SqlServer or SqlClient first?

In the same session, running `Import-Module SqlServer` (or anything that loads its own Microsoft.Data.SqlClient) before dbatools is a known cause.[^3_1][^3_2]

- Make sure your script starts with:

```powershell
# Do this first in the session
Import-Module dbatools -ErrorAction Stop
```

- Avoid importing the `SqlServer` module (or other modules that bundle Microsoft.Data.SqlClient) in the same session, or only use one of them in that script.[^3_2][^3_1]

If you _must_ use both, dbatools maintainers recommend **importing dbatools first**.[^3_2]

## 2. Hard reset: start a fresh PowerShell session

Assemblies cannot be unloaded easily once loaded in Windows PowerShell 5.1, so if you’ve already loaded another `Microsoft.Data.SqlClient`:

1. Close that PowerShell window.
2. Open a new one.
3. Immediately run:

```powershell
Import-Module dbatools -ErrorAction Stop
```

If that works cleanly, the previous error was due to a previously loaded SqlClient assembly.

## 3. Advanced workaround (only if needed)

In PowerShell 7+ there are experimental workarounds where people enumerate loaded assemblies and try to unload or avoid the conflicting one before importing dbatools, but even dbatools maintainers treat this as fragile.[^3_3][^3_4]

Given your use case, the most reliable pattern is:

- Use **either** dbatools **or** SqlServer in a given script/session, not both, when possible.[^3_1][^3_2]
- If both are absolutely required, import **dbatools first** and keep all direct SqlClient work going through dbatools or the same Microsoft.Data.SqlClient version they ship.
  <span style="display:none">[^3_10][^3_11][^3_12][^3_13][^3_14][^3_15][^3_16][^3_17][^3_18][^3_19][^3_20][^3_5][^3_6][^3_7][^3_8][^3_9]</span>

<div align="center">⁂</div>

[^3_1]: https://stackoverflow.com/questions/77545580/upgrade-to-powershell-7-dbatools-2-causing-assembly-with-same-name-is-already

[^3_2]: https://github.com/dataplat/dbatools/issues/9019

[^3_3]: https://github.com/dataplat/dbatools/issues/9566

[^3_4]: https://github.com/dataplat/dbatools/issues/9379

[^3_5]: https://github.com/dataplat/dbatools/issues/9280

[^3_6]: https://github.com/dataplat/dbatools/issues/8195

[^3_7]: https://stackoverflow.com/questions/75337123/could-not-load-file-or-assembly-microsoft-data-sqlclient-version-5-0-0-0

[^3_8]: https://github.com/dataplat/dbatools/issues/3816

[^3_9]: https://github.com/dotnet/SqlClient/issues/2082

[^3_10]: https://github.com/dataplat/dbatools/issues/5989

[^3_11]: https://www.reddit.com/r/PowerShell/comments/160185w/assembly_with_same_name_is_already_loaded/

[^3_12]: https://github.com/dotnet/SqlClient/issues/2146

[^3_13]: https://www.reddit.com/r/PowerShell/comments/14vtudk/failing_to_connect_to_sql_server_using_dbatools/

[^3_14]: https://learn.microsoft.com/en-us/answers/questions/1366936/could-not-load-file-or-assemblymicrosoft-data-sqlc

[^3_15]: https://github.com/dotnet/SqlClient/issues/763

[^3_16]: https://www.reddit.com/r/SQLServer/comments/14eonow/unable_to_install_dbatools_modules_blocked_by/

[^3_17]: https://www.reddit.com/r/learnprogramming/comments/1cq0ucn/could_not_load_file_or_assembly/

[^3_18]: https://www.youtube.com/watch?v=vrcc5onPxzA

[^3_19]: https://www.reddit.com/r/PowerShell/comments/a3fg4r/issues_installing_dbatools_module_from_powershell/

[^3_20]: https://forum.uipath.com/t/unable-to-load-dll-microsoft-data-sqlclient-sni-dll-or-one-of-its-dependencies/731916

---

# in visual studio code, I use the extensions SQL :Language Server and SQL Server (mssql). Do either of these extensions load the SqlServer module into a terminal windows.

Neither of those VS Code SQL extensions automatically imports the `SqlServer` PowerShell module into your integrated terminal. They run their own SQL tooling (SQL Tools Service) inside extension processes, separate from whatever happens in a PowerShell terminal window.[^4_1][^4_2][^4_3]

In practice, the only things that will auto‑load `SqlServer` into a VS Code PowerShell terminal are:

- Your PowerShell profile scripts (e.g. `Microsoft.VSCode_profile.ps1`) if they contain `Import-Module SqlServer`.[^4_4][^4_5]
- Commands you explicitly run in that terminal (like `Import-Module SqlServer` or tools that call it via profile/custom scripts).[^4_6][^4_7]
  <span style="display:none">[^4_10][^4_11][^4_12][^4_13][^4_14][^4_15][^4_16][^4_17][^4_18][^4_19][^4_20][^4_8][^4_9]</span>

<div align="center">⁂</div>

[^4_1]: https://learn.microsoft.com/en-us/sql/tools/visual-studio-code-extensions/mssql/mssql-extension-visual-studio-code?view=sql-server-ver17

[^4_2]: https://code.visualstudio.com/docs/languages/tsql

[^4_3]: https://marketplace.visualstudio.com/items?itemName=ms-mssql.mssql

[^4_4]: https://stackoverflow.com/questions/63044750/connect-with-vscode-powershell-to-docker-sql-server-smo-ps-provider

[^4_5]: https://code.visualstudio.com/docs/languages/powershell

[^4_6]: https://learn.microsoft.com/en-us/powershell/sql-server/download-sql-server-ps-module?view=sqlserver-ps

[^4_7]: https://github.com/MicrosoftDocs/sql-docs/blob/live/docs/linux/sql-server-linux-manage-powershell-core.md

[^4_8]: https://www.reddit.com/r/SQLServer/comments/1j3d23w/roadmap_for_mssql_extension_on_vscode/

[^4_9]: https://www.sqlservercentral.com/articles/how-well-does-the-mssql-extension-in-vscode-work

[^4_10]: https://stackoverflow.com/questions/9714054/how-to-execute-sqlcmd-from-powershell

[^4_11]: https://voiceofthedba.com/2019/12/27/installing-powershell-for-sql-server-sqlnewblogger/

[^4_12]: https://stackoverflow.com/questions/59057118/visual-studio-code-mssql-extention-sql-server-mssql-unable-to-connect-to-se

[^4_13]: https://www.sqlshack.com/visual-studio-code-vs-code-for-sql-server-development/

[^4_14]: https://www.youtube.com/watch?v=CFwn2a-j_no

[^4_15]: https://forums.powershell.org/t/invoke-sqlcmd-suddenly-stopped-working/18760

[^4_16]: https://github.com/PowerShell/vscode-powershell

[^4_17]: https://community.spiceworks.com/t/running-sqlcmd-not-working-from-powershell/789382

[^4_18]: https://stackoverflow.com/questions/39829611/what-do-i-need-to-execute-a-sql-server-powershell-module

[^4_19]: https://docs.azure.cn/en-us/azure-sql/database/connect-query-vscode

[^4_20]: https://blog.robsewell.com/blog/running-sql-queries-with-visual-studio-code/

---

# How to check loaded PowerShell modules from VS Code terminal

From the VS Code integrated PowerShell terminal, you use the normal `Get-Module` cmdlet; VS Code does not change how module listing works.[^5_1][^5_2]

### Show modules currently loaded in the session

```powershell
Get-Module
```

This lists only the modules that are already imported into that terminal’s session.[^5_3][^5_1]

To look for a specific module (for example, `SqlServer` or `dbatools`):

```powershell
Get-Module SqlServer, dbatools
```

If nothing is returned, those modules are not currently loaded in that session.[^5_4][^5_1]

### Show all modules installed and available

```powershell
Get-Module -ListAvailable
```

This shows all modules VS Code’s PowerShell session could import from the paths in `$env:PSModulePath`.[^5_5][^5_1]
<span style="display:none">[^5_10][^5_11][^5_12][^5_13][^5_14][^5_15][^5_16][^5_17][^5_18][^5_19][^5_20][^5_6][^5_7][^5_8][^5_9]</span>

<div align="center">⁂</div>

[^5_1]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-module?view=powershell-7.5

[^5_2]: https://code.visualstudio.com/docs/languages/powershell

[^5_3]: https://www.c-sharpcorner.com/blogs/list-of-loaded-and-available-modules-in-powershell

[^5_4]: https://community.spiceworks.com/t/determine-if-a-module-was-imported/368461

[^5_5]: https://blog.ironmansoftware.com/daily-powershell/powershell-list-modules/

[^5_6]: https://learn.microsoft.com/en-us/powershell/module/powershellget/get-installedmodule?view=powershellget-2.x

[^5_7]: https://activedirectorypro.com/list-installed-powershell-modules/

[^5_8]: https://www.reddit.com/r/PowerShell/comments/y99gj4/trying_to_understand_module_location_in_vscode/

[^5_9]: https://www.reddit.com/r/PowerShell/comments/faxskd/how_to_get_the_available_commands_from_a/

[^5_10]: https://hpc-wiki.info/hpc/Modules

[^5_11]: https://www.reddit.com/r/PowerShell/comments/13kkf09/problem_using_custom_classes_loaded_from_a_module/

[^5_12]: https://stackoverflow.com/questions/10854746/how-do-i-find-the-module-for-a-given-cmdlet

[^5_13]: https://docs.oracle.com/en/operating-systems/oracle-linux/6/admin/modules-list.html

[^5_14]: https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/using-vscode?view=powershell-7.5

[^5_15]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Modules

[^5_16]: https://stackoverflow.com/questions/6354317/how-do-i-retrieve-the-available-commands-from-a-module

[^5_17]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-command?view=powershell-7.5

[^5_18]: https://stackoverflow.com/questions/76133548/powershell-psmodulepaths-missing-in-vscode

[^5_19]: https://learn.microsoft.com/en-us/powershell/module/powershellget/?view=powershellget-2.x

[^5_20]: https://redis.io/docs/latest/commands/module-list/

---

# get-module produced these two modules

Script 2025.2.0 PowerShellProTools {ConvertTo-WinForm, Merge-Script, Show-WinFormDesigner, Expand-…
Script 2024.12.0 PowerShellProTools.VSCode {Add-VSCodeTextDocumentText, Clear-VSCodeDecoration, Get-Comple…

look up those modules on theinternet, and see if any of them load SQLServer.

Those two modules do not automatically import `SqlServer` on their own; they are general PowerShell tooling, not SQL‑specific modules.[^6_1][^6_2]

## What the modules are

- `PowerShellProTools` – A commercial tooling module from Ironman Software that provides GUI designers, packaging, debugging, and related dev features for PowerShell.[^6_3][^6_1]
- `PowerShellProTools.VSCode` – The VS Code integration wrapper that wires those features into the editor (forms designer, module explorer, etc.).[^6_2][^6_4]

Neither module’s documented behavior or examples indicate an automatic `Import-Module SqlServer` or any built‑in dependency on the `SqlServer` module.[^6_5][^6_6]

## When SqlServer might still be involved

- PowerShell Pro Tools **can package scripts that themselves import `SqlServer`**, and its packager will detect that `Import-Module SqlServer` line and try to include the module.[^6_5]
- Blog content from the same vendor shows _examples_ that use both `dbatools` and `SqlServer`, but those are explicit `Install-Module` / `Import-Module` calls in user scripts, not something PowerShellProTools does automatically for you.[^6_6]

So: having `PowerShellProTools` and `PowerShellProTools.VSCode` loaded in your VS Code terminal does not, by itself, mean the `SqlServer` module has been imported; you still need to call `Import-Module SqlServer` (or run a script that does) before it will be loaded.
<span style="display:none">[^6_10][^6_11][^6_12][^6_13][^6_14][^6_15][^6_16][^6_17][^6_18][^6_19][^6_20][^6_7][^6_8][^6_9]</span>

<div align="center">⁂</div>

[^6_1]: https://github.com/luke-beep/awesome-powershell

[^6_2]: https://forums.ironmansoftware.com/t/attempting-to-run-powershell-tools-on-visual-studio-code-produces-error/2025

[^6_3]: https://www.sqlservercentral.com/blogs/using-visual-studio-code

[^6_4]: https://gmwteam.rssing.com/chan-74535104/all_p12.html

[^6_5]: https://forums.ironmansoftware.com/t/package-modules-is-not-packaging-modules/2631

[^6_6]: https://blog.ironmansoftware.com/daily-powershell/powershell-query-sql/

[^6_7]: https://stackoverflow.com/questions/51492224/powershell-pro-tools-multiple-forms-not-running-as-expected

[^6_8]: https://www.youtube.com/watch?v=is3RfrZoKVc

[^6_9]: https://stackoverflow.com/questions/38315406/powershell-sqlserver-modules/52324891

[^6_10]: https://stackoverflow.com/questions/78037166/how-to-use-vs-codes-sqltools-extension-to-log-in-to-a-sql-server-database-with

[^6_11]: https://www.reddit.com/r/PowerShell/comments/11lvjna/sysadmins_what_script_are_you_running_to_help/

[^6_12]: https://www.sqlservercentral.com/blogs/installing-powershell-for-sql-server-sqlnewblogger

[^6_13]: https://www.mssqltips.com/sqlservertip/11546/sql-server-local-containers-with-vscode-mssql-extension/

[^6_14]: https://www.reddit.com/r/PowerShell/comments/11nmz04/how_to_import_powershell_modules_like_a_boss/

[^6_15]: https://www.reddit.com/r/PowerShell/comments/1i42lpx/powershell_pro_tools_for_vs_code_thoughts_from/

[^6_16]: https://psweekly.dowst.dev/2022/04/

[^6_17]: https://code.visualstudio.com/docs/languages/powershell

[^6_18]: https://www.reddit.com/r/PowerShell/comments/131apdo/learning_powershell/

[^6_19]: https://learn.microsoft.com/en-us/sql/tools/visual-studio-code-extensions/mssql/mssql-extension-visual-studio-code?view=sql-server-ver17

[^6_20]: https://forums.ironmansoftware.com/t/modules-explorer-not-actually-updating-modules/5406
