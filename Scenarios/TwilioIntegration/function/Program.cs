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
        // Isolated worker adds a filter that keeps only Warning+ in App Insights.
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
        services.AddHttpClient("resend", client =>
        {
            client.Timeout = TimeSpan.FromSeconds(30);
        });
    })
    .Build();

host.Run();
