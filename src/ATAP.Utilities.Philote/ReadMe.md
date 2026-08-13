# ATAP.Utilities.Philote

**Facade project**

## Purpose

Provide stable strongly typed identity plus immutable business-validity periods.
`IAbstractPhilote<TId,TValue>` exposes `Id`, immutable `AdditionalIds`, ordered
`ValidityPeriods`, and `IsValidAt(UtcInstant)`. The public contract contains no
third-party temporal type.

## Architecture

The Interfaces project owns the public contract. Models implements identity-only,
same-runtime-type equality and immutable validity transitions. The
System.Text.Json shim owns the Philote converter factory. DateTime Interfaces and
Model own the temporal value types and calculations.

## Child Packages

- ATAP.Utilities.Philote.DefaultConfiguration
- ATAP.Utilities.Philote.Interfaces
- ATAP.Utilities.Philote.Models
- ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson
- ATAP.Utilities.Philote.Converters.Interfaces

## JSON contract

The canonical Philote shape is:

```json
{
  "id": "01234567-abcd-9876-cdef-456789abcdef",
  "additionalIds": {},
  "validityPeriods": [
    {
      "validFromUtc": "2026-08-08T00:00:00.0000000Z",
      "validToUtc": null
    }
  ]
}
```

The property names are case-sensitive. A null `validityPeriods` value reads as an
empty set, but the writer emits an array. Retired vendor-shaped temporal fields
are rejected rather than ignored or reinterpreted.

## Contract references

- [C# temporal-validity ADR](../../SolutionDocumentation/ADR-Philote-Temporal-Validity-CSharp-Contract.md)
- [DateTime facade](../ATAP.Utilities.DateTime/INDEX.md)
- [Relational contract](../../Database/Documentation/ADR-Philote-Temporal-Validity-Relational-Contract.md)
