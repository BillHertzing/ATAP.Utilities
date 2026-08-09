# ATAP.Utilities.Philote Interfaces

This folder contains interface contracts for the `ATAP.Utilities.Philote` component.

## Contents

- `IPhilote.cs`: core public identity and temporal-validity interface definition
- `ATAP.Utilities.Philote.Interfaces.csproj`: project definition

## Notes

- Keep interfaces stable and versioned carefully.
- Implementations should reside in separate projects.
- `ValidityPeriods` is an ordered `IReadOnlyList<TemporalValidityPeriod>` and
  `IsValidAt(UtcInstant)` applies half-open boundary semantics.
- Public signatures must not expose a third-party temporal type.
