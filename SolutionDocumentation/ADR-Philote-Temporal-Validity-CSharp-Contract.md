# ADR: Philote temporal-validity C# contract

Status: Accepted at Gate PTV-G0; amended before Gate PTV-G5

Date: 2026-08-08; amended 2026-08-09

Owner: PTV-010 / Task 14.21.e

## Decision

ATAP owns the public temporal contract used by Philote and its consumers. The
contract represents UTC instants, non-negative durations, and immutable half-open
validity periods without exposing an `Itenso.TimePeriod` type. Itenso remains a
private implementation dependency of the DateTime model/adapter project.

`TemporalValidityPeriod` is a sealed record, not a record struct. A reference type
prevents `default(TemporalValidityPeriod)` from bypassing constructor validation and
silently creating an open-ended period at the minimum timestamp.
`TemporalValidityPeriodSet` is an immutable structural value object that implements
`IReadOnlyList<TemporalValidityPeriod>`; it is not a mutable collection service.

This ADR froze the Wave 0 C# contract accepted at PTV-G0. Before PTV-G5, the
contract was amended to extract `ITemporalValidityPeriod` and remove the
Philote.Interfaces dependency on DateTime.Model. The amendment changes no SQL,
seed, database, package identity, BuildMaster, or deployment boundary.

## Evidence boundary

### Content-summary coverage finding

The derived tags were `Philote`, `temporal-validity`, `DateTime`, `UTC`,
`Itenso.TimePeriod`, `serialization`, `immutability`, `equality`, `adapter`, and
`consumer`. The required `gather-content-summary` call was attempted with `Depth=3`,
`Width=2`, and `Instance=production`, but no such callable capability exists in this
worker's active tool surface. The sprint board records the retrieval implementation as
stubbed with marker `CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED`. No semantic summary is
claimed; the facts below come from direct source inspection.

### Verified source facts

- `IAbstractPhilote` currently exposes nullable
  `IEnumerable<ITimeBlock>? TimeBlocks` and a nullable mutable
  `ConcurrentDictionary`.
- `AbstractPhilote` preserves a non-null `timeBlocks` enumerable without
  materializing or validating it and leaves the property null when omitted.
- ComputerInventory and CryptoMiner use `ITimeBlock Moment` where the value is an
  observation instant. `RigConfig` currently uses `new TimeBlock()` as an anytime
  sentinel.
- CryptoCoin uses `TimeBlock` as a duration and reads `Duration.Ticks` in reward
  calculations.
- Process tests use `TimeInterval(DateTime)`, `ExpandTo(DateTime)`, and `Duration` for
  elapsed timing; that test-only use does not justify a production wrapper.
- Serializer fixtures assert vendor fields such as `IsAnytime`, `IsMoment`, `Start`,
  `End`, `Duration`, and `DurationDescription`; Philote fixtures use `TimeBlocks`.
- The PTV-000 inventory verified 40 Itenso imports, 24 project references, and active
  public coupling in Philote, ComputerInventory, CryptoCoin, and CryptoMiner.

### Adopted invariants used as authority

- Philote periods describe business-valid identity existence.
- Every interval is `[ValidFromUtc, ValidToUtc)`; null `ValidToUtc` means no known
  end.
- Zero-width and reversed periods are invalid. Gaps are legal; overlaps are not.
- A set is non-null, ordered, immutable, and has at most one open-ended period, which
  is last.
- Omitted Philote collections normalize to empty immutable collections.
- Legacy Itenso-shaped payloads are rejected rather than reinterpreted.

Verified facts and adopted invariants are evidence. The remainder of this document is
the proposed normative contract to ratify at PTV-G0.

## Assembly and namespace contract

| Project | Namespace | Public responsibility |
| --- | --- | --- |
| `ATAP.Utilities.DateTime.Interfaces` | `ATAP.Utilities.DateTime.Interfaces` | `UtcInstant`, `TemporalDuration`, `IHalfOpenTemporalPeriod`, `ITemporalValidityPeriod`, and `ITemporalPeriodCalculator` |
| `ATAP.Utilities.DateTime.Model` | `ATAP.Utilities.DateTime.Model` | `TemporalValidityPeriod`, `TemporalValidityPeriodSet`, and `ItensoTemporalPeriodCalculator` |
| `ATAP.Utilities.DateTime.StringConstants` | `ATAP.Utilities.DateTime.StringConstants` | Stable JSON and persistence names only |
| `ATAP.Utilities.DateTime` | `ATAP.Utilities.DateTime` | Package aggregation, `ToUnixTime`, and DI registration |

The two small value types live with the interfaces so
`ATAP.Utilities.DateTime.Model` can depend on `Interfaces` without a circular
project reference. The Model project is the sole project permitted a direct
`TimePeriodLibrary.NET` reference, marked private in package metadata. Neither the
interfaces nor any public member in Model may name an Itenso type.

## Plan variance resolved by this ADR

PTV-G0 approval of this ADR supersedes only the following location and dependency
prose in
`_Planning/InformationForTheFuture/Plan_PhiloteTemporalValidity_Adoption.md`. Task
intent, acceptance behavior, and ownership otherwise remain unchanged.

1. PTV-130 calls `UtcInstant` and `TemporalDuration` "the two model types." That
   phrase remains their semantic classification, but it no longer means that their
   files compile into `ATAP.Utilities.DateTime.Model`. They compile into
   `ATAP.Utilities.DateTime.Interfaces` because both
   `IHalfOpenTemporalPeriod` and `ITemporalPeriodCalculator` name them in public
   signatures. Putting them in Model would require Interfaces to reference Model
   while Model already references Interfaces, creating a project cycle. PTV-130
   retains sole ownership of implementing the two types and their focused tests;
   PTV-120 owns only the two interfaces and their focused tests, even though the
   resulting source files share the Interfaces project.
2. The plan's single
   `ATAP.Utilities.Philote.Interfaces -> ATAP.Utilities.DateTime.Model` edge is
   replaced by a direct
   `ATAP.Utilities.Philote.Interfaces -> ATAP.Utilities.DateTime.Interfaces`
   reference. `ITemporalValidityPeriod` is the semantic validity-period contract,
   while `TemporalValidityPeriod` remains its validated concrete implementation in
   DateTime.Model. Philote.Interfaces therefore names no model assembly in its
   public surface. Philote.Models references both assemblies because it implements
   the interface using `TemporalValidityPeriodSet`.
3. The project-graph qualifier "DateTime.Model to TimePeriodLibrary.NET, private
   implementation dependency only if needed" is resolved from optional to required.
   DateTime.Model
   owns `ItensoTemporalPeriodCalculator`, so it owns the sole direct
   `TimePeriodLibrary.NET` reference and marks it private in package metadata.
   PTV-160 owns adding that reference together with the adapter implementation and
   boundary-equivalence tests; PTV-100 scaffolds the Model project without adding a
   second or speculative vendor reference.

The resulting relevant graph is therefore:

```text
ATAP.Utilities.DateTime.Model
  -> ATAP.Utilities.DateTime.Interfaces
  -> ATAP.Utilities.DateTime.StringConstants
  -> TimePeriodLibrary.NET (sole direct reference; private)

ATAP.Utilities.Philote.Interfaces
  -> ATAP.Utilities.DateTime.Interfaces

ATAP.Utilities.Philote.Models
  -> ATAP.Utilities.Philote.Interfaces
  -> ATAP.Utilities.DateTime.Interfaces
  -> ATAP.Utilities.DateTime.Model
```

No other plan edge or Wave 1 task boundary is changed by this variance.

## Frozen public surface

The signatures below are normative. XML documentation and attributes may be added
without changing them.

```csharp
namespace ATAP.Utilities.DateTime.Interfaces;

public readonly record struct UtcInstant : IComparable<UtcInstant>
{
  public UtcInstant(DateTimeOffset value);
  public DateTimeOffset Value { get; }
  public int CompareTo(UtcInstant other);
}

public readonly record struct TemporalDuration : IComparable<TemporalDuration>
{
  public TemporalDuration(TimeSpan timeSpan);
  public TimeSpan TimeSpan { get; }
  public long Ticks { get; }
  public int CompareTo(TemporalDuration other);
}

public interface IHalfOpenTemporalPeriod
{
  UtcInstant ValidFromUtc { get; }
  UtcInstant? ValidToUtc { get; }
  bool IsOpenEnded { get; }
  TemporalDuration? Duration { get; }
  bool Contains(UtcInstant instant);
}

public interface ITemporalValidityPeriod : IHalfOpenTemporalPeriod
{
}

public interface ITemporalPeriodCalculator
{
  bool Contains(IHalfOpenTemporalPeriod period, UtcInstant instant);
  bool Overlaps(IHalfOpenTemporalPeriod left, IHalfOpenTemporalPeriod right);
  IHalfOpenTemporalPeriod? GetBoundedIntersection(
    IHalfOpenTemporalPeriod left,
    IHalfOpenTemporalPeriod right);
  IHalfOpenTemporalPeriod? GetBoundedIntersection(
    IHalfOpenTemporalPeriod left,
    IHalfOpenTemporalPeriod right,
    UtcInstant openEndHorizonUtc);
  IReadOnlyList<IHalfOpenTemporalPeriod> GetInternalGaps(
    IReadOnlyList<IHalfOpenTemporalPeriod> periods);
}
```

```csharp
namespace ATAP.Utilities.DateTime.Model;

public sealed record TemporalValidityPeriod : ITemporalValidityPeriod
{
  public TemporalValidityPeriod(UtcInstant validFromUtc, UtcInstant? validToUtc);
  public UtcInstant ValidFromUtc { get; }
  public UtcInstant? ValidToUtc { get; }
  public bool IsOpenEnded { get; }
  public TemporalDuration? Duration { get; }
  public bool Contains(UtcInstant instant);
}

public sealed class TemporalValidityPeriodSet :
  IReadOnlyList<TemporalValidityPeriod>,
  IEquatable<TemporalValidityPeriodSet>
{
  public static TemporalValidityPeriodSet Empty { get; }
  public TemporalValidityPeriodSet(
    IEnumerable<TemporalValidityPeriod>? periods = null);
  public int Count { get; }
  public TemporalValidityPeriod this[int index] { get; }
  public bool IsValidAt(UtcInstant instant);
  public TemporalValidityPeriodSet Activate(UtcInstant validFromUtc);
  public TemporalValidityPeriodSet Deactivate(UtcInstant validToUtc);
  public TemporalValidityPeriodSet Replace(
    TemporalValidityPeriod current,
    TemporalValidityPeriod replacement);
  public TemporalValidityPeriodSet Split(
    TemporalValidityPeriod current,
    UtcInstant splitAtUtc);
  public TemporalValidityPeriodSet Merge(
    TemporalValidityPeriod earlier,
    TemporalValidityPeriod later);
  public bool Equals(TemporalValidityPeriodSet? other);
  public override bool Equals(object? obj);
  public override int GetHashCode();
  public static bool operator ==(
    TemporalValidityPeriodSet? left,
    TemporalValidityPeriodSet? right);
  public static bool operator !=(
    TemporalValidityPeriodSet? left,
    TemporalValidityPeriodSet? right);
  public IEnumerator<TemporalValidityPeriod> GetEnumerator();
}

public sealed class ItensoTemporalPeriodCalculator : ITemporalPeriodCalculator
{
  public ItensoTemporalPeriodCalculator();
  public bool Contains(IHalfOpenTemporalPeriod period, UtcInstant instant);
  public bool Overlaps(IHalfOpenTemporalPeriod left, IHalfOpenTemporalPeriod right);
  public IHalfOpenTemporalPeriod? GetBoundedIntersection(
    IHalfOpenTemporalPeriod left,
    IHalfOpenTemporalPeriod right);
  public IHalfOpenTemporalPeriod? GetBoundedIntersection(
    IHalfOpenTemporalPeriod left,
    IHalfOpenTemporalPeriod right,
    UtcInstant openEndHorizonUtc);
  public IReadOnlyList<IHalfOpenTemporalPeriod> GetInternalGaps(
    IReadOnlyList<IHalfOpenTemporalPeriod> periods);
}
```

The normal non-generic `IEnumerable.GetEnumerator`, record-generated equality members,
and operators generated by the compiler are part of the CLR surface but do not add
domain operations.

The package aggregation project exposes one registration method:

```csharp
namespace ATAP.Utilities.DateTime;

public static class ServiceCollectionExtensions
{
  public static IServiceCollection AddATAPUtilitiesDateTime(
    this IServiceCollection services);
}
```

It registers `ITemporalPeriodCalculator` to
`ItensoTemporalPeriodCalculator` as a singleton and returns the same non-null service
collection. No clock is registered by this method.

## Value and validation semantics

### `UtcInstant`

- `value.Offset` must equal `TimeSpan.Zero`; the constructor does not normalize a
  nonzero offset even when it denotes the same instant.
- `Value` retains the exact 100-nanosecond tick value. `DateTime` is not accepted in
  the public constructor.
- `default(UtcInstant)` is the UTC `DateTimeOffset` minimum and is valid. Ordering and
  equality use `Value`.

### `TemporalDuration`

- `timeSpan` must be non-negative. Zero is valid because elapsed time and other
  duration consumers may legitimately produce zero.
- Equality, ordering, `TimeSpan`, and `Ticks` are all based on the same tick count.
  No unit conversion, calendar duration, or floating-point constructor is exposed.

### `TemporalValidityPeriod`

- `ValidFromUtc` is included. A non-null `ValidToUtc` is excluded and must compare
  strictly greater than `ValidFromUtc`.
- `IsOpenEnded` is exactly `ValidToUtc is null`. `Duration` is null for an open-ended
  period and otherwise equals `ValidToUtc - ValidFromUtc`.
- `Contains` is `instant >= ValidFromUtc && (ValidToUtc is null || instant <
  ValidToUtc)`. Exact start succeeds; exact end fails.
- Equality and hash code are structural over the two boundaries. Derived properties
  do not add equality state.

### `TemporalValidityPeriodSet`

- The constructor materializes the input once, treats a null enumerable as empty,
  rejects a null element, sorts by `ValidFromUtc`, and validates the complete snapshot
  before publishing it.
- Duplicate periods, duplicate starts, overlaps, more than one open end, and a period
  after an open end are rejected. Exact abutment and gaps are valid.
- The object never retains the caller's collection. `Empty` is a reusable valid empty
  instance. Indexing and enumeration expose the canonical sorted order.
- Equality and hash code are structural over that canonical sequence, so differently
  ordered inputs that describe the same valid periods are equal.
- `IsValidAt` returns true when exactly one contained period contains the instant.
- Every transition returns a new validated set. `Activate` appends one open period;
  `Deactivate` closes the current open period; `Replace` substitutes exactly one
  structurally equal member; `Split` replaces one period with two exactly abutting
  periods; and `Merge` combines two consecutive, exactly abutting periods. Merge never
  fills a gap. The receiver is unchanged on success or failure.

## Calculator and adapter semantics

- Null period or collection arguments are rejected before vendor mapping.
- `Contains` and `Overlaps` implement half-open behavior. Two periods that only abut
  do not overlap.
- The two-argument `GetBoundedIntersection` accepts only bounded periods. It returns
  null for no intersection and a bounded `TemporalValidityPeriod` otherwise.
- The three-argument overload substitutes `openEndHorizonUtc` only for a null end.
  The horizon must be later than the start of every open input. A bounded input keeps
  its actual end.
- `GetInternalGaps` validates that inputs are ordered and non-overlapping, then returns
  only bounded gaps between consecutive periods. It invents neither a leading nor a
  trailing observation window.
- The Itenso adapter explicitly constructs closed-start/open-end intervals. It may use
  vendor objects internally, but it must create ATAP-owned result objects and must not
  return a sentinel, vendor interface, or vendor exception.

## Null and exception contract

| Condition | Public result |
| --- | --- |
| Nonzero-offset `UtcInstant` input | `ArgumentException` naming `value` |
| Negative `TemporalDuration` | `ArgumentOutOfRangeException` naming `timeSpan` |
| Period end equal to or earlier than start | `ArgumentOutOfRangeException` naming `validToUtc` |
| Null period-set enumerable | Empty valid set |
| Null element or invalid whole set | `ArgumentException` naming `periods` |
| Null reference argument to calculator or transition | `ArgumentNullException` naming that argument |
| Transition member absent or present more than once | `ArgumentException` naming `current`, `earlier`, or `later` |
| Activate when an open period exists; deactivate without one | `InvalidOperationException` |
| Split outside the strict interior; non-abutting merge | `ArgumentOutOfRangeException` for the instant, otherwise `ArgumentException` |
| Open calculator input without the horizon overload | `InvalidOperationException` |
| Invalid or legacy JSON | `JsonException` |
| Null `IServiceCollection` | `ArgumentNullException` naming `services` |

Implementations may preserve an inner vendor exception for diagnostics, but the public
exception type must remain one of the types above.

## Serialization contract

Canonical JSON uses lower-camel property names and UTC strings with exactly seven
fractional-second digits and a terminal `Z`.

```json
{
  "id": "01234567-abcd-9876-cdef-456789abcdef",
  "additionalIds": {},
  "validityPeriods": [
    {
      "validFromUtc": "2026-08-08T12:34:56.1234567Z",
      "validToUtc": null
    }
  ]
}
```

- `UtcInstant` serializes as the canonical UTC JSON string shown above, not as an
  object. Input with `Z` or an explicit zero offset is accepted; nonzero offsets,
  missing offsets, local `DateTime` text, and excess precision are rejected rather
  than normalized. Output always uses `Z`.
- `TemporalDuration` serializes as `{ "ticks": 0 }`; ticks are a non-negative JSON
  integer. ISO calendar-duration strings and vendor duration descriptions are not
  accepted.
- `TemporalValidityPeriod` uses only `validFromUtc` and `validToUtc`.
  `validToUtc: null` is the sole open-end representation.
- `TemporalValidityPeriodSet` serializes as an array. An omitted or null Philote
  `validityPeriods` property becomes an empty set; a null array element is rejected.
- Philote uses `id`, `additionalIds`, and `validityPeriods`. Omitted or null
  `additionalIds` becomes an empty immutable dictionary.
- A case-insensitive `timeBlocks` property or any vendor period fields at the Philote
  temporal boundary cause `JsonException`, even if `validityPeriods` is omitted.
  Unknown-field handling outside that legacy rejection remains the serializer shim's
  policy.

The StringConstants project owns these exact public constants:

```csharp
public static class TemporalJsonPropertyNames
{
  public const string Id = "id";
  public const string AdditionalIds = "additionalIds";
  public const string ValidityPeriods = "validityPeriods";
  public const string ValidFromUtc = "validFromUtc";
  public const string ValidToUtc = "validToUtc";
  public const string Ticks = "ticks";
}

public static class TemporalPersistenceNames
{
  public const string PhiloteValidityPeriod = "PhiloteValidityPeriod";
  public const string ValidFromUtc = "ValidFromUtc";
  public const string ValidToUtc = "ValidToUtc";
  public const string PreviousValidToUtc = "PreviousValidToUtc";
}
```

These constants contain names only. They contain no SQL, validation rules, format
strings, or serializer behavior.

## Philote contract

The breaking interface replacement is:

```csharp
public interface IAbstractPhilote<TId, TValue>
  where TId : IAbstractStronglyTypedId<TValue>, new()
  where TValue : notnull
{
  TId Id { get; }
  IReadOnlyDictionary<string, IAbstractStronglyTypedId<TValue>> AdditionalIds { get; }
  IReadOnlyList<ITemporalValidityPeriod> ValidityPeriods { get; }
  bool IsValidAt(UtcInstant instant);
}
```

Concrete models copy both collections and store a `TemporalValidityPeriodSet` as the
validity authority. They return new concrete Philote instances after a set transition;
they never mutate an existing Philote or expose a mutable dictionary. Two concrete
Philotes of the same runtime type are equal exactly when their `Id` values are equal;
additional IDs and validity periods are state associated with that durable identity,
not additional identity components. Record-generated memberwise equality must be
overridden or records must be replaced to satisfy this rule.

## Public API traceability

| Public API group | Verified consumer or adopted invariant |
| --- | --- |
| `UtcInstant` constructor, value, comparison | ComputerInventory/CryptoMiner `Moment`; UTC and ordered-period invariants |
| `TemporalDuration` constructor, `TimeSpan`, `Ticks`, comparison | CryptoCoin `Duration.Ticks`; CryptoMiner elapsed running time; non-negative-duration invariant |
| `IHalfOpenTemporalPeriod` and `TemporalValidityPeriod` members | Philote validity; `[start,end)`, nullable end, and derived-duration invariants |
| `TemporalValidityPeriodSet` list surface and equality | Non-null, immutable, sorted, atomic-validation, and deterministic-equality invariants |
| `IsValidAt` and `Contains` | Philote as-of validity lookup and exact-boundary tests |
| Set transition methods | Adopted activation, deactivation, replacement, split, and merge operations named by PTV-150 |
| Calculator `Contains`, `Overlaps`, intersection, and gaps | Minimum adapter surface adopted by the plan and boundary-equivalence tests |
| Explicit open-end horizon overload | Plan requirement that the Itenso adapter never invent a sentinel for an open end |
| `ItensoTemporalPeriodCalculator` | Private-vendor adapter requirement and DI-first repository convention |
| `AddATAPUtilitiesDateTime` | PTV-160 DI registration requirement and DI-first repository convention |
| JSON property constants and persistence constants | Philote serializer fixtures and the adopted C#/database naming boundary |
| Philote `Id`, `AdditionalIds`, `ValidityPeriods`, and `IsValidAt` | Existing Philote surface plus immutable/non-null adoption decisions |

No public signature above contains `Itenso.TimePeriod`. No public holiday, calendar,
scheduling, vendor collection, vendor relation, mutable period, or compatibility API is
approved.

## Adversarial controls

Implementation and review must defeat these close variants:

1. A `record struct TemporalValidityPeriod` whose default value bypasses validation.
2. A nonzero-offset input silently normalized to UTC.
3. Exact abutment reported as overlap because the vendor end edge remained closed.
4. `validToUtc: null` converted to a maximum-date sentinel.
5. `timeBlocks`, `TimeBlocks`, or vendor fields ignored so a legacy payload becomes an
   empty valid set.
6. A collection validated lazily after the caller mutates its source enumerable.
7. Record-generated Philote equality that compares dictionary or list references.
8. Merge across a legal gap, thereby inventing validity.
9. Gap discovery that invents an unstated leading or trailing observation window.
10. An adapter method, exception, generic constraint, or XML-doc signature leaking an
    Itenso type.

## Consequences

PTV-100 through PTV-180 can implement the DateTime family without reopening names,
null semantics, equality, serialization, or adapter operations. PTV-200 through PTV-240
can make the Philote break explicitly. PTV-300 through PTV-330 can replace the current
three semantic misuses with `UtcInstant` or `TemporalDuration` rather than a generic
period facade.

Gate PTV-G0 must review this ADR together with the database and deterministic-seed
contracts. Until that joint approval, this document is a proposed contract and no
implementation is authorized.

## Related evidence and authority

- `_Planning/InformationForTheFuture/Plan_PhiloteTemporalValidity_Adoption.md`
- `_generated/PhiloteTemporalValidity/PTV-000/ItensoConsumerInventory.md`
- `src/ATAP.Utilities.Philote/Interfaces/IPhilote.cs`
- `src/ATAP.Utilities.Philote/Models/Philote.cs`
- `src/ATAP.Utilities.DateTime/ATAP.Utilities.DateTime.cs`
- `src/ATAP.Utilities.ComputerInventory/Hardware/Interfaces/Interfaces.Hardware.ComputerHardware.cs`
- `src/ATAP.Utilities.CryptoCoin/Models/CryptoCoinNetworkInfo.cs`
- `src/ATAP.Utilities.CryptoMiner/Models/Models.MinerSW.Claymore.cs`
