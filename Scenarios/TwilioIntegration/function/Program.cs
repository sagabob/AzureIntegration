// Isolated worker host. Do not AddHttpClient<SendEmail> — the worker constructs
// the function class itself and that typed client never gets BaseAddress.
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using TwilioEmail;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices(services =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
        services.AllowApplicationInsightsInformationLogs();
        services.AddHttpClient(ResendEmailSender.HttpClientName, client =>
        {
            client.Timeout = TimeSpan.FromSeconds(30);
        });
        services.AddSingleton<IResendEmailSender, ResendEmailSender>();
    })
    .Build();

host.Run();

internal static class IsolatedWorkerLogging
{
    // Isolated worker adds a Warning+ filter for App Insights; remove it so
    // sendEmail Information lines (payload, Resend request/response) appear.
    public static void AllowApplicationInsightsInformationLogs(this IServiceCollection services)
    {
        services.Configure<LoggerFilterOptions>(options =>
        {
            var appInsightsRule = options.Rules.FirstOrDefault(rule =>
                rule.ProviderName
                == "Microsoft.Extensions.Logging.ApplicationInsights.ApplicationInsightsLoggerProvider");
            if (appInsightsRule is not null)
            {
                options.Rules.Remove(appInsightsRule);
            }
        });
    }
}
