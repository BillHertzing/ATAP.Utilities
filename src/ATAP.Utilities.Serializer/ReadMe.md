# ATAP.Utilities.Serializer

This folder contains the Serializer component and its subprojects.

## Subprojects

- `Interfaces`: contracts for serializer abstractions
- `Model`: core serializer types and options
- `StringConstants`: shared constant values
- `Shim`: adapter layers for specific serializer implementations

## Contents

- `ATAP.Utilities.Serializer.csproj`: root project definition
- `version.json`: version metadata

## Notes

- Keep interfaces, models, constants, and shims separated by responsibility.
- Prefer implementation-specific behavior in the `Shim` subprojects.
