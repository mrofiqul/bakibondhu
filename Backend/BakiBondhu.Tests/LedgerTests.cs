using BakiBondhu.Domain;
using Xunit;

namespace BakiBondhu.Tests;

public class LedgerTests
{
    [Fact]
    public void Balance_sums_by_sign()
    {
        var balance = Ledger.Balance(new[]
        {
            (TxnType.Credit, Money.Taka(20000)),
            (TxnType.Credit, Money.Taka(18000)),
            (TxnType.Payment, Money.Taka(5000)),
        });
        Assert.Equal(Money.Taka(33000), balance);
    }

    [Fact]
    public void Overpayment_yields_negative_balance()
    {
        var balance = Ledger.Balance(new[]
        {
            (TxnType.Credit, Money.Taka(10000)),
            (TxnType.Payment, Money.Taka(15000)),
        });
        Assert.True(balance.IsNegative);
    }

    [Fact]
    public void Money_is_exact_no_float_error()
    {
        Assert.Equal(Money.Taka(0.30m), Money.Taka(0.10m) + Money.Taka(0.20m));
    }
}
