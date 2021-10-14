The entire project creates a single VoiceAttack (VA) profile package, which can be installed following the VA plugin instructions.

The MSbuild actions consist of `build`, then `deploy`.

The `package` action includes the Voice Attack Profile file (ATAP Profile.vab) in addition to all files in the Sounds and `PreCompiledFunctions` directory, and packages all that, along with the main  .dll(s) into a.zip file

The `deploy` action will deploy the generated package (.zip) to the local Nuget feed.
