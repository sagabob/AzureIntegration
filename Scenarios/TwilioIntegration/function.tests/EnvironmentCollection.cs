namespace TwilioEmail.Tests;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class EnvironmentCollection
{
    public const string Name = "Environment";
}

internal sealed class EnvScope : IDisposable
{
    private readonly string _name;
    private readonly string? _previous;

    private EnvScope(string name, string? previous)
    {
        _name = name;
        _previous = previous;
    }

    public static EnvScope Set(string name, string? value)
    {
        var previous = Environment.GetEnvironmentVariable(name);
        Environment.SetEnvironmentVariable(name, value);
        return new EnvScope(name, previous);
    }

    public void Dispose() => Environment.SetEnvironmentVariable(_name, _previous);
}
