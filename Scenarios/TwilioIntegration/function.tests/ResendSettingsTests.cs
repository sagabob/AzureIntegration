namespace TwilioEmail.Tests;

[Collection(EnvironmentCollection.Name)]
public class ResendSettingsTests
{
    [Fact]
    public void FromEnvironment_reads_resolved_values()
    {
        using var _ = EnvScope.Set("EMAIL_SERVICE_API_KEY", "re_test");
        using var __ = EnvScope.Set("EMAIL_FROM_ADDRESS", " from@demo.com ");

        var settings = ResendSettings.FromEnvironment();

        Assert.Equal("re_test", settings.ApiKey);
        Assert.Equal("from@demo.com", settings.FromAddress);
    }

    [Theory]
    [InlineData(null, "from@demo.com")]
    [InlineData("", "from@demo.com")]
    [InlineData("re_test", null)]
    [InlineData("re_test", "")]
    [InlineData("@Microsoft.KeyVault(SecretUri=https://vault.example/secrets/key)", "from@demo.com")]
    [InlineData("re_test", "@Microsoft.KeyVault(SecretUri=https://vault.example/secrets/from)")]
    public void FromEnvironment_rejects_missing_or_unresolved_refs(string? apiKey, string? from)
    {
        using var _ = EnvScope.Set("EMAIL_SERVICE_API_KEY", apiKey);
        using var __ = EnvScope.Set("EMAIL_FROM_ADDRESS", from);

        Assert.Throws<InvalidOperationException>(ResendSettings.FromEnvironment);
    }
}
