# Rules Compendium — C# (CSharp)

<!-- METADATA
  Language: C#
  Created: pre-existing; normalized 2026-08-02
  Kind Count: 1
  Primitive Count: 18
  Template version: 1.0
  Source skill: .claude/skills/new-rule-kind/SKILL.md
-->

This file documents C# Rule Primitives, Rules, and Rule Sets used within the
ATAP.Utilities libraries and the Ace Commander application.

## Philote Identity Convention

Every Primitive, Rule, Rule Set, and Build Set defined in this document carries a **Philote ID**. A Philote is a .NET generic type `IPhilote<T>` where `T` is either `GUID` or `int`. All identifiers in this document use the `GUID` variant. The GUID is allocated once when the element is defined and never changes; it is the stable key back into the Ace Commander Instantiations database.

Format: `IPhilote<GUID>` — rendered in this document as a quoted GUID string, e.g. `"a3f2e1d0-1b2c-4a5b-8c9d-0e1f2a3b4c5d"`.

## Overview

This file documents C# Rules and Rule Sets that make up modules and features.

Rules are created from Rule Primitives.

Rule Sets are created from Rules and include a directed graph that controls how execution flows from one Rule to another.

In order to define a feature or module in the ATAP.Utilities libraries or the Ace Commander application, a Rule Set is tagged with a feature identifier, which means that to implement the feature the Ace Commander Module will include that Rule Set in its Build Set.

## The purpose of Rules, Rule Sets, and Build Sets

Here is a simplifying acronym to shorten the long name "Rules, Rule Sets and Build Sets". We will refer to all of those compositely as "RRSBS".

Everything in the ATAP.Utilities libraries and the Ace Commander application, and all bolt-on modules for Ace Commander, are built from RRSBS. There are RRSBS that define the Ace Commander GUI. There are RRSBS for all visual display elements, RRSBS for composing visual elements into screens / pages, and RRSBS for stitching the screens / pages together into logical workflows. All data elements in the ecosystem are defined by RRSBS. Hardware for the computer systems that run the backend and on which the front end application runs are defined by RRSBS. Build processes for creating .dll libraries, .so libraries, .exe programs, are all defined by RRSBS. All tests for all software components are defined by RRSBS. Test Processes are defined by RRSBS. The processes to create and maintain database schemas and data are defined by RRSBS, as are the instructions how to backup and restore these databases. Documentation about how the RRSBS work are themselves defined by RRSBS. In sum, every concept, every bit of data, every software tool, the complete Ace Commander application, interfaces to third-party hardware and software are all defined by RRSBS. Specific instantiations of the Ace Commander or ATAP.Utilities libraries owned / used by owners / users are stored in the Instantiations database, and that database, and its schema and operational processes are defined by RRSBS. The APIs for the backend and how the Ace Commander front-end communicates with the backend APIs are defined by RRSBS.

## Language Version

Unless there is a compelling reason to target an older version, all C# code should target the latest stable version of the language to take advantage of new features and improvements.

As of this writing, the latest stable version is C# 14.0, released in November 2025 alongside .NET 10. C# 15 is in active preview, targeting .NET 11 (currently in preview as of early 2026). If new features in C# 15 arebeneficial, consider adopting them, but document and alert the user if features from versions in development are used.

## Part I — Grammar Specification

*This section is written once when the Kind is defined. Update only on grammar revision.*
*The grammar below is authored at `grammers/CSharp.grammar.ebnf`; its rendered `docs/`
*copy remains deferred until grammar artifacts become database-stored.*

<!-- rule-grammar-start -->

### Kind: CSharp

**Philote ID:** Not allocated in the current corpus; the retained-kind decision is
recorded by GRAMMAR-01 and the baseline seed gate must allocate the Kind identity.

**Grammar file:** `grammers/CSharp.grammar.ebnf`

**DB record:** No authoritative current `PrimitiveLanguageKind` row is asserted by
this normalization; database conformance is a later gated baseline activity.

**Description:** Deterministic C# source-file rendering from the retained CSharp
Rule Primitives.

#### Grammar

<!-- EMBEDDED from grammers/CSharp.grammar.ebnf -->
```ebnf
cs-source-file = { file-element } ;
file-element = using-directive | namespace-block-declaration | type-declaration |
               single-line-comment | block-comment | new-line ;
type-declaration = interface-declaration | class-declaration | record-declaration ;
```
<!-- END EMBEDDED -->

#### Composition Constraints

- A rendered source file is an ordered sequence of `file-element` values.
- A namespace body may contain using directives, type declarations, comments, and new lines.
- A type declaration resolves to an interface, class, or record declaration in this retained subset.
- Every documented Rule Primitive maps to at least one non-terminal in
  `grammers/CSharp.grammar.ebnf`.

#### Valid Expression Examples

```csharp
namespace Example;
public interface IWidget { string Name { get; } }
```

```csharp
public sealed record Widget(Guid Id, string Name);
```

<!-- rule-grammar-end -->

---

## Part II — Rule Primitives

Rule Primitives are the atomic building blocks from which a Rule is constructed. Each primitive maps to a single BNF non-terminal in the C# grammar. When a primitive is instantiated, its inputs are bound to specific values; the rendered output is the exact C# text that corresponds to that non-terminal node in the parse tree.

<!-- rule-primitives-start -->

---

### `<cs-source-file>` Rule Primitive

**Philote ID:** `"4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85"`

Description: Top-level container for a `.cs` file. A C# source file is a sequence of using directives followed by one or more namespace or type declarations, separated by whitespace or comments.

```bnf
<cs-source-file>          ::= <file-element-list>?

<file-element-list>       ::= <file-element>
              | <file-element-list> <file-element>

<file-element>            ::= <using-directive>
              | <namespace-block-declaration>
              | <type-declaration>
              | <single-line-comment>
              | <block-comment>
              | <new-line>
```

Body: The full text of the `.cs` file composed in declared order.

Inputs:

- `Elements` (ordered list of `<file-element>` instances).

Output: Concatenated rendering of all elements.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/ (ECMA-334)
2. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/namespace
```

---

### `<using-directive>` Rule Primitive

**Philote ID:** `"8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2"`

Description: Imports a namespace, static members of a type, or creates an alias.

```bnf
<using-directive>         ::= <using-namespace-directive>
              | <using-static-directive>
              | <using-alias-directive>

<using-namespace-directive> ::= "using" <ws> <namespace-or-type-name> ";"

<using-static-directive>  ::= "using" <ws> "static" <ws> <namespace-or-type-name> ";"

<using-alias-directive>   ::= "using" <ws> <identifier> <ws> "=" <ws>
                <namespace-or-type-name> ";"
```

Inputs:

- `DirectiveKind` (enum: `Namespace` | `Static` | `Alias`).
- `NamespaceName` (string).
- `AliasIdentifier` (string, required when `DirectiveKind = Alias`).

Output: Single `using` line.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/using-directive
```

---

### `<namespace-block-declaration>` Rule Primitive

**Philote ID:** `"d3f0f6b9-1eae-4a8d-9a6f-5d8f2410c8a4"`

Description: Declares a namespace using block syntax and encloses one or more type declarations.

```bnf
<namespace-block-declaration> ::= "namespace" <ws> <namespace-name>
                  <new-line>? "{" <namespace-body> "}"

<namespace-body>          ::= <namespace-body-element>*

<namespace-body-element>  ::= <using-directive>
              | <type-declaration>
              | <single-line-comment>
              | <block-comment>
              | <new-line>
```

Inputs:

- `NamespaceName` (string).
- `BodyElements` (ordered list of `<namespace-body-element>` instances).

Output: The namespace block text.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/namespace
```

---

### `<single-line-comment>` Rule Primitive

**Philote ID:** `"2f4a8073-b7c8-432e-aac7-65f6063a1e2a"`

Description: `//` comment to end of line.

```bnf
<single-line-comment>     ::= "//" <comment-text>? <new-line>
```

Inputs:

- `CommentText` (string, optional).

Output: One comment line.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/tokens/comments
```

---

### `<access-modifier>` Rule Primitive

**Philote ID:** `"0fbb4f0d-917d-4b60-8db1-9d9e3de5712f"`

Description: Visibility keyword for types and members.

```bnf
<access-modifier>         ::= "public"
              | "internal"
              | "private"
              | "protected"
              | "protected internal"
              | "private protected"
```

Inputs:

- `Level` (one of the listed tokens).

Output: The selected keyword string.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/access-modifiers
```

---

### `<type-parameter-list>` Rule Primitive

**Philote ID:** `"a4efb6e5-58f0-4603-94ae-45b62c323d0b"`

Description: Declares generic type parameters.

```bnf
<type-parameter-list>     ::= "<" <type-parameter-seq> ">"

<type-parameter-seq>      ::= <type-parameter>
              | <type-parameter-seq> "," <ws>? <type-parameter>

<type-parameter>          ::= <identifier>
```

Inputs:

- `TypeParameters` (ordered list of identifiers).

Output: `<T>` list.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/generics/generic-type-parameters
```

---

### `<type-constraint-clause>` Rule Primitive

**Philote ID:** `"8ad77df8-8366-40f8-99b5-ff2a2a8d5da9"`

Description: `where` clause restricting generic type arguments.

```bnf
<type-constraint-clause>  ::= "where" <ws> <identifier> <ws> ":" <ws>
                <type-constraint-list>

<type-constraint-list>    ::= <type-constraint>
              | <type-constraint-list> "," <ws>? <type-constraint>

<type-constraint>         ::= "class" | "struct" | "notnull" | "unmanaged" | "new()" | <type-reference>
```

Inputs:

- `TypeParameterName` (string).
- `Constraints` (ordered list of constraint tokens or type names).

Output: `where T : constraint1, constraint2` clause.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/generics/constraints-on-type-parameters
```

---

### `<base-type-list>` Rule Primitive

**Philote ID:** `"3e8eac46-1e1a-4b80-a5f1-406cc6f5d0f1"`

Description: Lists a base class and/or interfaces after a type name.

```bnf
<base-type-list>          ::= ":" <ws> <base-type-seq>

<base-type-seq>           ::= <type-reference>
              | <base-type-seq> "," <ws>? <type-reference>
```

Inputs:

- `BaseTypes` (ordered list of type names).

Output: `: Base, IFoo` list.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/base
```

---

### `<type-reference>` Rule Primitive

**Philote ID:** `"b7f87746-72af-4632-9dd9-05f833b3a8e8"`

Description: Names any C# type, optionally with generic arguments and nullability.

```bnf
<type-reference>          ::= <qualified-identifier>
              | <qualified-identifier> "<" <type-argument-list> ">"
              | <type-reference> "?"

<qualified-identifier>    ::= <identifier>
              | <qualified-identifier> "." <identifier>

<type-argument-list>      ::= <type-reference>
              | <type-argument-list> "," <ws>? <type-reference>
```

Inputs:

- `TypeName` (string, may be qualified).
- `TypeArguments` (ordered list of `<type-reference>` strings, optional).
- `IsNullable` (bool, default `false`).

Output: Rendered type token.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/built-in-types
```

---

### `<interface-declaration>` Rule Primitive

**Philote ID:** `"6a972b5b-5da7-4a73-b5d6-564e1b305a0b"`

Description: Declares an interface and its members.

```bnf
<interface-declaration>   ::= <access-modifier>? <ws>? "interface" <ws> <identifier>
                <type-parameter-list>?
                <base-type-list>?
                <type-constraint-clause>*
                <ws>? "{" <interface-member-list>? "}"

<interface-member-list>   ::= <interface-member>
              | <interface-member-list> <interface-member>

<interface-member>        ::= <property-declaration>
              | <single-line-comment>
              | <new-line>
```

Inputs:

- `AccessModifier` (string, optional).
- `InterfaceName` (string).
- `TypeParameters` (optional `<type-parameter-list>`).
- `BaseTypes` (optional `<base-type-list>`).
- `TypeConstraints` (ordered list of `<type-constraint-clause>` instances, optional).
- `Members` (ordered list of member declarations).

Output: Complete interface block.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/interface
```

---

### `<property-declaration>` Rule Primitive

**Philote ID:** `"6d2e4c24-4f59-487f-9e6d-2e65f97a6dd0"`

Description: Declares a property with get and/or set/init accessors.

```bnf
<property-declaration>    ::= <type-reference> <ws> <identifier> <ws>? "{" <accessor-list> "}"

<accessor-list>           ::= <accessor-declaration>
              | <accessor-list> <accessor-declaration>

<accessor-declaration>    ::= "get" ";" | "set" ";" | "init" ";"
```

Inputs:

- `PropertyType` (string).
- `PropertyName` (string).
- `Accessors` (ordered list of accessor keywords).

Output: Property declaration line.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/properties
```

---

### `<attribute-list>` Rule Primitive

**Philote ID:** `"2c75c902-3a6c-4c28-8f0f-1b8d6f45fefa"`

Description: One or more attributes applied to the next declaration.

```bnf
<attribute-list>          ::= <attribute>
              | <attribute-list> <new-line>? <attribute>

<attribute>              ::= "[" <attribute-target>? <attribute-name> <attribute-argument-list>? "]"

<attribute-target>       ::= "assembly:" | "module:" | "field:" | "event:" | "method:" | "param:" | "property:" | "return:" | "type:"

<attribute-name>         ::= <qualified-identifier>

<attribute-argument-list>::= "(" <argument-seq>? ")"

<argument-seq>           ::= <expression>
              | <argument-seq> "," <ws>? <expression>
```

Inputs:

- `Attributes` (ordered list of attribute strings, each already rendered with optional target and arguments).

Output: The rendered attributes, one per line, preceding the decorated declaration.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/attributes
```

---

### `<class-declaration>` Rule Primitive

**Philote ID:** `"5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a"`

Description: Declares a class, optionally static, abstract, or sealed, with members.

```bnf
<class-declaration>       ::= <attribute-list>? <access-modifier>? <ws>? <class-modifier>* "class" <ws> <identifier>
                <type-parameter-list>? <base-type-list>? <type-constraint-clause>*
                <ws>? "{" <class-member-list>? "}"

<class-modifier>          ::= "static" | "abstract" | "sealed" | "partial"

<class-member-list>       ::= <class-member>
              | <class-member-list> <class-member>

<class-member>            ::= <field-declaration>
              | <constructor-declaration>
              | <method-declaration>
              | <property-declaration>
              | <single-line-comment>
              | <block-comment>
              | <new-line>
```

Inputs:

- `AccessModifier` (optional string).
- `ClassModifiers` (ordered list of modifiers).
- `ClassName` (string).
- `TypeParameters` (optional `<type-parameter-list>`).
- `BaseTypes` (optional `<base-type-list>`).
- `TypeConstraints` (ordered list of `<type-constraint-clause>` instances, optional).
- `Members` (ordered list of `<class-member>` instances).

Output: Complete class block.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/class
```

---

### `<record-declaration>` Rule Primitive

**Philote ID:** `"1b5b9a87-9b4b-4d64-8720-3d7d8f3a6f5e"`

Description: Declares a record type with optional inheritance and members (class-style body).

```bnf
<record-declaration>      ::= <attribute-list>? <access-modifier>? <ws>? <record-modifier>* "record" <ws> <identifier>
                <type-parameter-list>? <base-type-list>? <type-constraint-clause>*
                <ws>? "{" <record-member-list>? "}"

<record-modifier>         ::= "sealed" | "abstract" | "partial"

<record-member-list>      ::= <class-member-list>
```

Inputs:

- `AccessModifier` (optional string).
- `RecordModifiers` (ordered list of modifiers).
- `RecordName` (string).
- `TypeParameters` (optional `<type-parameter-list>`).
- `BaseTypes` (optional `<base-type-list>`).
- `TypeConstraints` (ordered list of `<type-constraint-clause>` instances, optional).
- `Members` (ordered list of `<class-member>` instances).

Output: Record declaration block.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record
2. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record#record-class
```

---

### `<field-declaration>` Rule Primitive

**Philote ID:** `"c81c5942-0918-42b4-bc4c-1b1c9e7192cb"`

Description: Declares one or more fields.

```bnf
<field-declaration>       ::= <attribute-list>? <field-modifier>* <type-reference> <ws> <variable-declarator-list> ";"

<field-modifier>          ::= "const" | "readonly" | "static" | <access-modifier>

<variable-declarator-list>::= <variable-declarator>
              | <variable-declarator-list> "," <ws>? <variable-declarator>

<variable-declarator>     ::= <identifier> (<ws>? "=" <ws>? <expression>)?
```

Inputs:

- `FieldModifiers` (ordered list of modifiers).
- `FieldType` (string type reference).
- `Declarators` (ordered list of `identifier` with optional initializer strings).
- `Attributes` (optional list of rendered attributes).

Output: Single field declaration line.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/classes#fields
```

---

### `<parameter-list>` Rule Primitive

**Philote ID:** `"0e7a4a44-71d4-46cd-8bf1-ff7e1aa02a8d"`

Description: Ordered parameters for methods and constructors.

```bnf
<parameter-list>          ::= "(" <parameter-seq>? ")"

<parameter-seq>           ::= <parameter>
              | <parameter-seq> "," <ws>? <parameter>

<parameter>               ::= <parameter-modifier>? <type-reference> <ws> <identifier> (<ws>? "=" <ws>? <expression>)?

<parameter-modifier>      ::= "in" | "ref" | "out" | "params"
```

Inputs:

- `Parameters` (ordered list of parameter tokens, each including optional modifier and default value).

Output: Parenthesized parameter list.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/params
2. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/classes#methods
```

---

### `<constructor-declaration>` Rule Primitive

**Philote ID:** `"a8234b2e-17dc-4b18-9d6d-2f8ed2f4123c"`

Description: Declares a constructor with optional base/this initializer.

```bnf
<constructor-declaration> ::= <attribute-list>? <access-modifier>? <ws>? <identifier> <parameter-list>
                <constructor-initializer>? <ws>? <block>

<constructor-initializer> ::= ":" <ws>? ("base" | "this") <ws>? <argument-list>
```

Inputs:

- `AccessModifier` (optional string).
- `TypeName` (identifier matching the enclosing type).
- `Parameters` (a `<parameter-list>` instance).
- `Initializer` (string such as `: base(value)` or `: this(...)`, optional).
- `Body` (raw block text including braces).
- `Attributes` (optional list of rendered attributes).

Output: Full constructor declaration.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/constructors
```

---

### `<method-declaration>` Rule Primitive

**Philote ID:** `"cb1f3a32-bf40-4b35-97cf-36e5c8b08e31"`

Description: Declares a method with either a block body or an expression-bodied member.

```bnf
<method-declaration>      ::= <attribute-list>? <method-modifier>* <return-type> <ws> <identifier> <type-parameter-list>?
                <parameter-list> <type-constraint-clause>* <ws>? (<block> | <expression-bodied>)

<method-modifier>         ::= <access-modifier> | "static" | "virtual" | "override" | "abstract" | "sealed" | "extern" | "partial"

<return-type>             ::= <type-reference> | "void"

<expression-bodied>       ::= "=>" <ws>? <expression> ";"
```

Inputs:

- `ReturnType` (string or `void`).
- `MethodName` (string).
- `AccessModifier` (optional string).
- `MethodModifiers` (ordered list of modifiers).
- `TypeParameters` (optional `<type-parameter-list>`).
- `Parameters` (a `<parameter-list>` instance).
- `TypeConstraints` (ordered list of `<type-constraint-clause>` instances, optional).
- `Body` (either block text or expression string plus a flag indicating expression-bodied rendering).
- `Attributes` (optional list of rendered attributes).

Output: Complete method declaration.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/proposals/csharp-6.0/expression-bodied-members
2. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/classes#methods
```

---

<!-- rule-primitives-end -->

---

## Part III — Rule Repository

*This section grows as Rules are written using this Kind. The existing Rule
entries below preserve their stable Philote IDs and source references.*

<!-- rule-repository-start -->

## A Single Rule Definition

Each Rule is a named composition of Rule Primitives with bound input values. The Primitive Composition Table lists the primitives in render order and the inputs applied. Rendering each primitive in order produces the final C# source file for that Rule.

## How Rules Combine into Rule Sets

Rules aggregate into Rule Sets. A Rule Set may define sequencing or dependency (e.g., interfaces before implementations). For this document we focus on a single Rule that renders one source file.

## How an Instantiation Processes Inputs

An instantiation binds concrete values to the inputs of each primitive (namespaces, identifiers, constraints, etc.) and renders the file content. The rendered files then participate in project compilation.

---

## Feature / Module / Rule Set

### Philote Strongly-Typed ID Interfaces

The Rule below renders `IStronglyTypedIds.cs` from the primitives defined above.

#### Rule: IStronglyTypedIds

**Philote ID:** `"f1f9a5d5-5e5a-4a44-8c48-1544a6d1c5ee"`

**Purpose:** Generate `IAbstractStronglyTypedId<TValue>`, `IGuidStronglyTypedId`, and `IIntStronglyTypedId` interfaces.

**Source file:** `src/ATAP.Utilities.StronglyTypedIds.Interfaces/IStronglyTypedIds.cs`

**Top-level derivation:**

```text
<cs-source-file>
├── <using-directive> → using System;
└── <namespace-block-declaration> → namespace ATAP.Utilities.StronglyTypedId { ... }
  ├── <single-line-comment> → // public interface IIdAsStruct<T> { } // Deprecated
  ├── <interface-declaration> → public interface IAbstractStronglyTypedId<TValue> where TValue : notnull { TValue Value { get; init; } }
  ├── <interface-declaration> → public interface IGuidStronglyTypedId : IAbstractStronglyTypedId<Guid> { }
  └── <interface-declaration> → public interface IIntStronglyTypedId : IAbstractStronglyTypedId<int> { }
```

**Primitive Composition Table**

| #   | Primitive                       | Philote ID                             | Role                               | Bound Inputs                                                                                                                                                           |
| --- | ------------------------------- | -------------------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `<cs-source-file>`              | `4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85` | File container                     | `Elements = [2,3]`                                                                                                                                                     |
| 2   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Import System                      | `DirectiveKind = Namespace`; `NamespaceName = "System"`                                                                                                                |
| 3   | `<namespace-block-declaration>` | `d3f0f6b9-1eae-4a8d-9a6f-5d8f2410c8a4` | Namespace wrapper                  | `NamespaceName = "ATAP.Utilities.StronglyTypedId"`; `BodyElements = [4,5,6,7]`                                                                                         |
| 4   | `<single-line-comment>`         | `2f4a8073-b7c8-432e-aac7-65f6063a1e2a` | Deprecated marker                  | `CommentText = " public interface IIdAsStruct<T> { } // Deprecated"`                                                                                                   |
| 5   | `<interface-declaration>`       | `6a972b5b-5da7-4a73-b5d6-564e1b305a0b` | `IAbstractStronglyTypedId<TValue>` | `AccessModifier = "public"`; `InterfaceName = "IAbstractStronglyTypedId"`; `TypeParameters = <TValue>`; `TypeConstraints = [where TValue : notnull]`; `Members = [5a]` |
| 5a  | `<property-declaration>`        | `6d2e4c24-4f59-487f-9e6d-2e65f97a6dd0` | `Value` property                   | `PropertyType = "TValue"`; `PropertyName = "Value"`; `Accessors = [get, init]`                                                                                         |
| 6   | `<interface-declaration>`       | `6a972b5b-5da7-4a73-b5d6-564e1b305a0b` | `IGuidStronglyTypedId`             | `AccessModifier = "public"`; `InterfaceName = "IGuidStronglyTypedId"`; `BaseTypes = [: IAbstractStronglyTypedId<Guid>]`; `Members = []`                                |
| 7   | `<interface-declaration>`       | `6a972b5b-5da7-4a73-b5d6-564e1b305a0b` | `IIntStronglyTypedId`              | `AccessModifier = "public"`; `InterfaceName = "IIntStronglyTypedId"`; `BaseTypes = [: IAbstractStronglyTypedId<int>]`; `Members = []`                                  |

**Constraint details (item 5):**

| Type Parameter | Constraints |
| -------------- | ----------- |
| `TValue`       | `notnull`   |

**Member details (item 5a):**

| Member  | Type     | Accessors    |
| ------- | -------- | ------------ |
| `Value` | `TValue` | `get; init;` |

**Inputs to the Rule:**

| Input                   | Value                              |
| ----------------------- | ---------------------------------- |
| `UsingNamespaces`       | `["System"]`                       |
| `NamespaceName`         | `"ATAP.Utilities.StronglyTypedId"` |
| `AbstractInterfaceName` | `"IAbstractStronglyTypedId"`       |
| `TypeParameterName`     | `"TValue"`                         |
| `TypeConstraint`        | `"notnull"`                        |
| `ValuePropertyType`     | `"TValue"`                         |
| `ValuePropertyName`     | `"Value"`                          |
| `GuidInterfaceName`     | `"IGuidStronglyTypedId"`           |
| `GuidBaseType`          | `"IAbstractStronglyTypedId<Guid>"` |
| `IntInterfaceName`      | `"IIntStronglyTypedId"`            |
| `IntBaseType`           | `"IAbstractStronglyTypedId<int>"`  |

**Processing notes:**

- The `init` accessor requires C# 9 or later.
- Derived interfaces have empty bodies; they specialize the generic interface for `Guid` and `int` value types.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/interface
2. https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/properties
3. https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/generics/constraints-on-type-parameters
```

### Philote Identity Interfaces

The Rule below renders `IPhilote.cs` from the primitives defined above.

#### Rule: IPhilote

**Philote ID:** `"a8e3b1d0-1c6f-4f6f-9c7b-3c5d72e1b944"`

**Purpose:** Generate the Philote identity interfaces (`IGuidPhilote<TId>`, `IIntPhilote<TId>`, and `IAbstractPhilote<TId, TValue>`).

**Source file:** `src/ATAP.Utilities.Philote.Interfaces/IPhilote.cs`

**Top-level derivation:**

```text
<cs-source-file>
├── <using-directive> → using System;
├── <using-directive> → using ATAP.Utilities.StronglyTypedId;
├── <using-directive> → using ATAP.Utilities.DateTime.Interfaces;
├── <using-directive> → using System.Collections.Generic;
├── <using-directive> → using ATAP.Utilities.DateTime.Model;
└── <namespace-block-declaration> → namespace ATAP.Utilities.Philote { ... }
  ├── <interface-declaration> → public interface IGuidPhilote<TId> : IAbstractPhilote<TId, Guid> where TId : IAbstractStronglyTypedId<Guid>, new() { }
  ├── <interface-declaration> → public interface IIntPhilote<TId> : IAbstractPhilote<TId, int> where TId : IAbstractStronglyTypedId<int>, new() { }
  └── <interface-declaration> → public interface IAbstractPhilote<TId, TValue> where TId : IAbstractStronglyTypedId<TValue>, new() where TValue : notnull { TId Id { get; } IReadOnlyDictionary<string, IAbstractStronglyTypedId<TValue>> AdditionalIds { get; } IReadOnlyList<TemporalValidityPeriod> ValidityPeriods { get; } bool IsValidAt(UtcInstant instant); }
```

**Primitive Composition Table**

| #   | Primitive                       | Philote ID                             | Role                                                  | Bound Inputs                                                                                                                                                                     |
| --- | ------------------------------- | -------------------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `<cs-source-file>`              | `4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85` | File container                                        | `Elements = [2,3,4,5,6,7]`                                                                                                                                                       |
| 2   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Import System                                         | `DirectiveKind = Namespace`; `NamespaceName = "System"`                                                                                                                          |
| 3   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Import StronglyTypedId                                | `DirectiveKind = Namespace`; `NamespaceName = "ATAP.Utilities.StronglyTypedId"`                                                                                                  |
| 4   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Import DateTime interfaces                            | `DirectiveKind = Namespace`; `NamespaceName = "ATAP.Utilities.DateTime.Interfaces"`                                                                                              |
| 5   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Import Collections.Generic                            | `DirectiveKind = Namespace`; `NamespaceName = "System.Collections.Generic"`                                                                                                      |
| 6   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Import DateTime model                                 | `DirectiveKind = Namespace`; `NamespaceName = "ATAP.Utilities.DateTime.Model"`                                                                                                   |
| 7   | `<namespace-block-declaration>` | `d3f0f6b9-1eae-4a8d-9a6f-5d8f2410c8a4` | Namespace wrapper                                     | `NamespaceName = "ATAP.Utilities.Philote"`; `BodyElements = [8,9,10]`                                                                                                            |
| 8   | `<interface-declaration>`       | `6a972b5b-5da7-4a73-b5d6-564e1b305a0b` | `IGuidPhilote<TId>`                                   | `AccessModifier = "public"`; `InterfaceName = "IGuidPhilote"`; `TypeParameters = <TId>`; `BaseTypes = [: IAbstractPhilote<TId, Guid>]`; `TypeConstraints = [8a]`; `Members = []` |
| 8a  | `<type-constraint-clause>`      | `8ad77df8-8366-40f8-99b5-ff2a2a8d5da9` | `where TId : IAbstractStronglyTypedId<Guid>, new()`   | `TypeParameterName = "TId"`; `Constraints = ["IAbstractStronglyTypedId<Guid>", "new()"]`                                                                                         |
| 9   | `<interface-declaration>`       | `6a972b5b-5da7-4a73-b5d6-564e1b305a0b` | `IIntPhilote<TId>`                                    | `AccessModifier = "public"`; `InterfaceName = "IIntPhilote"`; `TypeParameters = <TId>`; `BaseTypes = [: IAbstractPhilote<TId, int>]`; `TypeConstraints = [9a]`; `Members = []`   |
| 9a  | `<type-constraint-clause>`      | `8ad77df8-8366-40f8-99b5-ff2a2a8d5da9` | `where TId : IAbstractStronglyTypedId<int>, new()`    | `TypeParameterName = "TId"`; `Constraints = ["IAbstractStronglyTypedId<int>", "new()"]`                                                                                          |
| 10  | `<interface-declaration>`       | `6a972b5b-5da7-4a73-b5d6-564e1b305a0b` | `IAbstractPhilote<TId, TValue>`                       | `AccessModifier = "public"`; `InterfaceName = "IAbstractPhilote"`; `TypeParameters = <TId, TValue>`; `TypeConstraints = [10a,10b]`; `Members = [10c,10d,10e,10f]`                |
| 10a | `<type-constraint-clause>`      | `8ad77df8-8366-40f8-99b5-ff2a2a8d5da9` | `where TId : IAbstractStronglyTypedId<TValue>, new()` | `TypeParameterName = "TId"`; `Constraints = ["IAbstractStronglyTypedId<TValue>", "new()"]`                                                                                       |
| 10b | `<type-constraint-clause>`      | `8ad77df8-8366-40f8-99b5-ff2a2a8d5da9` | `where TValue : notnull`                              | `TypeParameterName = "TValue"`; `Constraints = ["notnull"]`                                                                                                                      |
| 10c | `<property-declaration>`        | `6d2e4c24-4f59-487f-9e6d-2e65f97a6dd0` | `Id` property                                         | `PropertyType = "TId"`; `PropertyName = "Id"`; `Accessors = [get]`                                                                                                               |
| 10d | `<property-declaration>`        | `6d2e4c24-4f59-487f-9e6d-2e65f97a6dd0` | `AdditionalIds` property                              | `PropertyType = "IReadOnlyDictionary<string, IAbstractStronglyTypedId<TValue>>"`; `PropertyName = "AdditionalIds"`; `Accessors = [get]`                                         |
| 10e | `<property-declaration>`        | `6d2e4c24-4f59-487f-9e6d-2e65f97a6dd0` | `ValidityPeriods` property                            | `PropertyType = "IReadOnlyList<TemporalValidityPeriod>"`; `PropertyName = "ValidityPeriods"`; `Accessors = [get]`                                                               |
| 10f | `<method-declaration>`          | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | point-in-time validity                                | `ReturnType = "bool"`; `MethodName = "IsValidAt"`; `Parameters = [UtcInstant instant]`                                                                                           |

**Constraint details (items 8a, 9a, 10a, 10b):**

| Type Parameter   | Constraints                                 |
| ---------------- | ------------------------------------------- |
| `TId` (Guid)     | `IAbstractStronglyTypedId<Guid>`, `new()`   |
| `TId` (int)      | `IAbstractStronglyTypedId<int>`, `new()`    |
| `TId` (abstract) | `IAbstractStronglyTypedId<TValue>`, `new()` |
| `TValue`         | `notnull`                                   |

**Member details for `IAbstractPhilote<TId, TValue>` (items 10c–10f):**

| Member | Type | Accessors / signature |
| --- | --- | --- |
| `Id` | `TId` | `get;` |
| `AdditionalIds` | `IReadOnlyDictionary<string, IAbstractStronglyTypedId<TValue>>` | `get;` |
| `ValidityPeriods` | `IReadOnlyList<TemporalValidityPeriod>` | `get;` |
| `IsValidAt` | `bool` | `(UtcInstant instant)` |

**Inputs to the Rule:**

| Input                   | Value                                                                                                                          |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `UsingNamespaces`       | `["System","System.Collections.Generic","ATAP.Utilities.DateTime.Interfaces","ATAP.Utilities.DateTime.Model","ATAP.Utilities.StronglyTypedId"]` |
| `NamespaceName`         | `"ATAP.Utilities.Philote"`                                                                                                     |
| `GuidInterfaceName`     | `"IGuidPhilote"`                                                                                                               |
| `IntInterfaceName`      | `"IIntPhilote"`                                                                                                                |
| `AbstractInterfaceName` | `"IAbstractPhilote"`                                                                                                           |

**Processing notes:**

- `AdditionalIds` and `ValidityPeriods` are non-null immutable/read-only views.
- `new()` constraints are required because implementations may need to construct `TId` instances at runtime.
- `IsValidAt` applies the DateTime contract's half-open interval semantics.
- No third-party temporal type appears in the public Philote interface.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/interface
2. https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/generics/constraints-on-type-parameters
3. https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/properties
4. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/nullable-references
```

### Strongly-Typed ID Implementations

The Rule below renders `StronglyTypedIds.cs` (concrete and abstract strongly-typed ID implementations plus converters and helper functions).

#### Rule: StronglyTypedIds

**Philote ID:** `"c4a4b59f-1f8e-4bdb-9c8d-7a23f3b3d6e2"`

**Purpose:** Generate records `GuidStronglyTypedId`, `IntStronglyTypedId`, the generic `AbstractStronglyTypedId<TValue>`, converters, and helper utilities.

**Source file:** [src/ATAP.Utilities.StronglyTypedIds/StronglyTypedIds.cs](src/ATAP.Utilities.StronglyTypedIds/StronglyTypedIds.cs#L1-L330)

**Top-level derivation (condensed):**

```text
<cs-source-file>
├── <using-directive> ×11
└── <namespace-block-declaration> → namespace ATAP.Utilities.StronglyTypedId { ... }
  ├── <single-line-comment> (attributions)
  ├── <record-declaration> → GuidStronglyTypedId : AbstractStronglyTypedId<Guid>, IGuidStronglyTypedId { ... }
  ├── <record-declaration> → IntStronglyTypedId : AbstractStronglyTypedId<int>, IIntStronglyTypedId { ... }
  ├── <record-declaration> → AbstractStronglyTypedId<TValue> : IAbstractStronglyTypedId<TValue> where TValue : notnull { ... }
  ├── <class-declaration>  → StronglyTypedIdConverter<TValue> : TypeConverter { fields + overrides }
  ├── <class-declaration>  → StronglyTypedIdConverter : TypeConverter { delegates to inner converter }
  └── <class-declaration>  → StronglyTypedIdHelper { static factories and helpers }
```

**Primitive Composition Table (key items)**

| #   | Primitive                       | Philote ID                             | Role                                    | Bound Inputs (high level)                                                                                                                                                                          |
| --- | ------------------------------- | -------------------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `<cs-source-file>`              | `4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85` | File container                          | `Elements = [usings, ns]`                                                                                                                                                                          |
| 2   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Imports System, Collections, Linq, etc. | 11 namespace imports                                                                                                                                                                               |
| 3   | `<namespace-block-declaration>` | `d3f0f6b9-1eae-4a8d-9a6f-5d8f2410c8a4` | Namespace wrapper                       | `NamespaceName = "ATAP.Utilities.StronglyTypedId"; BodyElements = [4..10]`                                                                                                                         |
| 4   | `<single-line-comment>`         | `2f4a8073-b7c8-432e-aac7-65f6063a1e2a` | Attribution comments                    | Text as in source                                                                                                                                                                                  |
| 5   | `<record-declaration>`          | `1b5b9a87-9b4b-4d64-8720-3d7d8f3a6f5e` | `GuidStronglyTypedId`                   | `RecordModifiers = []`; `BaseTypes = [: AbstractStronglyTypedId<Guid>, IGuidStronglyTypedId]`; `Members = [constructors, method ToString]`                                                         |
| 6   | `<record-declaration>`          | `1b5b9a87-9b4b-4d64-8720-3d7d8f3a6f5e` | `IntStronglyTypedId`                    | `BaseTypes = [: AbstractStronglyTypedId<int>, IIntStronglyTypedId]`; similar members                                                                                                               |
| 7   | `<record-declaration>`          | `1b5b9a87-9b4b-4d64-8720-3d7d8f3a6f5e` | `AbstractStronglyTypedId<TValue>`       | `RecordModifiers = [abstract]`; `TypeParameters = <TValue>`; `TypeConstraints = [where TValue : notnull]`; `Members = [property Value, constructors, methods AllowedTValue/RandomTValue/ToString]` |
| 8   | `<class-declaration>`           | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | `StronglyTypedIdConverter<TValue>`      | Members: static field `IdValueConverter`, constructors, `CanConvert*`, `Convert*` methods                                                                                                          |
| 9   | `<class-declaration>`           | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | `StronglyTypedIdConverter`              | Members: static dictionary field, constructor, overrides delegating to inner converter                                                                                                             |
| 10  | `<class-declaration>`           | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | `StronglyTypedIdHelper`                 | Members: static factory cache, `GetFactory`, reflection helpers, `IsStronglyTypedId`                                                                                                               |

**Selected member rendering aids**

| Member kind              | Primitive used              | Example binding                                                                                                                                       |
| ------------------------ | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Field                    | `<field-declaration>`       | `FieldModifiers = ["private", "static", "readonly"]`; `FieldType = "TypeConverter"`; `Declarators = ["IdValueConverter = GetIdValueConverter()"]`     |
| Constructor              | `<constructor-declaration>` | `AccessModifier = "public"`; `TypeName = "GuidStronglyTypedId"`; `Parameters = ()` or `(Guid value)`; `Initializer = ": base(value)"`; `Body = "{ }"` |
| Method (expression body) | `<method-declaration>`      | `ReturnType = "string"`; `MethodName = "ToString"`; `MethodModifiers = ["override"]`; `Parameters = ()`; `Body = "=> base.ToString();"`               |
| Method (block body)      | `<method-declaration>`      | `ReturnType = "object"`; `MethodName = "ConvertTo"`; `MethodModifiers = ["public", "override"]`; `Body = source block lines 188–219`                  |

**Inputs to the Rule:**

- `UsingNamespaces = ["System","System.ComponentModel","System.Collections.Concurrent","System.Globalization","System.Linq.Expressions","System.Linq","System.Reflection","System.Collections","System.Collections.Generic","System.Diagnostics.CodeAnalysis"]`
- `NamespaceName = "ATAP.Utilities.StronglyTypedId"`
- Record and class names as shown in the composition table.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record
2. https://learn.microsoft.com/en-us/dotnet/api/system.componentmodel.typeconverter
3. [src/ATAP.Utilities.StronglyTypedIds/StronglyTypedIds.cs](src/ATAP.Utilities.StronglyTypedIds/StronglyTypedIds.cs#L1-L330)
```

### Philote Implementations

The Rule below renders `Philote.cs` (concrete Philote records built on strongly-typed IDs).

#### Rule: PhiloteRecords

**Philote ID:** `"5a2a7d5f-017d-4c89-98c5-7d4ab0f4ec3b"`

**Purpose:** Generate `AbstractPhilote<TId, TValue>`, `IntPhilote<TId>`, and `GuidPhilote<TId>` immutable class implementations.

**Source file:** [src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/Philote.cs](src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/Philote.cs#L1-L120)

**Top-level derivation (condensed):**

```text
<cs-source-file>
├── <using-directive> ×6
└── <namespace-block-declaration> → namespace ATAP.Utilities.Philote { ... }
  ├── <class-declaration> → abstract AbstractPhilote<TId, TValue> : IAbstractPhilote<TId, TValue> where TId : AbstractStronglyTypedId<TValue>, new() where TValue : notnull { ... }
  ├── <class-declaration> → sealed IntPhilote<TId> : AbstractPhilote<TId, int>, IIntPhilote<TId> where TId : IntStronglyTypedId, new() { ... }
  └── <class-declaration> → sealed GuidPhilote<TId> : AbstractPhilote<TId, Guid>, IGuidPhilote<TId> where TId : GuidStronglyTypedId, new() { ... }
```

**Primitive Composition Highlights**

| #   | Primitive                       | Philote ID                             | Role                                         | Bound Inputs (high level)                                                                                                                                                              |
| --- | ------------------------------- | -------------------------------------- | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `<cs-source-file>`              | `4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85` | File container                               | `Elements = [usings, ns]`                                                                                                                                                              |
| 2   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Imports System, Collections, StronglyTypedId | 6 namespace imports                                                                                                                                                                    |
| 3   | `<namespace-block-declaration>` | `d3f0f6b9-1eae-4a8d-9a6f-5d8f2410c8a4` | Namespace wrapper                            | `NamespaceName = "ATAP.Utilities.Philote"; BodyElements = [4,5,6]`                                                                                                                     |
| 4   | `<record-declaration>`          | `1b5b9a87-9b4b-4d64-8720-3d7d8f3a6f5e` | `AbstractPhilote<TId, TValue>`               | `RecordModifiers = [abstract]`; `TypeConstraints = [where TId : AbstractStronglyTypedId<TValue>, new(); where TValue : notnull]`; members include properties, constructors, body logic |
| 5   | `<record-declaration>`          | `1b5b9a87-9b4b-4d64-8720-3d7d8f3a6f5e` | `IntPhilote<TId>`                            | `BaseTypes = [: AbstractPhilote<TId, int>, IIntPhilote<TId>]`; constructors and overrides                                                                                              |
| 6   | `<record-declaration>`          | `1b5b9a87-9b4b-4d64-8720-3d7d8f3a6f5e` | `GuidPhilote<TId>`                           | `BaseTypes = [: AbstractPhilote<TId, Guid>, IGuidPhilote<TId>]`; constructors and overrides                                                                                            |

**Constructor tabular bindings**

| Type              | Parameters (primitive `<parameter-list>`)                                                                                                                                   | Initializer                | Body summary                                         |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- | ---------------------------------------------------- |
| `AbstractPhilote` | `(TId? id = default, IEnumerable<KeyValuePair<string, IAbstractStronglyTypedId<TValue>>>? additionalIds = default, IEnumerable<TemporalValidityPeriod>? validityPeriods = default)` | none | Copies identity metadata and validates an immutable period set. |
| `IntPhilote` | `()`; `(TId id)`; `(TId? id, IEnumerable<KeyValuePair<string, IAbstractStronglyTypedId<int>>>? additionalIds, IEnumerable<TemporalValidityPeriod>? validityPeriods)` | `: base(...)` | Delegates to base and exposes immutable validity transitions. |
| `GuidPhilote` | same shapes as `IntPhilote`, with `Guid` types | `: base(...)` | Delegates to base and exposes immutable validity transitions. |

**Inputs to the Rule:**

- `UsingNamespaces = ["System","System.Collections.Generic","System.Collections.Immutable","System.Linq","ATAP.Utilities.DateTime.Interfaces","ATAP.Utilities.DateTime.Model","ATAP.Utilities.StronglyTypedId"]`
- `NamespaceName = "ATAP.Utilities.Philote"`
- Record names and constraints as shown above.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record
2. https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/generics/constraints-on-type-parameters
3. [src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/Philote.cs](src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/Philote.cs#L1-L120)
```

### Activator Replacement Utilities

The Rule below renders `ActivatorReplacement.cs` (fast reflective factory helpers).

#### Rule: ActivatorReplacement

**Philote ID:** `"01d7c067-65b8-4370-bacf-2abf5ca7f7b8"`

**Purpose:** Generate `InstanceFactory` and `InstanceFactoryGeneric<...>` classes that cache expression-compiled constructors.

**Source file:** [src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ActivatorReplacement.cs](src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ActivatorReplacement.cs#L1-L140)

**Top-level derivation (condensed):**

```text
<cs-source-file>
├── <using-directive> → using System;
├── <using-directive> → using System.Collections.Concurrent;
├── <using-directive> → using System.Collections.Generic;
├── <using-directive> → using System.Linq;
└── <using-directive> → using System.Linq.Expressions;
└── <namespace-block-declaration> → namespace ATAP.Utilities.Philote { ... }
  ├── <class-declaration> → static InstanceFactory { overloaded CreateInstance methods, cache builder }
  ├── <class-declaration> → static InstanceFactoryGeneric<TArg1, TArg2, TArg3> { compiled constructor cache }
  └── <class-declaration> → TypeToIgnore { marker type }
```

**Primitive Composition Highlights**

| #   | Primitive                       | Philote ID                             | Role                                                   | Bound Inputs (high level)                                                                                  |
| --- | ------------------------------- | -------------------------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| 1   | `<cs-source-file>`              | `4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85` | File container                                         | `Elements = [usings, ns]`                                                                                  |
| 2   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Imports System namespaces needed for expressions       | 5 namespace imports                                                                                        |
| 3   | `<namespace-block-declaration>` | `d3f0f6b9-1eae-4a8d-9a6f-5d8f2410c8a4` | Namespace wrapper                                      | `NamespaceName = "ATAP.Utilities.Philote"; BodyElements = [4,5,6]`                                         |
| 4   | `<class-declaration>`           | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | `InstanceFactory` (static)                             | `ClassModifiers = ["static"]`; members: cached delegate dictionary, overloads using `<method-declaration>` |
| 5   | `<class-declaration>`           | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | `InstanceFactoryGeneric<TArg1, TArg2, TArg3>` (static) | `TypeParameters = <TArg1,TArg2,TArg3>`; members: cached functions, `CreateInstance` overload, `CacheFunc`  |
| 6   | `<class-declaration>`           | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | `TypeToIgnore`                                         | Empty marker class                                                                                         |

**Inputs to the Rule:**

- `UsingNamespaces = ["System","System.Collections.Concurrent","System.Collections.Generic","System.Linq","System.Linq.Expressions"]`
- `NamespaceName = "ATAP.Utilities.Philote"`
- Class names and modifiers as shown above.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/api/system.linq.expressions.expression
2. [src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ActivatorReplacement.cs](src/ATAP.Utilities.Philote/ATAP.Utilities.Philote.CSharp/ActivatorReplacement.cs#L1-L140)
```

### StronglyTypedId System.Text.Json Converters

#### Rule: StronglyTypedIdJsonConverterSystemTextJson

**Philote ID:** "6e7f54c4-0b7d-4f0a-8d57-5f1f96c4d7b8"

**Purpose:** Render generic System.Text.Json converter and factory for StronglyTypedId records.

**Source file:** [src/ATAP.Utilities.StronglyTypedId/JsonConverter.Shim.SystemTextJson/StronglyTypedIdJsonConverterSystemTextJson.cs](src/ATAP.Utilities.StronglyTypedId/JsonConverter.Shim.SystemTextJson/StronglyTypedIdJsonConverterSystemTextJson.cs#L1-L116)

**Top-level derivation (condensed):**

```text
<cs-source-file>
├── <using-directive> ×4
└── <namespace-block-declaration> → ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson { ... }
  ├── <single-line-comment> (attribution)
  ├── <class-declaration> → StronglyTypedIdJsonConverter<TStronglyTypedId, TValue> : JsonConverter<TStronglyTypedId>
  └── <class-declaration> → StronglyTypedIdJsonConverterFactory : JsonConverterFactory
```

**Primitive Composition Highlights**

| #   | Primitive                       | Philote ID                             | Role                                                     | Bound Inputs (high level)                                                                                                                                 |
| --- | ------------------------------- | -------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `<cs-source-file>`              | `4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85` | File container                                           | `Elements = [usings, ns]`                                                                                                                                 |
| 2   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Imports System, Concurrent, Json namespaces              | 4 namespace imports                                                                                                                                       |
| 3   | `<namespace-block-declaration>` | `d3f0f6b9-1eae-4a8d-9a6f-5d8f2410c8a4` | Namespace wrapper                                        | `NamespaceName = "ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson"; Body = [4,5]`                                                        |
| 4   | `<class-declaration>`           | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | `StronglyTypedIdJsonConverter<TStronglyTypedId, TValue>` | Generic converter overriding `Read` and `Write` with constraints `where TStronglyTypedId : IAbstractStronglyTypedId<TValue>` and `where TValue : notnull` |
| 5   | `<class-declaration>`           | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | `StronglyTypedIdJsonConverterFactory`                    | Inherits `JsonConverterFactory`; overrides `CanConvert`, `CreateConverter`; caches converters                                                             |

Inputs to the Rule include converter cache field, helper invocations (`StronglyTypedIdHelper.GetFactory`, `IsStronglyTypedId`), and JsonSerializer calls.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/api/system.text.json.serialization.jsonconverter
2. Source file linked above
```

### Philote System.Text.Json Converters

#### Rule: PhiloteJsonConverterSystemTextJson

**Philote ID:** "7d1a3b4c-2f5e-4c9f-9a64-5c7d8e9f0a1b"

**Purpose:** Generate the Philote converter factory and closed generic converter
that implement the canonical identity and temporal-validity JSON contract.

**Source file:** [src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/JsonConverter.Shim.SystemTextJson.cs](../src/ATAP.Utilities.Philote/JsonConverter.Shim.SystemTextJson/JsonConverter.Shim.SystemTextJson.cs)

**Top-level derivation (condensed):**

```text
<cs-source-file>
├── <using-directive> ×9
└── <namespace-block-declaration> → ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson { ... }
  ├── <class-declaration> → PhiloteConverterFactory : JsonConverterFactory { cache, CanConvert, CreateConverter }
  └── <class-declaration> → PhiloteJsonConverter<TPhilote,TId,TValue> : JsonConverter<TPhilote> { Read, Write, validation helpers }
```

**Primitive Composition Highlights**

| #   | Primitive                       | Philote ID                             | Role                                             | Bound Inputs (high level)                                                                                 |
| --- | ------------------------------- | -------------------------------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| 1   | `<cs-source-file>`              | `4f6dbde9-52f2-4d3f-82a1-7b9f3a6c4d85` | File container                                   | `Elements = [usings, ns]`                                                                                 |
| 2   | `<using-directive>`             | `8b9e0f19-5272-4c1f-90db-e1e6b0c5d3f2` | Imports JSON, DateTime, identity, and collections | 9 namespace imports |
| 3   | `<namespace-block-declaration>` | `d3f0f6b9-1eae-4a8d-9a6f-5d8f2410c8a4` | Namespace wrapper | `NamespaceName = "ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson"; Body=[4,5]` |
| 4   | `<class-declaration>`           | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | `PhiloteConverterFactory` : `JsonConverterFactory` | Finds the closed Philote interface, creates and caches the generic converter. |
| 5   | `<class-declaration>`           | `5c1f93b8-6db5-4aaf-94ef-7b3d8b8a9d3a` | `PhiloteJsonConverter<TPhilote,TId,TValue>` | Reads/writes `id`, `additionalIds`, and `validityPeriods`; rejects duplicate canonical and retired temporal properties. |

The writer emits validity periods in their validated order. Each period uses
`validFromUtc` and `validToUtc`; a null end is open-ended. The reader delegates
period-set validation to `TemporalValidityPeriodSet`, so overlapping intervals,
duplicate starts, and multiple or non-final open ends fail closed.

Attribution:

```text
1. https://learn.microsoft.com/en-us/dotnet/api/system.text.json.serialization.jsonconverterfactory
2. Source file linked above
```

<!-- rule-repository-end -->

---

## Part IV — Rule Sets

*No formal C# Rule Set is defined in the retained corpus. This section is
intentionally empty until a Rule Set and its stable Philote ID are authored.*

<!-- rule-sets-start -->
<!-- rule-sets-end -->

---

*Last updated: 2026-08-09 | Maintained by: `.claude/skills/new-rule-kind/SKILL.md`*
