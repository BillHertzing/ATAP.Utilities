using ATAP.Utilities.ETW;

const string TypeName = "U00.SyntheticRunner";

ATAPUtilitiesETWProvider.Log.MethodBoundryFromAspect($"<{TypeName}.Success");
ATAPUtilitiesETWProvider.Log.MethodBoundryFromAspect($">{TypeName}.Success");
ATAPUtilitiesETWProvider.Log.MethodBoundryFromAspect($"<{TypeName}.Fault");
ATAPUtilitiesETWProvider.Log.Information($"OnException: {typeof(InvalidOperationException).FullName}");
ATAPUtilitiesETWProvider.Log.MethodBoundryFromAspect($"<{TypeName}.Cancelled");
ATAPUtilitiesETWProvider.Log.Information($"OnException: {typeof(OperationCanceledException).FullName}");
