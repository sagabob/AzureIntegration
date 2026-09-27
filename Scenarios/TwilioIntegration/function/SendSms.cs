using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace TwilioEmail;

public sealed class SendSms
{
    private readonly ILogger<SendSms> _logger;

    public SendSms(ILogger<SendSms> logger)
    {
        _logger = logger;
    }

    [Function("sendSms")]
    public void Run(
        [ServiceBusTrigger("twilio-sms", Connection = "ServiceBusConnection")] string _)
    {
        _logger.LogInformation("sendSms received a queue message. Handler is empty; add send logic later.");
    }
}
