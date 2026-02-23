<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# You are an expert on using Flyway from RedHat to manage database evolution and migration. . List all of the environment variables that Flyway will recognize. Ensure your answer is in the correct Case

I don’t have live access to the Flyway docs or your environment right now, so I can’t reliably list _all_ currently supported environment variables, in the correct and complete form, for the exact Flyway version you are using. Any “full list” I tried to reconstruct from memory would almost certainly miss items or use outdated names, which is not what you want for something this precise.

What I can tell you with confidence is how Flyway derives its environment-variable names from configuration keys, so you can generate an accurate list yourself for your exact version:

- Every standard configuration property `flyway.<key>` (for example `flyway.url`, `flyway.user`, `flyway.password`, `flyway.schemas`, `flyway.locations`, and all the others in the configuration reference) can be supplied as an environment variable by:
  - Stripping the `flyway.` prefix.
  - Converting the remainder to upper case.
  - Replacing dots with underscores.
  - Prefixing with `FLYWAY_`.

Examples (with exact case):

- `flyway.url` → `FLYWAY_URL`
- `flyway.user` → `FLYWAY_USER`
- `flyway.password` → `FLYWAY_PASSWORD`
- `flyway.schemas` → `FLYWAY_SCHEMAS`
- `flyway.defaultSchema` → `FLYWAY_DEFAULTSCHEMA`
- `flyway.locations` → `FLYWAY_LOCATIONS`
- `flyway.table` → `FLYWAY_TABLE`
- `flyway.baselineOnMigrate` → `FLYWAY_BASELINEONMIGRATE`
- `flyway.baselineVersion` → `FLYWAY_BASELINEVERSION`
- `flyway.connectRetries` → `FLYWAY_CONNECTRETRIES`
- `flyway.cleanDisabled` → `FLYWAY_CLEANDISABLED`
- `flyway.mixed` → `FLYWAY_MIXED`
- `flyway.placeholders.myPlaceholder` → `FLYWAY_PLACEHOLDERS_MYPLACEHOLDER`

In addition, Flyway exposes connection-related config into callbacks/scripts as environment variables with the same `FLYWAY_` prefix, such as `FLYWAY_URL`, `FLYWAY_USER`, and `FLYWAY_PASSWORD` for the current environment, plus placeholder-related variables like `FP__flyway_table__` etc.[^1_1]

Because the official documentation is the only authoritative, version-specific source for the _full_ set of configuration keys, the accurate way to get the complete list of environment variables for your Flyway build is:

1. Go to the “Configuration” section of the Flyway docs for your exact version.
2. Enumerate all configuration keys that start with `flyway.` (including command-line-only and env-only ones, if listed).
3. Apply the mapping rules above to each key to get the exact environment-variable name.

For scripting, a common pattern (PowerShell example) is to parse a `.conf` or TOML configuration and emit the corresponding `FLYWAY_...` variables automatically, using that same transformation, which guarantees correctness and keeps you aligned with new settings as you upgrade versions.[^1_1]

If you can share your specific Flyway version (e.g., “Flyway 10.12.0 CLI”), I can outline a quick script (PowerShell, Bash, or Python) that will walk the config reference or your config file and generate the exhaustive list for that version.
<span style="display:none">[^1_10][^1_11][^1_12][^1_13][^1_14][^1_15][^1_2][^1_3][^1_4][^1_5][^1_6][^1_7][^1_8][^1_9]</span>

<div align="center">⁂</div>

[^1_1]: https://www.red-gate.com/hub/product-learning/flyway/making-full-use-of-environment-variables-for-flyway-settings

[^1_2]: https://stackoverflow.com/questions/61050413/flyway-migrations-fails-when-passing-environment-variables-to-docker

[^1_3]: https://www.neh.gov/sites/default/files/2024-10/FOIA 23-27 Fashion Institute of Technology.pdf

[^1_4]: https://pubs.usgs.gov/of/2007/1239/report.pdf

[^1_5]: https://lemon.io/interview-questions/devops/

[^1_6]: https://documentation.red-gate.com/flyway/reference/environment-variables

[^1_7]: https://esginc.com/search-jobs/

[^1_8]: https://stackoverflow.com/questions/74543518/how-to-use-environment-variables-in-flyway-config-file

[^1_9]: https://snap.berkeley.edu/project/12316474

[^1_10]: https://documentation.red-gate.com/fd/environments-273973424.html

[^1_11]: https://noise.getoto.net/tag/aws-codecommit/page/2/

[^1_12]: https://www.youtube.com/watch?v=uvGNB57xcH0

[^1_13]: https://appinventiv.com/blog/devops-automation/

[^1_14]: https://github.com/flyway/flywaydb.org/blob/gh-pages/documentation/configuration/configfile.md

[^1_15]: https://quarkus.io/guides/flyway

---

# how do I find my vewrsion of Flyway

On any platform, you can print the installed Flyway CLI version directly from the command line.

### Command-line Flyway

Run either of these in the shell where `flyway` is on your `PATH`:

- `flyway --version`
- `flyway -v`

Both commands output the Flyway version and edition, then exit without running any migrations.[^2_1][^2_2]

### If you have multiple Flyway installs

If you suspect several versions are installed (e.g., multiple `flyway` folders or Docker images):

- For a specific installation directory: run the `flyway` executable from that directory with `./flyway -v` (Linux/macOS) or `flyway.cmd -v` (Windows).[^2_3]
- For a Docker image: `docker run --rm flyway/flyway -v` (or whatever image tag you use) will print the version inside that container.[^2_4][^2_5]
  <span style="display:none">[^2_10][^2_11][^2_12][^2_13][^2_14][^2_15][^2_6][^2_7][^2_8][^2_9]</span>

<div align="center">⁂</div>

[^2_1]: https://documentation.red-gate.com/fd/command-line-parameters-277578836.html

[^2_2]: https://documentation.red-gate.com/flyway/reference/command-line-parameters

[^2_3]: https://www.red-gate.com/hub/product-learning/flyway/installing-and-upgrading-the-flyway-cli

[^2_4]: https://jdriven.com/blog/2025/04/Flyway-in-the-command-line

[^2_5]: https://neon.com/docs/guides/flyway

[^2_6]: https://stackoverflow.com/questions/48230507/how-do-i-get-the-flyway-version-number-of-a-database

[^2_7]: https://www.red-gate.com/hub/product-learning/flyway/finding-the-version-of-a-flyway-managed-database

[^2_8]: https://www.red-gate.com/hub/product-learning/flyway/the-flyway-info-command-explained-simply

[^2_9]: https://github.com/flyway/flyway/issues/2389

[^2_10]: https://www.youtube.com/watch?v=mYE_omHLM_A

[^2_11]: https://documentation.red-gate.com/fd/flyway-output-query-results-setting-277579016.html

[^2_12]: https://github.com/flyway/flywaydb.org/blob/gh-pages/documentation/usage/commandline/index.md

[^2_13]: https://stackoverflow.com/questions/33677026/flyway-migration-schema-version

[^2_14]: https://documentation.red-gate.com/fd/command-line-277579359.html

[^2_15]: https://jilles.me/database-versioning-and-migrations-for-everyone-using-flyway/

---

# I have Flyway OSS Edition 10.21.0 by Redgate

For Flyway OSS 10.21.0 there isn’t a short, fixed “enum” of environment variables; instead, **almost every configuration parameter becomes an environment variable via a naming rule**.[^3_1][^3_2]

### How environment-variable names are derived

Take any documented configuration parameter name (from the Parameters list for Flyway 10.x).[^3_2]

1. Start from the key as used in config files, e.g. `flyway.url`, `flyway.defaultSchema`, `flyway.placeholders.myPlaceholder`.
2. Strip the `flyway.` prefix, if present.
3. Replace any remaining dots with underscores.
4. Uppercase the result.
5. Prefix with `FLYWAY_`.

Examples in correct case:

- `flyway.url` → `FLYWAY_URL`
- `flyway.user` → `FLYWAY_USER`
- `flyway.password` → `FLYWAY_PASSWORD`
- `flyway.driver` → `FLYWAY_DRIVER`
- `flyway.schemas` → `FLYWAY_SCHEMAS`
- `flyway.defaultSchema` → `FLYWAY_DEFAULTSCHEMA`
- `flyway.locations` → `FLYWAY_LOCATIONS`
- `flyway.table` → `FLYWAY_TABLE`
- `flyway.tablespace` → `FLYWAY_TABLESPACE`
- `flyway.target` → `FLYWAY_TARGET`
- `flyway.mixed` → `FLYWAY_MIXED`
- `flyway.outOfOrder` → `FLYWAY_OUTOFORDER`
- `flyway.validateOnMigrate` → `FLYWAY_VALIDATEONMIGRATE`
- `flyway.validateMigrationNaming` → `FLYWAY_VALIDATEMIGRATIONNAMING`
- `flyway.cleanDisabled` → `FLYWAY_CLEANDISABLED`
- `flyway.createSchemas` → `FLYWAY_CREATESCHEMAS`
- `flyway.baselineOnMigrate` → `FLYWAY_BASELINEONMIGRATE`
- `flyway.baselineVersion` → `FLYWAY_BASELINEVERSION`
- `flyway.baselineDescription` → `FLYWAY_BASELINEDESCRIPTION`
- `flyway.ignoreMigrationPatterns` → `FLYWAY_IGNOREMIGRATIONPATTERNS`
- `flyway.connectRetries` → `FLYWAY_CONNECTRETRIES`
- `flyway.connectRetriesInterval` → `FLYWAY_CONNECTRETRIESINTERVAL`
- `flyway.initSql` → `FLYWAY_INITSQL`
- `flyway.jdbcProperties` → `FLYWAY_JDBCPROPERTIES`
- `flyway.workingDirectory` → `FLYWAY_WORKINGDIRECTORY`
- `flyway.loggers` → `FLYWAY_LOGGERS`
- `flyway.skipDefaultResolvers` → `FLYWAY_SKIPDEFAULTRESOLVERS`
- `flyway.skipDefaultCallbacks` → `FLYWAY_SKIPDEFAULTCALLBACKS`
- `flyway.skipExecutingMigrations` → `FLYWAY_SKIPEXECUTINGMIGRATIONS`
- `flyway.outputQueryResults` → `FLYWAY_OUTPUTQUERYRESULTS`
- `flyway.reportFilename` → `FLYWAY_REPORTFILENAME`
- `flyway.placeholders.myPlaceholder` → `FLYWAY_PLACEHOLDERS_MYPLACEHOLDER`

Flyway’s docs explicitly say: “See configuration for a full list of supported configuration parameters. Each individual settings page will list the environment variable, if supported.” The master parameter list for 10.x is in the Parameters page.[^3_3][^3_1][^3_2]

### Special environment-variable groups

Besides the straight `FLYWAY_…` mappings:

- JDBC properties can be passed via `FLYWAY_JDBCPROPERTIES_…` (for example `FLYWAY_JDBCPROPERTIES_ACCESSTOKEN`).[^3_4][^3_2]

```
- Placeholders are available to callbacks both as `FLYWAY_PLACEHOLDERS_<NAME>` and via the `FP__flyway_<name>__` pattern used in Redgate’s sample scripts, but the portable, documented form is the `FLYWAY_PLACEHOLDERS_…` name derived as above.[^3_5][^3_6]
```

### Getting the exhaustive list for 10.21.0

To literally list **all** environment variable names for your version, walk the 10.x Parameters list and apply the rule.[^3_2]

For your workflow, a small generator script is practical. For example, in PowerShell:

```powershell
# Given a list of flyway.* keys (one per line in params.txt),
# emit their environment variable names for Flyway 10.21.0

Get-Content .\params.txt |
  Where-Object { $_ -and -not $_.StartsWith('#') } |
  ForEach-Object {
    $key = $_.Trim()
    if ($key.StartsWith('flyway.')) {
      $suffix = $key.Substring(7)           # drop 'flyway.'
    } else {
      $suffix = $key
    }
    $envName = 'FLYWAY_' + ($suffix -replace '\.', '_' | ForEach-Object { $_.ToUpper() })
    $envName
  }
```

Feed it the parameter names from the 10.x Parameters reference and it will output every valid `FLYWAY_…` variable in the exact case Flyway expects.[^3_1][^3_2]
<span style="display:none">[^3_10][^3_11][^3_12][^3_13][^3_14][^3_15][^3_7][^3_8][^3_9]</span>

<div align="center">⁂</div>

[^3_1]: https://documentation.red-gate.com/flyway/reference/environment-variables

[^3_2]: https://github.com/flyway/flyway/blob/main/documentation/Flyway CLI and API/Configuration/Environment Variables.md

[^3_3]: https://documentation.red-gate.com/fd/environment-variables-224003080.html

[^3_4]: https://documentation.red-gate.com/fd/release-notes-for-flyway-engine-179732572.html

[^3_5]: https://www.red-gate.com/hub/product-learning/flyway/making-full-use-of-environment-variables-for-flyway-settings

[^3_6]: https://www.red-gate.com/hub/product-learning/flyway/passing-parameters-and-settings-to-flyway-scripts

[^3_7]: https://www.youtube.com/watch?v=uvGNB57xcH0

[^3_8]: https://stackoverflow.com/questions/74543518/how-to-use-environment-variables-in-flyway-config-file

[^3_9]: https://documentation.red-gate.com/fd/flyway-desktop-7-release-notes-229116743.html

[^3_10]: https://voiceofthedba.com/2023/09/22/friday-flyway-tips-flyway-parameters/

[^3_11]: https://www.youtube.com/watch?v=K7mdHjMh46U

[^3_12]: https://github.com/flyway/flyway/blob/main/documentation/Flyway CLI and API/Configuration/Parameters.md

[^3_13]: https://www.opsmatters.com/videos/making-full-use-environment-variables-flyway-tony-and-tonie-show

[^3_14]: https://documentation.red-gate.com/flyway/flyway-concepts/environments

[^3_15]: https://github.com/flyway/flywaydb.org/blob/gh-pages/documentation/configuration/parameters/index.md

---

# explain what FLYWAY*PLACEHOLDERS or FP\_\_flyway*<name> is used for

`FLYWAY_PLACEHOLDERS_*` and `FP__flyway_<name>__` are both ways of getting values into Flyway **placeholders**, which are variables you can use inside migration scripts so the same SQL can be customized per environment (dev/test/prod, different schemas, different users, secrets, etc.).[^4_1][^4_4]

### What placeholders are

In your SQL migrations you can write things like:

```sql
CREATE SCHEMA ${schema_name};

GRANT SELECT ON SCHEMA ${schema_name} TO ${readonly_user};
```

At runtime Flyway replaces `${schema_name}` and `${readonly_user}` with concrete values before sending the SQL to the database. This lets you keep one generic script and change only configuration between environments.[^4_2][^4_1]

### `FLYWAY_PLACEHOLDERS_*` environment variables

Configuration keys of the form `flyway.placeholders.<name>=value` define user placeholders. The environment-variable form is:

- `flyway.placeholders.schema_name = my_schema`
  → `FLYWAY_PLACEHOLDERS_SCHEMA_NAME=my_schema`
- `flyway.placeholders.readonly_user = app_reader`
  → `FLYWAY_PLACEHOLDERS_READONLY_USER=app_reader`

Flyway reads these and uses them when replacing `${schema_name}` and `${readonly_user}` in your SQL.[^4_4]

Typical uses:

- Environment-specific schema names, table prefixes, or roles.
- Injecting connection strings, URLs, or other config that differ by environment.
- Avoiding hard-coding secrets (e.g., passwords) directly in SQL files.[^4_1][^4_2]

### `FP__flyway_<name>__` variables

The `FP__flyway_<name>__` style is a naming convention used when exposing placeholders (and some other settings) as environment variables to scripts or tools that run alongside Flyway, especially in more complex pipelines.

Conceptually:

- Flyway resolves placeholders from its configuration (including `FLYWAY_PLACEHOLDERS_*`).
- For callbacks or external scripts, it also surfaces those values as environment variables like `FP__flyway_schema_name__`, so your script can read them without parsing Flyway config files.

So:

- `FLYWAY_PLACEHOLDERS_*` → how you **provide** placeholder values to Flyway.
- `FP__flyway_<name>__` → how Flyway (or wrapper tooling) can **export** resolved placeholder values (and some other settings) for use in external scripts, keeping everything in sync with what the migrations saw.[^4_11]
  <span style="display:none">[^4_10][^4_3][^4_5][^4_6][^4_7][^4_8][^4_9]</span>

<div align="center">⁂</div>

[^4_1]: https://documentation.red-gate.com/fd/migration-placeholders-275218550.html

[^4_2]: https://stackoverflow.com/questions/44252696/purpose-of-placeholders-in-flyway-database-migrations

[^4_3]: https://stackoverflow.com/questions/9418173/how-do-placeholders-work-in-flyway

[^4_4]: https://documentation.red-gate.com/flyway/flyway-cli-and-api/configuration/parameters/flyway/placeholders

[^4_5]: https://runebook.dev/en/articles/spring_boot/application-properties/application-properties.data-migration.spring.flyway.placeholders

[^4_6]: https://runebook.dev/en/articles/spring_boot/application-properties/application-properties.data-migration.spring.flyway.script-placeholder-suffix

[^4_7]: https://github.com/flyway/flyway/issues/3826

[^4_8]: https://github.com/flyway/flyway/issues/3384

[^4_9]: https://github.com/flyway/flyway/issues/2429

[^4_10]: https://developer-youn.tistory.com/129

[^4_11]: https://www.red-gate.com/hub/product-learning/flyway/passing-parameters-and-settings-to-flyway-scripts

---

# Common pitfalls when using placeholders in repeatable migrations

The biggest issues are around how checksums work and how often repeatable migrations re-run when only placeholder values change.[^5_1][^5_2][^5_3]

### 1. Expecting placeholder changes to re-run repeatables

- Flyway calculates the checksum for a repeatable migration from the script text, usually **before** substituting user placeholders.[^5_2][^5_4]
- Changing `flyway.placeholders.MY_VALUE` often does not change the stored checksum for the repeatable, so the migration does not re-run as you might expect.[^5_5][^5_1]
- Relying on “flip a placeholder value to force an R\_\_ script to run” is therefore fragile and version-dependent.

**Mitigation:**
Change the script itself when you truly want to re-run it, or use the built‑in `${flyway:timestamp}` placeholder when you intentionally want “always rerun” behavior.[^5_6][^5_3]

### 2. Trying to make “always-run” repeatables via placeholders

- Putting a changing placeholder like `${timestamp}` in a repeatable script and expecting it to run on every `migrate` is a common pattern that does not work in older versions, because checksum is taken pre‑substitution.[^5_4][^5_2]
- This leads to confusion when a “dynamic” placeholder appears to change each run but Flyway still skips the repeatable.

**Mitigation:**

- Use Flyway callbacks (`beforeMigrate.sql`, `afterMigrate.sql`, etc.) for “run every time” logic.[^5_2]
- Or use the documented `${flyway:timestamp}` trick, which is specifically designed so that each run changes the checksum for repeatables.[^5_3][^5_6]

### 3. Hidden coupling between environment config and repeatables

- If a repeatable’s behavior depends on placeholders that vary by environment (schema names, roles, feature flags), you can end up with the **same checksum** but different side effects across environments.[^5_7][^5_8]
- This makes it harder to reason about whether a repeatable “has done its job” everywhere, because Flyway’s tracking only knows about the checksum, not the substituted values.

**Mitigation:**

- Keep environment-specific behavior in versioned migrations or separate repeatables per environment, and make repeatables depend as little as possible on volatile placeholders.[^5_8][^5_3]

### 4. Using default placeholders that have limitations in repeatables

- Some built‑in placeholders (e.g., `${flyway:filename}`) have had issues or limitations specifically with repeatable migrations in certain versions.[^5_9]
- This can manifest as failures populating the placeholder only for repeatables, while versioned migrations and callbacks work.

**Mitigation:**

- Check the docs and release notes for any limitations of default placeholders in repeatable migrations for your Flyway version.[^5_10][^5_8]
- If a default placeholder misbehaves in repeatables, fall back to explicit configuration or a callback.

### 5. Using placeholders to represent large or generated content

- Some teams try to inject large generated SQL blobs into a repeatable via a placeholder (e.g., concatenated DDL of many procedures).[^5_5]
- If Flyway’s checksum does not incorporate the fully substituted content the way you expect, changes in the underlying generated SQL may not trigger re-execution.

**Mitigation:**

- Prefer one repeatable per unit (e.g., per object) or use versioned migrations to track such changes explicitly.[^5_11][^5_3]
- If you must generate content, generate or update the migration file itself so its text (and checksum) changes predictably.
  <span style="display:none">[^5_12][^5_13][^5_14][^5_15][^5_16]</span>

<div align="center">⁂</div>

[^5_1]: https://stackoverflow.com/questions/41242156/repeatable-flyway-migration-wont-run-again-if-placeholder-changes

[^5_2]: https://stackoverflow.com/questions/39661878/flyway4-repeatable-migration-dynamic-checksum-change-maven-always-execute

[^5_3]: https://documentation.red-gate.com/fd/repeatable-migrations-273973335.html

[^5_4]: https://stackoverflow.com/questions/39661878/flyway4-repeatable-migration-dynamic-checksum-change-maven-always-execute/39672079

[^5_5]: https://github.com/flyway/flyway/issues/2177

[^5_6]: https://flywaydb.org/blog/flyway-timestampsAndRepeatables

[^5_7]: https://documentation.red-gate.com/flyway/flyway-concepts/migrations/migration-placeholders

[^5_8]: https://documentation.red-gate.com/fd/migration-placeholders-275218550.html

[^5_9]: https://github.com/flyway/flyway/issues/3454

[^5_10]: https://documentation.red-gate.com/fd/release-notes-for-flyway-engine-179732572.html

[^5_11]: https://stackoverflow.com/questions/42930738/flyway-and-initialization-of-repeatable-migrations

[^5_12]: https://www.red-gate.com/hub/product-learning/flyway/flyway-gotchas

[^5_13]: https://github.com/flyway/flyway/issues/4063

[^5_14]: https://www.red-gate.com/hub/product-learning/flyway/flyway-how-tos-a-users-perspective

[^5_15]: https://stackoverflow.com/questions/63091283/flyway-always-execute-repeatable-migrations

[^5_16]: https://bell-sw.com/blog/how-to-use-flyway-with-spring-boot/

---

# give me powershell to use join-path to create "C:\Dropbox\whertzing\GitHub\SharedVSCode\Databases\flyway.toml"

Use `Join-Path` with multiple segments like this:

```powershell
$flywayToml = Join-Path -Path 'C:' -ChildPath 'Dropbox\whertzing\GitHub\SharedVSCode\Databases\flyway.toml'
$flywayToml
```

Or, using separate segments:

```powershell
$flywayToml = Join-Path -Path 'C:' -ChildPath 'Dropbox' |
    Join-Path -ChildPath 'whertzing' |
    Join-Path -ChildPath 'GitHub' |
    Join-Path -ChildPath 'SharedVSCode' |
    Join-Path -ChildPath 'Databases' |
    Join-Path -ChildPath 'flyway.toml'
$flywayToml
```

<span style="display:none">[^6_1][^6_10][^6_11][^6_12][^6_13][^6_14][^6_15][^6_2][^6_3][^6_4][^6_5][^6_6][^6_7][^6_8][^6_9]</span>

<div align="center">⁂</div>

[^6_1]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/join-path?view=powershell-7.5

[^6_2]: https://stackoverflow.com/questions/25880122/how-do-i-use-join-path-to-combine-more-than-two-strings-into-a-file-path

[^6_3]: https://www.pdq.com/powershell/join-path/

[^6_4]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/join-path?view=powershell-7.4\&viewFallbackFrom=powershell-6

[^6_5]: http://devblackops.io/joining-paths-in-powershell/

[^6_6]: https://jonlabelle.com/snippets/view/powershell/join-multiplepaths

[^6_7]: https://stackoverflow.com/questions/25880122/how-do-i-use-join-path-to-combine-more-than-two-strings-into-a-file-path/53745818

[^6_8]: https://www.powershellgallery.com/packages/DailyBackup/1.10.4/Content/Private\Join-MultiplePaths.ps1

[^6_9]: https://powershell-7.ru/?p=942

[^6_10]: https://codebuckets.com/2016/08/20/powershell-join-path-with-multiple-parameters/

[^6_11]: https://www.youtube.com/watch?v=8_goo3YWQxU

[^6_12]: https://www.powershellgallery.com/packages/DailyBackup/1.10.5/Content/Private\Join-MultiplePaths.ps1

[^6_13]: https://day3bits.com/2024-12-09-Revisiting-Join-Path-in-PowerShell/

[^6_14]: https://www.byteinthesky.com/powershell/combine-multiple-paths/

[^6_15]: https://blog.ironmansoftware.com/powershell-paths/

---

# give me seperate argumensts all on the same line

```powershell
$flywayToml = Join-Path -Path 'C:' -ChildPath 'Dropbox' 'whertzing' 'GitHub' 'SharedVSCode' 'Databases' 'flyway.toml'
```
