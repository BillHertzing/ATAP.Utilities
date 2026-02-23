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
- [VS Code Branches and Worktrees](https://code.visualstudio.com/docs/sourcecontrol/branches-worktrees)
- [GitHub changelog: Create a branch for an issue (2022)](https://github.blog/changelog/2022-03-01-create-a-branch-for-an-issue/)
- [GitHub Docs Enterprise Server 3.11: Creating a branch for an issue](https://docs.github.com/en/enterprise-server@3.11/issues/tracking-your-work-with-issues/using-issues/creating-a-branch-for-an-issue)

### Community & Stack Overflow

- [Stack Overflow: Create new branch from the issue](https://stackoverflow.com/questions/41614421/create-new-branch-from-the-issue)
- [GitHub Community: Creating and switching branches in VS Code](https://github.com/orgs/community/discussions/89927)
- [GitHub CLI gist: gh issue develop usage](https://gist.github.com/devinschumacher/ea416af5542ac7102c8e1ffd0ab38a99)
- [Reddit: Issue with creating branch in VS Code](https://www.reddit.com/r/vscode/comments/1bdwjzr/issue_with_creating_branch/)

