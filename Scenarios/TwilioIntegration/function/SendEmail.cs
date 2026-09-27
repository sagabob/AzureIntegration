using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace TwilioEmail;

// Queue trigger only. Resend HTTP lives in IResendEmailSender so this class
// is not an AddHttpClient<T> typed client.
public sealed class SendEmail
{
    private readonly IResendEmailSender _resend;
    private readonly ILogger<SendEmail> _logger;

    public SendEmail(IResendEmailSender resend, ILogger<SendEmail> logger)
    {
        _resend = resend;
        _logger = logger;
    }

    [Function("sendEmail")]
    public async Task Run(
        [ServiceBusTrigger(EmailQueues.Email, Connection = EmailQueues.ServiceBusConnection)]
        string message)
    {
        var melbourne = MelbourneTime.Now();
        _logger.LogInformation(
            "sendEmail queue payload at {MelbourneTime}. raw={RawMessage}",
            melbourne,
            message);

        var queued = EmailQueueParser.Parse(message);
        _logger.LogInformation(
            "sendEmail received at {MelbourneTime}. to={To} subject={Subject} body={Body}",
            melbourne,
            queued.To,
            queued.Subject,
            queued.Body);

        var result = await _resend.SendAsync(queued, ResendSettings.FromEnvironment());
        // Throw so Service Bus retries and can dead-letter after max delivery.
        if (!result.Succeeded)
        {
            _logger.LogError(
                "Resend rejected email at {MelbourneTime} to {To} with {Status}. request={ResendRequest} response={ResendResponse}",
                melbourne,
                queued.To,
                result.StatusCode,
                result.RequestJson,
                result.ResponseBody);
            throw new InvalidOperationException($"Resend returned {result.StatusCode}: {result.ResponseBody}");
        }

        _logger.LogInformation(
            "Resend accepted email at {MelbourneTime} to {To}. request={ResendRequest} response={ResendResponse}",
            melbourne,
            queued.To,
            result.RequestJson,
            result.ResponseBody);
    }
}
