namespace TwilioEmail;

/// <summary>Sends one email through Resend. Implemented by ResendEmailSender, not the function class.</summary>
public interface IResendEmailSender
{
    Task<ResendSendResult> SendAsync(
        ValidatedEmailMessage email,
        ResendSettings settings,
        CancellationToken cancellationToken = default);
}

public sealed record ResendSendResult(int StatusCode, string RequestJson, string ResponseBody)
{
    public bool Succeeded => StatusCode is >= 200 and < 300;
}
