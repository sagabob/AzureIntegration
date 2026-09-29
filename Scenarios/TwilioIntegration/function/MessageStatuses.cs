namespace TwilioEmail;

// Keep literals in sync with sendEmail and library/policies/twilio-sms-api.xml.
internal static class MessageStatuses
{
    public const string Queued = "queued";
    public const string QueueFailed = "queueFailed";
    public const string Sent = "sent";
    public const string Failed = "failed";
    public const string EmailPartition = "email";
    public const string SmsPartition = "sms";
}
