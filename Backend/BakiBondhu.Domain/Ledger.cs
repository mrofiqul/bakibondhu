namespace BakiBondhu.Domain;

/// <summary>Directional effect of a transaction type on the receivable balance.</summary>
public enum TxnType
{
    Credit,           // baki given (+1)
    Payment,          // money received (-1)
    AdjustmentDebit,  // correction increasing the receivable (+1)
    AdjustmentCredit, // correction/reversal decreasing the receivable (-1)
}

/// <summary>
/// Core balance rule, shared by both apps through the backend (app-spec §29 /
/// Coding Standards §2.1): balance = Σ amount × balance_sign, computed, never
/// stored. FIFO allocation and aging live here too as the backend grows.
/// </summary>
public static class Ledger
{
    public static int BalanceSign(this TxnType type) => type switch
    {
        TxnType.Credit or TxnType.AdjustmentDebit => 1,
        _ => -1,
    };

    public static Money Balance(IEnumerable<(TxnType type, Money amount)> entries)
    {
        var total = Money.Zero;
        foreach (var (type, amount) in entries)
            total = type.BalanceSign() == 1 ? total + amount : total - amount;
        return total;
    }
}
