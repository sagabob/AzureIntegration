using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace TwilioEmail;

public sealed class SendEmail
{
    private readonly ILogger<SendEmail> _logger;

    public SendEmail(ILogger<SendEmail> logger)
    {
        _logger = logger;
    }

    [Function("sendEmail")]
    public void Run(
        [ServiceBusTrigger("%TWILIO_EMAIL_QUEUE_NAME%", Connection = "ServiceBusConnection")] string _)
    {
        _logger.LogInformation("sendEmail received a queue message. Handler is empty.");
    }
}
