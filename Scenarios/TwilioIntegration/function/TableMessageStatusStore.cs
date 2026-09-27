using Azure;
using Azure.Data.Tables;
using Azure.Identity;
using Microsoft.Extensions.Logging;

namespace TwilioEmail;

internal sealed class TableMessageStatusStore : IMessageStatusStore
{
    private readonly TableClient _table;
    private readonly ILogger<TableMessageStatusStore> _logger;

    public TableMessageStatusStore(MessageTableSettings settings, ILogger<TableMessageStatusStore> logger)
    {
        _table = new TableClient(new Uri(settings.TableServiceUri), settings.TableName, new DefaultAzureCredential());
        _logger = logger;
    }

    public async Task SetStatusAsync(
        string partitionKey,
        string? id,
        string status,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return;
        }

        var entity = new TableEntity(partitionKey, id.Trim())
        {
            ["Status"] = status
        };

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
}
