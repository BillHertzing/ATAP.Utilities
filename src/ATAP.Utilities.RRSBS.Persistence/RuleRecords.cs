namespace ATAP.Utilities.RRSBS.Persistence;

public sealed class RuleRecord
{
    public Guid PhiloteId { get; set; }
    public byte PrimitiveLanguageKindId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Purpose { get; set; }
    public ICollection<RuleStepRecord> Steps { get; set; } = new List<RuleStepRecord>();
}

public sealed class RuleStepRecord
{
    public int RuleStepId { get; set; }
    public Guid RulePhiloteId { get; set; }
    public int Sequence { get; set; }
    public string PrimitiveName { get; set; } = string.Empty;
    public string? BoundInputsJson { get; set; }
    public RuleRecord? Rule { get; set; }
}
