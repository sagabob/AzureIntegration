namespace TwilioEmail;

/// <summary>Merges Status on the message table row (RowKey = APIM request id).</summary>
public interface IMessageStatusStore
{
    Task SetStatusAsync(string partitionKey, string? id, string status, CancellationToken cancellationToken = default);
}
