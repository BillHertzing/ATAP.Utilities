# Write-ArrayIndented

Formats an array as an indented string representation.

## Synopsis

`Write-ArrayIndented` recursively converts an array to a multi-line indented string,
expanding nested arrays and hashtables at each level. It is intended for diagnostic
display of complex data structures, such as a settings hashtable inspected from the
`AllUsersAllHosts` profile or from a diagnostic script.

## Syntax

```powershell
Write-ArrayIndented [[-Array] <Object>] [[-Indent] <Int32>] [[-IndentIncrement] <Int32>] [<CommonParameters>]
```

## Description

The function walks the supplied array one element at a time and appends a line to an
accumulating string for each element. Every line is prefixed with `-Indent` spaces, so
the caller controls the absolute indentation of the whole block while the function
controls the relative indentation of everything nested inside it.

Element handling is decided by type, tested in this order:

| Element type                     | Rendered as                                                                  |
| -------------------------------- | ---------------------------------------------------------------------------- |
| `$null`                          | the literal text `(null)`                                                    |
| `[System.Boolean]`               | the string form of the value, `True` or `False`                              |
| `[System.String]`                | the string itself                                                            |
| `[System.Array]`                 | `(`, then the nested array indented by one increment, then `)`               |
| `[System.Collections.Hashtable]` | `{`, then the delegated hashtable body indented by one increment, then `}`   |
| anything else                    | the result of casting the element to `[string]`                              |

Nested arrays are handled by recursing into `Write-ArrayIndented` itself with `-Indent`
raised by `-IndentIncrement`. Nested hashtables are **not** handled here: the function
delegates them to `Write-HashIndented`, passing the raised indent as that function's
`-InitialIndent`. `Write-HashIndented` must therefore be available in the session, which
is why the three `*Indented` functions are normally dot-sourced or imported together.

Because the `[System.String]` test precedes the `[System.Array]` test, a string element
is emitted as one line rather than being enumerated character by character.

Every line is terminated with `[Environment]::NewLine`, so output carries the line
ending native to the running platform.

## Parameters

| Parameter          | Type     | Position | Required | Default | Description                                                                          |
| ------------------ | -------- | -------- | -------- | ------- | ------------------------------------------------------------------------------------ |
| `-Array`           | `Object` | 0        | No       | none    | The array to format. The parameter is untyped, so any enumerable or scalar may be passed. |
| `-Indent`          | `Int32`  | 1        | No       | `0`     | The current indentation level, in spaces, applied to every line this call emits.     |
| `-IndentIncrement` | `Int32`  | 2        | No       | `2`     | The number of additional spaces added at each nesting level.                         |

The function is decorated with `[CmdletBinding()]`, so it also accepts the common
parameters.

## Outputs

`[string]` — an indented, multi-line string representation of the array. The string is
emitted from the `process` block as a single value, so one call returns one string
containing every line, not one string per element. The returned string ends with a
trailing newline, so splitting it on the line terminator yields a final empty element.

## Examples

Every example below shows output captured from the function itself, not a reconstruction.

### Example 1: A flat array

```powershell
Write-ArrayIndented -Array @('alpha', 'beta') -Indent 0 -IndentIncrement 2
```

```text
alpha
beta
```

### Example 2: Indenting a whole block

```powershell
Write-ArrayIndented -Array @('item') -Indent 4 -IndentIncrement 2
```

```text
    item
```

### Example 3: A nested array

```powershell
Write-ArrayIndented -Array @('a', @('b', 'c'), 'd') -Indent 0 -IndentIncrement 2
```

```text
a
(
  b
  c
)
d
```

### Example 4: Null, booleans, and other scalars

```powershell
Write-ArrayIndented -Array @($null, $true, $false, 42) -Indent 0 -IndentIncrement 2
```

```text
(null)
True
False
42
```

### Example 5: A nested hashtable

```powershell
Write-ArrayIndented -Array @('a', 'b', @{x = 'one'}) -Indent 0 -IndentIncrement 2
```

```text
a
b
{
  x = one
}
```

The brace lines come from `Write-ArrayIndented`; the `x = one` line is produced by
`Write-HashIndented`, called with `-InitialIndent 2`, which in turn calls
`Write-KVPIndented` for each pair.

## Known limitation: scalar hashtable values are dropped

A hashtable value whose type is neither `[Boolean]`, `[String]`, `[Array]`, nor
`[Hashtable]` renders as an empty value. `Write-KVPIndented` selects the value's
rendering with a `switch` that has no default case, so an integer, `DateTime`, enum, or
`PSCustomObject` value produces the key, the ` = ` separator, and nothing after it:

```powershell
Write-ArrayIndented -Array @('a', 'b', @{x = 1}) -Indent 0 -IndentIncrement 2
```

```text
a
b
{
  x =
}
```

Note the asymmetry: at array level `Write-ArrayIndented` renders `42` correctly, because
its own `if`/`elseif` chain ends with an `else` that casts to `[string]`. The loss occurs
only for values reached through the hashtable delegation path. Callers diagnosing numeric
settings should be aware that a blank right-hand side means *unhandled type*, not *empty
value*. The fix belongs in `Write-KVPIndented`, not here.

## Notes

The function logs entry and exit at `Debug` level through PSFramework:

```powershell
Write-PSFMessage -FunctionName $fn -ModuleName 'ATAP.Utilities.PowerShell' -Level Debug -Message 'Starting Write-ArrayIndented'
```

Both the `begin` and `end` messages are written on every call, including each recursive
call, so a deeply nested structure produces two Debug messages per level.

Edge cases confirmed by `tests/Unit/Write-ArrayIndented.Tests.ps1`: an empty array and a
`$null` array each return without throwing, as do boolean elements and a nested
hashtable. An empty array returns a string containing only the trailing newline.

This function was moved out of `AllUsersAllHostsV7CoreProfile.ps1` into the
`ATAP.Utilities.PowerShell` module as part of SC-0183, which reduced profile loading
times.

## Related

- [Write-HashIndented](../public/Write-HashIndented.ps1) — formats a hashtable; called by this function for nested hashtable elements
- [Write-KVPIndented](../public/Write-KVPIndented.ps1) — formats a single key/value pair; called in turn by `Write-HashIndented`, and calls back into this function for array values
- [Write-EnvironmentVariablesIndented](../public/Write-EnvironmentVariablesIndented.ps1) — formats the environment variable collection

## Source

- Implementation: [Write-ArrayIndented.ps1](../public/Write-ArrayIndented.ps1)
- Tests: [Write-ArrayIndented.Tests.ps1](../tests/Unit/Write-ArrayIndented.Tests.ps1)
