# ATAP.Utilities.Serializer.Shim

This folder contains serializer shim/adapter projects used to integrate specific serializer engines.

## Contents

- `ATAP.Utilities.Serializer.Shim.csproj`: shim project definition
- `Newtonsoft`: Newtonsoft.Json adapter surface
- `Plugin`: plugin-based adapter integrations
- `ServiceStack`: ServiceStack adapter surface
- `SystemTextJson`: System.Text.Json adapter surface

## Notes

- Keep serializer-engine-specific code in the corresponding subfolder.
- Keep shared serializer contracts in the `Interfaces` project.
