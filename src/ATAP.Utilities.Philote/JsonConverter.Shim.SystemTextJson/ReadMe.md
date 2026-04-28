# ATAP.Utilities.Philote JsonConverter Shim (System.Text.Json)

This folder contains `System.Text.Json` shim/adapter code for `ATAP.Utilities.Philote`.

## Contents

- `JsonConverter.Shim.SystemTextJson.cs`: converter shim implementation
- `ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson.csproj`: project definition

## Notes

- Use this project for serializer integration concerns only.
- Keep domain model behavior in the models or core projects.
