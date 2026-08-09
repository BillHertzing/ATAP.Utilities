# ATAP.Utilities.DateTime

## Overview

This facade exposes the ATAP temporal-validity contract without exposing a vendor
period type. Its child projects provide:

- `UtcInstant`, a UTC-only instant value;
- `TemporalDuration`, a tick-based duration value;
- `TemporalValidityPeriod`, an immutable half-open interval;
- `TemporalValidityPeriodSet`, an immutable ordered, non-overlapping set;
- `IHalfOpenTemporalPeriod` and `ITemporalPeriodCalculator`; and
- the private `ItensoTemporalPeriodCalculator` implementation registered by
  `AddATAPUtilitiesDateTime`.

A period contains its start and excludes its finite end. A null end means
open-ended. Gaps are valid; overlaps and multiple open ends are rejected. The
vendor library is confined to the Model implementation and does not appear in a
public signature.

## JSON

The canonical property names are `validFromUtc`, `validToUtc`, and `ticks`.
Instants must carry a UTC `Z` designator. The converters are internal and are
activated on the public value types with `JsonConverterAttribute`.

## Navigation

- [INDEX.md](INDEX.md)
- [Documentation](Documentation/)
- [C# contract ADR](../../SolutionDocumentation/ADR-Philote-Temporal-Validity-CSharp-Contract.md)
