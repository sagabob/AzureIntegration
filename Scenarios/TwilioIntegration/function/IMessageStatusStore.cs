namespace TwilioEmail;

/// <summary>Table row for one queued message (RowKey = APIM request id).</summary>
public sealed record MessageTableRow(string Status, string? ProviderMessageId, string? Payload)
{
    public bool AlreadySent =>
        string.Equals(Status, MessageStatuses.Sent, StringComparison.Ordinal)
        || !string.IsNullOrWhiteSpace(ProviderMessageId);
}

/// <summary>Inserts queued rows and merges Status / ProviderMessageId (RowKey = APIM request id).</summary>
public interface IMessageStatusStore
{
    Task<MessageTableRow?> EnsureQueuedAsync(
        string partitionKey,
        string? id,
        string payload,
        CancellationToken cancellationToken = default);

    Task SetStatusAsync(
        string partitionKey,
        string? id,
        string status,
        string? providerMessageId = null,
        CancellationToken cancellationToken = default);
}
