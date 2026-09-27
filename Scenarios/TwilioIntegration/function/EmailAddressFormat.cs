namespace TwilioEmail;

// Same pattern as library/policies/twilio-email-api.xml. Shape only (local@domain.tld),
// not mailbox existence or MX. APIM rejects the same form before the queue.
internal static class EmailAddressFormat
{
    public const string Pattern = @"^[^@\s]+@[^@\s]+\.[^@\s]+$";

    public static bool IsWellFormed(string? value) =>
        !string.IsNullOrWhiteSpace(value)
        && System.Text.RegularExpressions.Regex.IsMatch(value.Trim(), Pattern);
}
