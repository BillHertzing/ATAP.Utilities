# ATAP.Utilities.Serializer Interfaces

This folder contains interface contracts for the serializer subsystem.

## Contents

- ISerializer.cs: primary serializer abstraction.
- ISerializerOptions.cs: options contract used by serializer implementations.
- ATAP.Utilities.Serializer.Interfaces.csproj: project definition.

## Notes

- Keep these interfaces implementation-agnostic.
- Add new contracts here before adding concrete behavior in Model or Shim projects.
