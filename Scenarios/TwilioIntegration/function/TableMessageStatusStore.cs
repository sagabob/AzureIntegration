using Azure;
using Azure.Data.Tables;
using Azure.Identity;
using Microsoft.Extensions.Logging;

namespace TwilioEmail;

internal sealed class TableMessageStatusStore : IMessageStatusStore
{
    private const string StatusProperty = "Status";
    private const string PayloadProperty = "Payload";
    private const string ProviderMessageIdProperty = "ProviderMessageId";

    private readonly TableClient _table;
    private readonly ILogger<TableMessageStatusStore> _logger;

    public TableMessageStatusStore(MessageTableSettings settings, ILogger<TableMessageStatusStore> logger)
    {
        _table = new TableClient(new Uri(settings.TableServiceUri), settings.TableName, new DefaultAzureCredential());
        _logger = logger;
    }

    public async Task<MessageTableRow?> EnsureQueuedAsync(
        string partitionKey,
        string? id,
        string payload,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return null;
        }

        var rowKey = id.Trim();
        var existing = await TryGetAsync(partitionKey, rowKey, cancellationToken);
        if (existing?.AlreadySent == true)
        {
            return existing;
        }

        var entity = new TableEntity(partitionKey, rowKey)
        {
            [StatusProperty] = MessageStatuses.Queued,
            [PayloadProperty] = payload
        };

        await _table.UpsertEntityAsync(entity, TableUpdateMode.Merge, cancellationToken);
        return new MessageTableRow(MessageStatuses.Queued, existing?.ProviderMessageId, payload);
    }

    public async Task SetStatusAsync(
        string partitionKey,
        string? id,
        string status,
        string? providerMessageId = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return;
        }

        var entity = new TableEntity(partitionKey, id.Trim())
        {
            [StatusProperty] = status
        };
        if (!string.IsNullOrWhiteSpace(providerMessageId))
        {
            entity[ProviderMessageIdProperty] = providerMessageId.Trim();
        }

        try
        {
            await _table.UpdateEntityAsync(entity, ETag.All, TableUpdateMode.Merge, cancellationToken);
        }
        catch (RequestFailedException ex) when (ex.Status == 404)
        {
            _logger.LogWarning(
                "Message table row {PartitionKey}/{RowKey} was not found; status {Status} not written.",
                partitionKey,
                id,
                status);
        }
    }

    private async Task<MessageTableRow?> TryGetAsync(
        string partitionKey,
        string rowKey,
        CancellationToken cancellationToken)
    {
        try
        {
            var response = await _table.GetEntityAsync<TableEntity>(partitionKey, rowKey, cancellationToken: cancellationToken);
            var entity = response.Value;
            return new MessageTableRow(
                entity.GetString(StatusProperty) ?? string.Empty,
                entity.GetString(ProviderMessageIdProperty),
                entity.GetString(PayloadProperty));
        }
        catch (RequestFailedException ex) when (ex.Status == 404)
        {
            return null;
        }
    }
}
