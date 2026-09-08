namespace BakiBondhu.Domain;

/// <summary>
/// Money as an integer number of paisa (1 taka = 100 paisa) — never floating
/// point, matching the DB's NUMERIC(14,2) and the Android app's Money type.
/// </summary>
public readonly record struct Money(long Paisa) : IComparable<Money>
{
    public static readonly Money Zero = new(0);

    public static Money Taka(decimal taka) => new((long)Math.Round(taka * 100m));

    public static Money operator +(Money a, Money b) => new(a.Paisa + b.Paisa);
    public static Money operator -(Money a, Money b) => new(a.Paisa - b.Paisa);

    public bool IsPositive => Paisa > 0;
    public bool IsNegative => Paisa < 0;

    public int CompareTo(Money other) => Paisa.CompareTo(other.Paisa);

    public override string ToString() => $"৳{Paisa / 100m:0.##}";
}
