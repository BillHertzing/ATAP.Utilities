# Attribution of ideas

The maintainers and contributors to this repository feel it is important to credit the individuals and organizations who have taken their time to publish ideas and guides. This document provides a place to mention ALL of the works that have influenced the design and implementation of the repository's content.

## Documentation

### Creation of a repository or project's ReadMe file

- https://github.com/noffle/art-of-readme
- https://github.com/jehna/readme-best-practices
- https://blog.algorithmia.com/github-readme-analyzer/

### Creation of a repository's documentation site

- https://visualstudiomagazine.com/articles/2017/02/21/vs-dotnet-code-documentation-tools-roundup.aspx
- https://dotnet.github.io/docfx/

### DocFx

<tbd> this should someday be created by a docfx merge plugin, to merge Attribution.md files found in each project, up to a master Attribution.html
<fyi, all the attribution lines are currently done manually (cut'n'paste)>
<multitude of docfx.json files from other early adopter's sites>

- https://github.com/docascode/docfx-seed/blob/master/docfx.json
- https://github.com/wekempf/testify/blob/develop/docs/docfx.json
- https://github.com/googleapis/google-cloud-dotnet/blob/master/docs/root/docfx.json
- https://github.com/SixLabors/docs/blob/master/docfx.json
- https://dzone.com/articles/generating-documentation-with-docfx-as-part-of-a-v

### Adding triple-Slash \(///) comments to code

- https://submain.com/products/ghostdoc.aspx \* Commercial editions as well as free community version

## Visual Studio

### Doing Builds

#### Build Logging

- Project System Tools (Structured MSBUILD log viewer) https://marketplace.visualstudio.com/items?itemName=VisualStudioProductTeam.ProjectSystemTools and http://msbuildlog.com/

#### New Project System for MSBuild

- https://github.com/dotnet/project-system/blob/master/docs/opening-with-new-project-system.md"

#### Builds in Docker

- https://natemcmaster.com/blog/2018/05/12/dotnet-watch-2.1/ Indicates need to add to .csproj. Then implies obj and bin(!) need subdirs of /local and /container

### Packing into NuGet packages

#### Packing Libraries

##### Library Versioning

These libraries use the following attributes for versioning
_ AssemblyInfo - <tbd> insert link for Semantic versioning
_ AssemblyFileInfo - <tbd> insert link for date since ? and secs/midnight / 2 \* AssemblyInformational - <tbd> insert links that show how modern NuGet resolves the third part in alphabetical order, so alpha resolve before beta, qa, rc, rtm, etc. tbd - link to the BuildTooling documentation in tyhis repository that provides the targets and tasks that update the version during a build if necessary.

##### Library Dependencies

##### Development Versioning and LocalFeed

#### Packing the BuildTools Assemblies

##### BuildTool Versioning

##### BuildTool Dependencies

##### Installing Executables in the user's .nuget

##### Installing PowerShell Scripts in the user's .nuget

##### Installing Documentation for the BuildTools and configuring Visual Studio to recognize it

##### Development Versioning and LocalFeed

#### Packing the Blazor-SserviceStack Examples Assemblies

##### App Versioning

##### App Dependencies

##### Chocolatey Installation script

##### Chocolatey Installation configuration

##### Development Versioning and LocalFeed

[Bundling .NET build tools in NuGet](https://natemcmaster.com/blog/2017/11/11/build-tools-in-nuget/)

[Contents tagged with Category Theory](https://weblogs.asp.net/dixin/Tags/Category%20Theory)
[Category Theory via C# (7) Monad and LINQ to Monads](https://weblogs.asp.net/dixin/category-theory-via-csharp-7-monad-and-linq-to-monads)

#### C#

[Cleaner Code With Swtich Expressions In C#](https://www.conradakunga.com/blog/cleaner-code-with-swtich-expressions-in-c/)
[LINQExample](https://github.com/ssukhpinder/LINQExample)
[How to combine LINQ queries with regular expressions (C#)](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/concepts/linq/how-to-combine-linq-queries-with-regular-expressions)

#### powershell

[High Performance PowerShell with LINQ](https://www.red-gate.com/simple-talk/development/dotnet-development/high-performance-powershell-linq/]
[Let’s play with Strings & LINQ](https://medium.com/c-sharp-progarmming/learn-linq-by-example-9c4221ffcdbf)
[Executing LINQ Queries in PowerShell – Part 2](https://powershell.org/2018/05/executing-linq-queries-in-powershell-part-2/)

#### Everything

[Really Useful Set of Bookmark Searches 2.1 for Everything](https://www.voidtools.com/forum/viewtopic.php?t=4239)

# Obsolete

The following links are to projects or articles no longer included in the solution. However, they were considered relevant at one time, and certainly will contain information worth reviewing.

MSBump: Used for automatic build number bumping and Nuget Package versioning https://github.com/BalassaMarton/MSBump

---

## Section 3.3.3 – Flyway Database Migration Management (Dev/Build/Repo Toolchain)

Sources for the Flyway OSS 10.21.0 configuration reference, environment-variable naming rules, placeholder usage, and repeatable-migration pitfalls documented in Module Catalog Section 3.3.3.

### Official Flyway Documentation (Redgate)

- [Flyway Reference – Environment Variables](https://documentation.red-gate.com/flyway/reference/environment-variables)
- [Flyway Reference – Command-Line Parameters](https://documentation.red-gate.com/flyway/reference/command-line-parameters)
- [Flyway CLI – Command-Line Parameters (fd)](https://documentation.red-gate.com/fd/command-line-parameters-277578836.html)
- [Flyway CLI – Command-Line (fd)](https://documentation.red-gate.com/fd/command-line-277579359.html)
- [Flyway – Environments (fd)](https://documentation.red-gate.com/fd/environments-273973424.html)
- [Flyway – Environment Variables (fd)](https://documentation.red-gate.com/fd/environment-variables-224003080.html)
- [Flyway – Migration Placeholders (fd)](https://documentation.red-gate.com/fd/migration-placeholders-275218550.html)
- [Flyway CLI & API – Placeholders Parameter](https://documentation.red-gate.com/flyway/flyway-cli-and-api/configuration/parameters/flyway/placeholders)
- [Flyway – Concepts: Environments](https://documentation.red-gate.com/flyway/flyway-concepts/environments)
- [Flyway – Output Query Results Setting](https://documentation.red-gate.com/fd/flyway-output-query-results-setting-277579016.html)

### Flyway GitHub Source / Documentation

- [Flyway GitHub – Configuration: Environment Variables](https://github.com/flyway/flyway/blob/main/documentation/Flyway%20CLI%20and%20API/Configuration/Environment%20Variables.md)
- [Flyway GitHub – Configuration: Parameters](https://github.com/flyway/flyway/blob/main/documentation/Flyway%20CLI%20and%20API/Configuration/Parameters.md)
- [flywaydb.org – Configuration config file](https://github.com/flyway/flywaydb.org/blob/gh-pages/documentation/configuration/configfile.md)
- [flywaydb.org – Command-line usage](https://github.com/flyway/flywaydb.org/blob/gh-pages/documentation/usage/commandline/index.md)
- [flywaydb.org – Configuration parameters index](https://github.com/flyway/flywaydb.org/blob/gh-pages/documentation/configuration/parameters/index.md)

### Redgate Hub Learning Articles

- [Making Full Use of Environment Variables for Flyway Settings](https://www.red-gate.com/hub/product-learning/flyway/making-full-use-of-environment-variables-for-flyway-settings)
- [Installing and Upgrading the Flyway CLI](https://www.red-gate.com/hub/product-learning/flyway/installing-and-upgrading-the-flyway-cli)
- [Finding the Version of a Flyway-Managed Database](https://www.red-gate.com/hub/product-learning/flyway/finding-the-version-of-a-flyway-managed-database)
- [The Flyway Info Command Explained Simply](https://www.red-gate.com/hub/product-learning/flyway/the-flyway-info-command-explained-simply)
- [Passing Parameters and Settings to Flyway Scripts](https://www.red-gate.com/hub/product-learning/flyway/passing-parameters-and-settings-to-flyway-scripts)

### Stack Overflow

- [Flyway migrations fail when passing environment variables to Docker](https://stackoverflow.com/questions/61050413/flyway-migrations-fails-when-passing-environment-variables-to-docker)
- [How to use environment variables in Flyway config file](https://stackoverflow.com/questions/74543518/how-to-use-environment-variables-in-flyway-config-file)
- [How do I get the Flyway version number of a database?](https://stackoverflow.com/questions/48230507/how-do-i-get-the-flyway-version-number-of-a-database)
- [Purpose of placeholders in Flyway database migrations](https://stackoverflow.com/questions/44252696/purpose-of-placeholders-in-flyway-database-migrations)
- [How do placeholders work in Flyway?](https://stackoverflow.com/questions/9418173/how-do-placeholders-work-in-flyway)
- [Flyway migration schema version](https://stackoverflow.com/questions/33677026/flyway-migration-schema-version)

### Tutorials and Guides

- [Flyway in the Command Line (jDriven, 2025)](https://jdriven.com/blog/2025/04/Flyway-in-the-command-line)
- [Flyway Guide – Neon](https://neon.com/docs/guides/flyway)
- [Database Versioning and Migrations for Everyone Using Flyway](https://jilles.me/database-versioning-and-migrations-for-everyone-using-flyway/)
- [Friday Flyway Tips – Flyway Parameters (Voice of the DBA)](https://voiceofthedba.com/2023/09/22/friday-flyway-tips-flyway-parameters/)
- [Making Full Use of Environment Variables – Flyway (Opsmatters video)](https://www.opsmatters.com/videos/making-full-use-environment-variables-flyway-tony-and-tonie-show)
- [Quarkus Flyway Guide](https://quarkus.io/guides/flyway)

### Videos (YouTube)

- [Flyway and environment variables (YouTube)](https://www.youtube.com/watch?v=uvGNB57xcH0)
- [Flyway parameters deep dive (YouTube)](https://www.youtube.com/watch?v=K7mdHjMh46U)
- [Flyway output and results (YouTube)](https://www.youtube.com/watch?v=mYE_omHLM_A)

---

## Section 2.4 – VS Code Multi-AI Extension, GitHub Copilot, and AI Services

Sources for the Copilot token usage monitoring, Copilot coding agent pull request workflow, Copilot plan management, Claude Code Windows installation, and AI service subscription reference material documented in Module Catalog Sections 2.4.4–2.4.7.

### 2.4.4 – Copilot Token Usage Monitoring and Plan Management

#### GitHub Community Discussions

- [No built-in way to see token usage per conversation in GitHub Copilot Chat](https://github.com/orgs/community/discussions/169702)
- [Community discussion: Copilot doesn't show token usage stats](https://github.com/orgs/community/discussions/168800)
- [Copilot Business and Enterprise plan limits (community)](https://github.com/orgs/community/discussions/164101)

#### GitHub / Microsoft Issue Trackers

- [VS Code feature request: Real-time Token Usage Display for GitHub Copilot](https://github.com/microsoft/vscode/issues/251807)
- [How to change GitHub Copilot settings in VS Code to increase the token limit](https://stackoverflow.com/questions/77842786/how-to-change-github-copilot-settings-in-vscode-to-increase-the-token-limit-to-4)

#### GitHub Official Documentation

- [Monitoring your Copilot usage and entitlements](https://docs.github.com/copilot/how-tos/monitoring-your-copilot-usage-and-entitlements)
- [View and change your Copilot plan](https://docs.github.com/en/copilot/how-tos/manage-your-account/view-and-change-your-copilot-plan)
- [Billing for individuals – GitHub Copilot](https://docs.github.com/en/copilot/concepts/billing/billing-for-individuals)

#### Reddit

- [How to track Copilot usage – GitHub Copilot subreddit](https://www.reddit.com/r/GithubCopilot/comments/1lei9yw/how_to_track_my_usage_now_github_copilot/)
- [How to get token usages in GitHub Copilot Chat](https://www.reddit.com/r/GithubCopilot/comments/1oc61nh/how_to_get_token_usages_in_github_copilot_chat_or/)
- [GitHub Copilot Usage Tracker (CLI)](https://www.reddit.com/r/opencodeCLI/comments/1qga256/github_copilot_usage_tracker/)
- [I made a GitHub Copilot usage tracker](https://www.reddit.com/r/GithubCopilot/comments/1qhlim2/i_made_a_github_copilot_usage_tracker/)
- [Copilot Business and Copilot Enterprise plans (rate limits)](https://www.reddit.com/r/ChatGPTCoding/comments/1jj6zh6/copilot_business_and_copilot_enterprise_plans/)

### 2.4.5 – Copilot Coding Agent: Pull Request Workflow

#### GitHub / VS Code Official Documentation

- [VS Code Copilot coding agent](https://code.visualstudio.com/docs/copilot/copilot-coding-agent)
- [GitHub Copilot: Create a PR with the coding agent](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-a-pr)
- [About the Copilot coding agent](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent)
- [GitHub Enterprise: Create a PR with the coding agent](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/use-copilot-agents/coding-agent/create-a-pr)
- [Reviewing proposed changes in a pull request](https://docs.github.com/articles/reviewing-proposed-changes-in-a-pull-request)
- [VS Code Copilot smart actions](https://code.visualstudio.com/docs/copilot/copilot-smart-actions)

### 2.4.6 – Claude Code: Windows Installation

#### Official Documentation

- [Claude Code setup (code.claude.com)](https://code.claude.com/docs/en/setup)
- [Claude Code troubleshooting (code.claude.com)](https://code.claude.com/docs/en/troubleshooting)
- [Claude Code quickstart](https://code.claude.com/docs/en/quickstart)

#### Community

- [Installing Claude Code CLI on Windows (blog)](https://vincenzopirozzi.substack.com/p/installing-claude-code-cli-on-windows)
- [How to run Claude Code on Windows (Reddit)](https://www.reddit.com/r/ClaudeAI/comments/1l89j30/this_is_how_i_managed_to_run_claude_code_on/)
- [Install Claude Code on Windows without WSL (Reddit)](https://www.reddit.com/r/ClaudeAI/comments/1lbrils/install_claude_code_on_windows_without_wsl/)
- [GitHub Issue: Claude Code install path on Windows](https://github.com/anthropics/claude-code/issues/14942)
- [Where is Claude Code installed? (claudelog FAQ)](https://www.claudelog.com/faqs/where-is-claude-code-installed/)

### 2.4.7 – AI Service Subscription Reference (Google One / Google AI Plans)

- [Google One – about page](https://one.google.com/about/)
- [Google AI Plans](https://one.google.com/about/google-ai-plans/)
- [What is Google One AI Premium? (How-To Geek)](https://www.howtogeek.com/what-is-google-one-ai-premium/)
- [What is Google One? (Wired)](https://www.wired.com/story/what-is-google-one/)
- [Reddit: What's the difference between Google One Premium and Google AI plans?](https://www.reddit.com/r/GoogleOne/comments/1p5da6f/whats_the_difference_between_google_one_premium/)
- [Reddit: Google One Premium 2 TB plan changes](https://www.reddit.com/r/GoogleOne/comments/1pd6bqd/your_google_one_premium_2_tb_plan_has_been/)
- [YouTube: Google AI Plans explained](https://www.youtube.com/watch?v=iobcFFxgpNQ)

---

## Section 3.3.4 – Dev/Build/Repo Toolchain: GitHub Issue & Branch Workflow

Sources for the GitHub issue-to-branch workflow documented in Module Catalog Section 3.3.4.

### GitHub Official Documentation

- [Creating a branch for an issue (GitHub Docs)](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-a-branch-for-an-issue)
- [Creating and deleting branches within your repository](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-and-deleting-branches-within-your-repository)
- [VS Code Branches and Worktrees](https://code.visualstudio.com/docs/sourcecontrol/branches-workTrees)
- [GitHub changelog: Create a branch for an issue (2022)](https://github.blog/changelog/2022-03-01-create-a-branch-for-an-issue/)
- [GitHub Docs Enterprise Server 3.11: Creating a branch for an issue](https://docs.github.com/en/enterprise-server@3.11/issues/tracking-your-work-with-issues/using-issues/creating-a-branch-for-an-issue)

### Community & Stack Overflow

- [Stack Overflow: Create new branch from the issue](https://stackoverflow.com/questions/41614421/create-new-branch-from-the-issue)
- [GitHub Community: Creating and switching branches in VS Code](https://github.com/orgs/community/discussions/89927)
- [GitHub CLI gist: gh issue develop usage](https://gist.github.com/devinschumacher/ea416af5542ac7102c8e1ffd0ab38a99)
- [Reddit: Issue with creating branch in VS Code](https://www.reddit.com/r/vscode/comments/1bdwjzr/issue_with_creating_branch/)

---

## Section 3.3.5 – Dev/Build/Repo Toolchain: Jenkins and ProGet Role Comparison

Sources for the Jenkins vs. ProGet toolchain distinction and typical integration pipeline documented in Module Catalog Section 3.3.5.

### Official Product Documentation

- [Jenkins Pipeline Steps reference](https://www.jenkins.io/doc/pipeline/steps/)
- [ProGet product overview (Inedo)](https://inedo.com/proget)
- [ProGet feature list (Inedo)](https://inedo.com/proget/features)
- [ProGet SCA API](https://docs.inedo.com/docs/proget-sca-api)
- [ProGet SCA Projects & Releases](https://docs.inedo.com/docs/proget-sca-projects-releases)
- [BuildMaster overview (Inedo)](https://docs.inedo.com/docs/buildmaster-overview)
- [BuildMaster features](https://inedo.com/buildmaster/features)
- [BuildMaster integrations: Jenkins](https://docs.inedo.com/docs/buildmaster-integrations-jenkins)
- [BuildMaster build scripts](https://docs.inedo.com/docs/buildmaster-build-scripts)
- [BuildMaster OtterScript overview](https://docs.inedo.com/docs/buildmaster-otterscript-overview)
- [BuildMaster OtterScript operations](https://docs.inedo.com/docs/otter-otterscript-and-operations)
- [BuildMaster scripts reference](https://docs.inedo.com/docs/buildmaster-scripts)

### Blog Articles

- [Universal Packages in ProGet with Jenkins (Inedo blog)](https://blog.inedo.com/jenkins/universal-packages-in-proget)
- [Jenkins vs BuildMaster (Inedo blog)](https://blog.inedo.com/jenkins/jenkins-vs-buildmaster)
- [Repository showdown: Artifactory vs Nexus vs ProGet](https://blog.packagecloud.io/repository-showdown-artifactory-vs-nexus-vs-proget/)

### Community & Stack Overflow

- [TrustRadius: Jenkins vs ProGet comparison](https://www.trustradius.com/compare-products/jenkins-vs-proget)
- [Reddit: From zero to a Docker app using Jenkins and ProGet](https://www.reddit.com/r/selfhosted/comments/nudv3g/from_zero_to_a_docker_app_using_jenkins_proget/)
- [Stack Overflow: Differences between Jenkins project types](https://stackoverflow.com/questions/60861091/differences-between-jenkins-projects)
- [Inedo forums: ProGet Jenkins plugin on slave agents](https://forums.inedo.com/topic/1502/proget-jenkins-plugin-not-working-on-slaves)
- [Wikipedia: ProGet](https://en.wikipedia.org/wiki/ProGet)

---

## Section 3.3.6 – Dev/Build/Repo Toolchain: PowerShell Database Connectivity (dbatools & SqlClient)

Sources for the SQL Server connection string builder library survey, dbatools install/import patterns, Microsoft.Data.SqlClient DLL version-conflict resolution, VS Code SQL extension module-loading behavior, and PowerShell module inspection guidance documented in Module Catalog Section 3.3.6.

### dbatools – Official Documentation and Installation

- [dbatools: New-DbaConnectionStringBuilder](https://dbatools.io/New-DbaConnectionStringBuilder/)
- [dbatools: PowerShell Gallery source for New-DbaConnectionStringBuilder](https://www.powershellgallery.com/packages/dbatools/1.1.54/Content/functions\New-DbaConnectionStringBuilder.ps1)
- [dbatools: Getting Started](https://dbatools.io/getting-started/)
- [dbatools: Install guide](https://dbatools.io/install/)
- [dbatools: Soup to Nuts install walkthrough](https://dbatools.io/soup2nutz/)
- [dbatools: Command reference](https://dbatools.io/commands/)
- [Red9: Install dbatools PowerShell guide](https://red9.com/blog/install-dbatools-powershell-guide/)
- [Ordix: How to install the PowerShell module dbatools](https://blog.ordix.de/how-do-i-install-the-powershell-module-dbatools)
- [Ordix: Installation without internet connection](https://blog.ordix.de/installation-and-use-of-dbatools-on-a-computer-without-internet-connection)
- [Rob Sewell: Import dbatools from a zip file / GitHub release into Azure Automation](https://blog.robsewell.com/blog/how-to-import-dbatools-from-a-zip-file-from-the-github-release-into-azure-automation-modules-without-an-error/)
- [netnerds: Offline install of dbatools and dbatools-library](https://blog.netnerds.net/2023/04/offline-install-of-dbatools-and-dbatools-library/)
- [SQLShack: dbatools PowerShell module for SQL Server](https://www.sqlshack.com/dbatools-powershell-module-for-sql-server/)
- [Thomas LaRock: Install-Module dbatools](https://thomaslarock.com/2017/04/install-module-dbatools/)

### Connection String Builder Libraries

- [Microsoft.Data.SqlClient.SqlConnectionStringBuilder (Microsoft Docs)](https://learn.microsoft.com/en-us/dotnet/api/microsoft.data.sqlclient.sqlconnectionstringbuilder?view=sqlclient-dotnet-core-6.1)
- [ADO.NET Connection String Builders (Microsoft Docs)](https://learn.microsoft.com/en-us/sql/connect/ado-net/connection-string-builders?view=sql-server-ver17)
- [System.Data.SqlClient.SqlConnectionStringBuilder – .NET Framework 4.8](https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlconnectionstringbuilder?view=netframework-4.8.1)
- [ADO.NET Connection String Builders – .NET Framework](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/connection-string-builders)
- [DatabaseWrapper (jchristn/DatabaseWrapper) – GitHub](https://github.com/jchristn/DatabaseWrapper)
- [Aireforge SQL Server Connection String Generator](https://www.aireforge.com/tools/sql-server-connection-string-generator)
- [Microsoft Elastic DB Tools for Java – SqlConnectionStringBuilder](https://github.com/microsoft/elastic-db-tools-for-java/blob/master/elastic-db-tools/src/main/java/com/microsoft/azure/elasticdb/shard/sqlstore/SqlConnectionStringBuilder.java)
- [JDBC SQL Server connection string reference (Beekeeper Studio)](https://www.beekeeperstudio.io/blog/jdbc-sql-server-connection-string)
- [connectionstrings.com – SQL Server](https://www.connectionstrings.com/sql-server/)

### Microsoft.Data.SqlClient DLL Version Conflict

- [Stack Overflow: Upgrade to PowerShell 7 – dbatools 2 causing "assembly with same name is already loaded"](https://stackoverflow.com/questions/77545580/upgrade-to-powershell-7-dbatools-2-causing-assembly-with-same-name-is-already)
- [dataplat/dbatools GitHub issue #9019 – SqlClient version conflict](https://github.com/dataplat/dbatools/issues/9019)
- [dataplat/dbatools GitHub issue #9566 – PS7+ workaround attempts](https://github.com/dataplat/dbatools/issues/9566)
- [dataplat/dbatools GitHub issue #9379 – assembly unload fragility](https://github.com/dataplat/dbatools/issues/9379)
- [dataplat/dbatools GitHub issue #9280](https://github.com/dataplat/dbatools/issues/9280)
- [dataplat/dbatools GitHub issue #8195](https://github.com/dataplat/dbatools/issues/8195)
- [Stack Overflow: Could not load file or assembly Microsoft.Data.SqlClient Version 5.0.0.0](https://stackoverflow.com/questions/75337123/could-not-load-file-or-assembly-microsoft-data-sqlclient-version-5-0-0-0)
- [Reddit: Assembly with same name is already loaded](https://www.reddit.com/r/PowerShell/comments/160185w/assembly_with_same_name_is_already_loaded/)

### VS Code SQL Extensions and PowerShell Module Loading

- [mssql extension for VS Code (Microsoft Docs)](https://learn.microsoft.com/en-us/sql/tools/visual-studio-code-extensions/mssql/mssql-extension-visual-studio-code?view=sql-server-ver17)
- [VS Code – Working with T-SQL](https://code.visualstudio.com/docs/languages/tsql)
- [mssql on VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=ms-mssql.mssql)
- [Download SQL Server PowerShell module (Microsoft Docs)](https://learn.microsoft.com/en-us/powershell/sql-server/download-sql-server-ps-module?view=sqlserver-ps)
- [VS Code – PowerShell language guide](https://code.visualstudio.com/docs/languages/powershell)
- [PowerShell Pro Tools – Ironman Software forums](https://forums.ironmansoftware.com/t/attempting-to-run-powershell-tools-on-visual-studio-code-produces-error/2025)
- [PowerShellProTools packaging modules (Ironman forums)](https://forums.ironmansoftware.com/t/package-modules-is-not-packaging-modules/2631)
- [Ironman Software blog: PowerShell Query SQL](https://blog.ironmansoftware.com/daily-powershell/powershell-query-sql/)

### Inspecting Loaded PowerShell Modules

- [Get-Module cmdlet (PowerShell Docs)](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/get-module?view=powershell-7.5)
- [Get-InstalledModule (PowerShellGet)](https://learn.microsoft.com/en-us/powershell/module/powershellget/get-installedmodule?view=powershellget-2.x)
- [Determine if a module was imported (Spiceworks community)](https://community.spiceworks.com/t/determine-if-a-module-was-imported/368461)
- [List installed PowerShell modules (Active Directory Pro)](https://activedirectorypro.com/list-installed-powershell-modules/)
- [Ironman Software blog: PowerShell list modules](https://blog.ironmansoftware.com/daily-powershell/powershell-list-modules/)
- [Stack Overflow: PSModulePaths missing in VS Code](https://stackoverflow.com/questions/76133548/powershell-psmodulepaths-missing-in-vscode)

---

## Section 3.3.7 – Dev/Build/Repo Toolchain: VS Code C# Build Configuration (tasks.json and launch.json)

Sources for the minimal `.csproj` class library setup, `tasks.json` build entry, and `launch.json` `preLaunchTask` wiring documented in Module Catalog Section 3.3.7.

### Microsoft Official Documentation

- [Create a .NET class library using Visual Studio Code](https://learn.microsoft.com/en-us/dotnet/core/tutorials/library-with-visual-studio-code)
- [C# build tools in VS Code](https://code.visualstudio.com/docs/csharp/build-tools)
- [Get started with C# and Visual Studio Code](https://code.visualstudio.com/docs/csharp/get-started)
- [VS Code Debugging Configuration](https://code.visualstudio.com/docs/debugtest/debugging-configuration)
- [VS Code Tasks reference](https://code.visualstudio.com/docs/debugtest/tasks)
- [Create a .NET class library using Visual Studio (Microsoft Docs)](https://learn.microsoft.com/en-us/dotnet/core/tutorials/library-with-visual-studio)

### Stack Overflow

- [In .NET Core is it possible to create a library project that does not reference other projects](https://stackoverflow.com/questions/68076892/in-dotnet-core-is-it-possible-to-create-a-library-project-that-does-not-referen)
- [VS Code build script configuration to build class library](https://stackoverflow.com/questions/74780048/vscode-build-script-configuration-to-build-class-library)
- [How to configure JSON options for C# to debug console app in internal terminal](https://stackoverflow.com/questions/77854353/how-to-configure-json-options-for-c-sharp-to-debug-console-app-in-internal-term)
- [VS Code for C# – doesn't generate launch.json and tasks.json](https://stackoverflow.com/questions/75572318/problem-on-configuring-vscode-for-c-it-doesnt-generate-launch-json-and-tasks)
- [Convert C# class to DLL file in Visual Studio Code](https://stackoverflow.com/questions/76341485/convert-c-sharp-class-to-dll-file-in-visual-studio-code)
- [Creating a DLL file in C# .NET](https://stackoverflow.com/questions/15567893/creating-a-dll-file-in-c-net)

### Community Articles and Guides

- [How to build a .NET Core project with VS Code (joffreykern)](https://joffreykern.github.io/blog/how-to-build-dotnet-core-project-with-vs-code)
- [Create a C# class library DLL (bradwellsb / dev.to)](https://dev.to/bradwellsb/create-a-c-class-library-dll-3cbb)
- [Creating and Using DLL Class Library in C# (GeeksforGeeks)](https://www.geeksforgeeks.org/c-sharp/creating-and-using-dll-class-library-in-c/)
- [VS Code defining tasks.json for debugging (fsharp forums)](https://forums.fsharp.org/t/vs-code-defining-tasks-json-for-debugging/3352)
- [Arch Linux BBS: .NET debugging in VS Code](https://bbs.archlinux.org/viewtopic.php?id=261729)

### Videos

- [Building .NET projects in VS Code (YouTube)](https://www.youtube.com/watch?v=DAsyjpqhDp4)
- [C# Class Library DLL walkthrough (YouTube)](https://www.youtube.com/watch?v=6Y63Tg1GDbs)
- [Using dotnet build / launch in VS Code (YouTube)](https://www.youtube.com/watch?v=MPOuci-6amQ)

---

## Section 3.3.8 – Dev/Build/Repo Toolchain: Multi-Project Repository Structure and Aggregator Libraries

Sources for the aggregator `.csproj` pattern, `<ProjectReference>` / `<Reference HintPath>` usage, NuGet single-package bundling, and multi-project repository structure documented in Module Catalog Section 3.3.8.

### Microsoft Official Documentation

- [Common MSBuild project items (ProjectReference)](https://learn.microsoft.com/en-us/visualstudio/msbuild/common-msbuild-project-items?view=visualstudio)
- [dotnet pack command](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-pack)
- [Package references in project files (PackageReference)](https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files)
- [Merge all class into single class (Microsoft Q&A)](https://learn.microsoft.com/en-us/answers/questions/992281/merge-all-class-into-single-class)
- [dotnet pack (Microsoft Docs – dynamics-usd-3 view)](https://learn.microsoft.com/th-th/dotnet/core/tools/dotnet-pack?view=dynamics-usd-3)

### Stack Overflow

- [dotnet pack / NuGet pack: how to simply pack multiple projects into one package](https://stackoverflow.com/questions/78672095/dotnet-pack-nuget-pack-how-to-simply-pack-multiple-projects-into-one-package)
- [How to make a condition to add reference when there are many project references](https://stackoverflow.com/questions/76048606/how-can-i-make-a-condition-to-add-reference-when-i-have-many-project-references)
- [How to merge multiple .NET Core assemblies into a single DLL/exe](https://stackoverflow.com/questions/52320592/how-to-merge-multiple-net-core-assemblies-into-a-single-one-dll-exe/52320733)
- [How to merge all DLL files of a class library as one DLL (.NET Framework)](https://stackoverflow.com/questions/67331722/how-to-merge-all-dll-files-of-a-class-library-as-one-dll-net-framework)
- [How to merge DLLs into one DLL](https://stackoverflow.com/questions/28932074/how-to-merge-dlls-into-one-dll)

### Community Articles and Guides

- [Multiple NuGet packages from a single repo (markheath.net)](https://markheath.net/post/multiple-nuget-single-repo)
- [Include both NuGet package references and project reference DLLs using dotnet pack (dev.to/yerac)](https://dev.to/yerac/include-both-nuget-package-references-and-project-reference-dll-using-dotnet-pack-2d8p)
- [dotnet-pack-multilib (mwyrebski / GitHub)](https://github.com/mwyrebski/dotnet-pack-multilib)
- [dotnet/sdk issue #8313 – pack multiple projects](https://github.com/dotnet/sdk/issues/8313)
- [dotnet/roslyn discussion #47517 – multi-project output](https://github.com/dotnet/roslyn/discussions/47517)

### Reddit

- [NuGet package of multiple projects (r/dotnet)](https://www.reddit.com/r/dotnet/comments/ogcquf/nugget_package_of_multiple_projects/)
- [How to reference DLL from another project (r/csharp)](https://www.reddit.com/r/csharp/comments/kf4ien/how_to_reference_dll_from_another_project/)
- [Help bundling several DLL files into one DLL (r/csharp)](https://www.reddit.com/r/csharp/comments/6jl0z9/help_bundling_several_dll_files_into_one_dll/)
- [Multiple projects in SLN – where to install (r/dotnet)](https://www.reddit.com/r/dotnet/comments/w0wrnr/multiple_projects_in_sln_where_to_install/)

---

## Section 3.3.9 – Dev/Build/Repo Toolchain: Secrets Management with Bitwarden CLI and PowerShell SecretManagement

Sources for the Bitwarden SecretManagement extension `match`-property bug analysis and workaround, the CI/CD headless unlock pattern for Jenkins service accounts, and the VS Code `BW_SESSION` inheritance workflow documented in Module Catalog Section 3.3.9.

### Bitwarden CLI Official Documentation

- [Bitwarden CLI reference (bitwarden.com)](https://bitwarden.com/help/cli/)
- [Bitwarden CLI secrets manager reference](https://bitwarden.com/help/secrets-manager-cli/)

### PowerShell SecretManagement Extensions

- [SecretManagement.Warden – GitHub (marshallwp)](https://github.com/marshallwp/SecretManagement.Warden)
- [SecretManagement.Warden 1.1.3 – PSGallery source: Invoke-BitwardenCLI.ps1](https://www.powershellgallery.com/packages/SecretManagement.Warden/1.1.3/Content/SecretManagement.Warden.Extension\private\Invoke-BitwardenCLI.ps1)
- [SecretManagement.BitWarden 0.1.1 – PSGallery source: .psm1](https://www.powershellgallery.com/packages/SecretManagement.BitWarden/0.1.1/Content/SecretManagement.BitWarden.Extension\SecretManagement.BitWarden.Extension.psm1)

### CI/CD Integration

- [Bitwarden as an IaaS CI/CD secret vault (Bitwarden community)](https://community.bitwarden.com/t/bitwarden-as-a-iaas-ci-cd-secret-vault/32013/2)
- [Bitwarden as an IaaS CI/CD secret vault – thread root](https://community.bitwarden.com/t/bitwarden-as-a-iaas-ci-cd-secret-vault/32013)
- [The simplest way to make Bitwarden and Jenkins work like it should (hoop.dev blog)](https://hoop.dev/blog/the-simplest-way-to-make-bitwarden-jenkins-work-like-it-should/)
- [Jenkins Bitwarden Credentials Provider plugin](https://plugins.jenkins.io/bitwarden-credentials-provider/)
- [Bitwarden CLI client Docker image (jitesoft)](https://hub.docker.com/r/jitesoft/bitwarden-client)
- [Bitwarden clients GitHub issue #16527 – bw lock behavior](https://github.com/bitwarden/clients/issues/16527)

### VS Code and PowerShell Environment Variable Integration

- [Bitwarden CLI usage notes and session key patterns (ryan.himmelwright.net)](https://ryan.himmelwright.net/post/bitwarden-cli/)
- [Setting environment variables in PowerShell (configu.com)](https://configu.com/blog/setting-environment-variables-in-powershell-a-practical-guide/)
- [VS Code and environmental variables in PowerShell profiles (PowerShell Forums)](https://forums.powershell.org/t/visual-studio-code-and-environmental-variables/13349)
- [VS Code Tasks reference](https://code.visualstudio.com/docs/debugtest/tasks)
- [CLI keeps asking for password in PowerShell (Bitwarden community)](https://community.bitwarden.com/t/cli-keeps-asking-for-password-in-powershell/90610)
- [CLI session key (Bitwarden community)](https://community.bitwarden.com/t/cli-session-key/13397)
- [Is the key in BW_SESSION used by bw CLI? (Reddit)](https://www.reddit.com/r/Bitwarden/comments/ul3zy1/is_the_key_in_bw_session_used_by_bwcli/)

### Community Guides

- [Retrieve secrets from Bitwarden via PowerShell (Reddit r/PowerShell)](https://www.reddit.com/r/PowerShell/comments/qil3e7/retrieve_secrets_from_bitwarden/)
- [Non-interactive API login via PowerShell (Reddit r/Bitwarden)](https://www.reddit.com/r/Bitwarden/comments/s930ik/noninteractive_api_login_via_powershell/)
- [Password-manage your environment and secrets with Bitwarden (dev.to)](https://dev.to/stevengonsalvez/password-manage-your-environment-and-secrets-with-bitwarden-13n5)
- [How to securely store secrets in Bitwarden CLI and load them into your shell (Gruntwork)](https://www.gruntwork.io/blog/how-to-securely-store-secrets-in-bitwarden-cli-and-load-them-into-your-zsh-shell-when-needed)
- [Using bwenv to sync Bitwarden secrets into your shell environment (dev.to)](https://dev.to/s1ks1/use-bwenv-to-sync-your-bitwarden-secrets-into-your-shell-environment-23fh)
- [Bitwarden GitLab integration guide](https://bitwarden.com/help/gitlab-integration/)

### Videos

- [Bitwarden CLI walkthrough (YouTube)](https://www.youtube.com/watch?v=0PhTVbuffEE)
- [Bitwarden CI/CD integration demo (YouTube)](https://www.youtube.com/watch?v=mdbpXEzyrJY)

---

## Section 3.3.10 – Dev/Build/Repo Toolchain: WSL2 Runtime Environment

Sources for the WSL2 installation and configuration reference, distro selection guidance, drive mounting, Windows↔WSL2 networking, Ansible setup, PowerShell driving Ansible from Windows, and Docker in WSL2 with API access from .NET and PowerShell documented in Module Catalog Section 3.3.10.

### WSL2 Official Documentation (Microsoft)

- [Install WSL (learn.microsoft.com)](https://learn.microsoft.com/en-us/windows/wsl/install)
- [WSL networking (learn.microsoft.com)](https://learn.microsoft.com/en-us/windows/wsl/networking)
- [WSL tutorials: Docker containers](https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-containers)
- [WSL setup environment](https://learn.microsoft.com/en-us/windows/wsl/setup/environment)
- [WSL configuration (`wsl.conf` and `.wslconfig`)](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
- [Mount a disk in WSL2](https://learn.microsoft.com/en-us/windows/wsl/wsl2-mount-disk)
- [WSL basic commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)
- [Compare WSL versions](https://learn.microsoft.com/en-us/windows/wsl/compare-versions)
- [Install WSL on Windows Server](https://learn.microsoft.com/en-us/windows/wsl/install-on-server)
- [About WSL](https://learn.microsoft.com/en-us/windows/wsl/about)

### Ubuntu / WSL2 Official Documentation

- [Ubuntu on WSL (ubuntu.com)](https://ubuntu.com/desktop/wsl)
- [Install Ubuntu on WSL2 (documentation.ubuntu.com – stable)](https://documentation.ubuntu.com/wsl/stable/howto/install-ubuntu-wsl2/)
- [Install Ubuntu on WSL2 (documentation.ubuntu.com – latest)](https://documentation.ubuntu.com/wsl/latest/howto/install-ubuntu-wsl2/)
- [Ubuntu GitHub – WSL install guide](https://github.com/ubuntu/WSL/blob/main/docs/guides/install-ubuntu-wsl2.md)

### Docker Documentation

- [Docker Desktop WSL2 backend](https://docs.docker.com/desktop/features/wsl/)

### Distro Selection (Community)

- [Reddit: WSL recommended distribution](https://www.reddit.com/r/bashonubuntuonwindows/comments/1co100t/wsl_recommended_distribution/)
- [Reddit: Which WSL distro is best?](https://www.reddit.com/r/bashonubuntuonwindows/comments/juupsx/which_distro_is_best/)
- [Reddit: Smallest Linux distro for WSL as a base](https://www.reddit.com/r/bashonubuntuonwindows/comments/15e8knk/what_is_the_smallest_linux_distro_to_use_as/)
- [Ansible forum: Using WSL with Ansible and RHEL](https://forum.ansible.com/t/using-wsl-with-ansible-and-rhel-to-develop-automation-content/39720)
- [vanfalchi.com: Developer guide to WSL2](https://vanfalchi.com/unleashing-linux-on-windows-a-developers-guide-to-wsl2/)

### Drive Mounting and Networking (Community)

- [SitePoint: WSL2 overview and setup](https://www.sitepoint.com/wsl2/)
- [GitHub WSL issue #6286 – automount options](https://github.com/microsoft/WSL/issues/6286)
- [UIowa IT KB: WSL drive mounting](https://www.public-health.uiowa.edu/it/support/kb48568/)
- [Stack Overflow: Connecting to WSL2 server via local network](https://stackoverflow.com/questions/61002681/connecting-to-wsl2-server-via-local-network)
- [Stack Overflow: Reaching localhost from within Docker container using WSL2](https://stackoverflow.com/questions/76959405/reaching-localhost-from-within-docker-container-using-wsl2)

### Bitwarden CLI in WSL2 and Docker Secrets Patterns

- [Bitwarden CLI reference](https://bitwarden.com/help/cli/)
- [Bitwarden Secrets Manager CLI reference](https://bitwarden.com/help/secrets-manager-cli/)
- [Bitwarden developer quick start (Secrets Manager)](https://bitwarden.com/help/developer-quick-start/)
- [Bitwarden Personal API Key](https://bitwarden.com/help/personal-api-key/)
- [Bitwarden CLI GitHub](https://github.com/bitwarden/cli)
- [npm: @bitwarden/cli](https://www.npmjs.com/package/@bitwarden/cli)
- [Reddit: How to install bw CLI in Docker](https://www.reddit.com/r/Bitwarden/comments/xhir0q/how_to_install_bw_cli_in_docker/)
- [Docker secret management with bw (scottmckendry.tech)](https://scottmckendry.tech/docker-secret-management/)
- [chezmoi: Bitwarden integration](https://www.chezmoi.io/user-guide/password-managers/bitwarden/)
- [bwenv Python package](https://pypi.org/project/bwenv/)
- [SecretManagement.Warden 1.1.0 on PSGallery](https://www.powershellgallery.com/packages/SecretManagement.Warden/1.1.0)
- [vaultwarden: BW CLI with self-hosted server (Reddit)](https://www.reddit.com/r/vaultwarden/comments/v6f1uv/trying_to_access_bw_cli_commands_in_vaultwarden/)
- [writerit.nl: Load Bitwarden CLI env variable with one command](https://writerit.nl/productivity/bitwarden/load-bitwarden-cli-environment-variable-with-one-command/)
- [passageway.id: Bitwarden CLI guide](https://www.passageway.id/article/cli/)

### WSL/pwsh Auto-unlock and Session Management

- [Bitwarden community: CLI session key](https://community.bitwarden.com/t/cli-session-key/13397)
- [Is the key in BW_SESSION used by bw CLI? (Reddit)](https://www.reddit.com/r/Bitwarden/comments/ul3zy1/is_the_key_in_bw_session_used_by_bwcli/)
- [Gruntwork: Securely store and load secrets from Bitwarden into shell](https://www.gruntwork.io/blog/how-to-securely-store-secrets-in-bitwarden-cli-and-load-them-into-your-zsh-shell-when-needed)
- [ergaster.org: direnv + Bitwarden integration](https://ergaster.org/posts/2025/07/28-direnv-bitwarden-integration/)
- [Bitwarden CLI issue #383 – CLIXML / DPAPI concerns](https://github.com/bitwarden/cli/issues/383)
- [Bitwarden community: CLI unlock with PIN](https://community.bitwarden.com/t/cli-unlock-with-pin/29779)
- [Bitwarden community: CLI trying to login with personal API key automatically](https://community.bitwarden.com/t/cli-trying-to-login-with-personal-api-key-automatically-using-environment-variables/43434)
- [bitwarden/cli issue #378 – piping password via stdin](https://github.com/bitwarden/cli/issues/378)
- [bitwarden GitHub discussions #12650 – lock on logout](https://github.com/orgs/bitwarden/discussions/12650)
