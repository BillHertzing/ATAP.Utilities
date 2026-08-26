# Task 15.182.F04 BuildMaster/ProGet worker protocol

This protocol is required for any worker or coordinator operating the C# package
release path. It is derived from the Task 15.182.F03 release incident record.

## Separate gates

Never infer one gate from another. A green BuildMaster deployment proves only that
BuildMaster recorded success. The release record must separately prove that an
intended target ran, a runner completion marker was written for the exact package
and tier, the live plan/raft matches the committed plan, and the original prepared
build/artifacts context was used. Only after those checks may the worker inspect
ProGet.

For ProGet, distinguish exact package availability, direct restore, transitive
range eligibility, and downloaded-byte identity. A successful package-status or
relist response is not evidence that V3 registration changed.

## Worker interaction contract

- Preparation and approval are feed-free. A worker must never request or carry a
  resolved secret, API key, BWS token, or private key in a prompt, variable, command
  line, log, or handoff.
- Authenticated publication and promotion run only under the BuildMaster service
  identity. If `bws` is absent, pass only an approved absolute `bws.exe` path; add
  its parent to process-local `PATH`, verify command resolution to the exact file,
  and restore the original process `PATH`.
- Every retry revalidates the immutable prepared and approved manifests. If the
  exact package/tier completion marker exists, skip the mutation and resume at the
  next tier. Never rebuild, repack, resign, replace the BuildMaster build, or copy
  prepared state.
- Keep the requested lifecycle feed first. Add `nuget-stable` only as a dependency
  fallback when the requested tier is not Stable; retain configured public sources,
  and exclude unrelated lifecycle feeds.
- If Development restore fails with `NU1102`, recover only when the package is an
  `ATAP.*` dependency and NuGet's machine-readable cache identifies one exact
  nearest version. Add that exact direct reference with a bounded maximum of 16
  additions, persist the deterministic consumer and lock file, and use locked
  restore unchanged at later tiers. Fail closed for every other ambiguity.
- Select `net8.0-windows7.0` only for package IDs ending in `.Windows`; use
  `net8.0` otherwise. Verify the primary package's `.nupkg.metadata.source`
  identifies the requested tier before compiling.

## Required handoff evidence

The handoff separates verified facts from assertions and includes the exact
commands, package/version identity, requested feed, target-execution evidence,
completion-marker path, source-provenance result, lock-file path, and downloaded
SHA-256. It records `listed=null` or relist behavior as an observed fact without
claiming a server-side fix. It also records any blocked deploy-state gate rather
than converting it into a successful build claim.

This protocol is guidance only: it authorizes no live feed mutation, secret access,
private-key use, service installation, or deployment. Those actions remain named
HITL gates in the task board.
