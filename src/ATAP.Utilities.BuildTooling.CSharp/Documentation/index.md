# ATAP.Utilities.BuildTooling.CSharp conceptual documentation

The package contract, package layout, NuGet-first bootstrap, exact immutable
selection, compatibility diagnostics, rollback, provenance/signing boundary,
Release/publication separation, import properties, and validation boundary are
documented in the project [ReadMe](../ReadMe.md).

Repository-wide consumer integration and health gates are separate concerns.
Task 15.180.d proves an offline local pack and isolated direct/transitive
consumer imports. It does not claim that either real repository has selected,
published, promoted, installed, or deployed the package.
