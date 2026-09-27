namespace TwilioEmail;

// Literal queue names so the Consumption scale controller does not have to
// expand %TWILIO_EMAIL_QUEUE_NAME%. Connection prefix matches Function app settings
// ServiceBusConnection__fullyQualifiedNamespace + __credential=managedidentity.
internal static class EmailQueues
{
    public const string Email = "twilio-email";
    public const string Sms = "twilio-sms";
    public const string ServiceBusConnection = "ServiceBusConnection";
}
