const { app } = require('@azure/functions');

function readPayload(message) {
  if (message == null) {
    return {};
  }
  if (typeof message === 'string') {
    const text = message.trim();
    if (!text) {
      return {};
    }
    try {
      return JSON.parse(text);
    } catch {
      return {};
    }
  }
  if (Buffer.isBuffer(message) || message instanceof Uint8Array) {
    return readPayload(Buffer.from(message).toString('utf8'));
  }
  if (typeof message.body === 'string' && message.to == null) {
    return readPayload(message.body);
  }
  if ((Buffer.isBuffer(message.body) || message.body instanceof Uint8Array) && message.to == null) {
    return readPayload(message.body);
  }
  return message;
}

app.serviceBusQueue('sendSms', {
  connection: 'ServiceBusConnection',
  queueName: 'twilio-sms',
  handler: async (message, context) => {
    const payload = readPayload(message);
    const to = payload.to;
    const body = payload.body;

    context.log('sendSms received', {
      messageType: message === null ? 'null' : typeof message,
      hasTo: Boolean(to),
      hasBody: Boolean(body),
      hasAccountSid: Boolean(process.env.TWILIO_ACCOUNT_SID),
      hasApiKey: Boolean(process.env.TWILIO_API_KEY),
      hasApiSecret: Boolean(process.env.TWILIO_API_SECRET),
      hasFrom: Boolean(process.env.TWILIO_FROM_NUMBER),
    });

    if (!to || !body) {
      throw new Error('Queue message must include to and body');
    }

    const accountSid = process.env.TWILIO_ACCOUNT_SID;
    const apiKey = process.env.TWILIO_API_KEY;
    const apiSecret = process.env.TWILIO_API_SECRET;
    const from = process.env.TWILIO_FROM_NUMBER;

    if (!accountSid || !apiKey || !apiSecret || !from) {
      throw new Error('Twilio Key Vault secrets are missing (Twilio-AccountSid, Twilio-ApiKey, Twilio-ApiSecret, Twilio-FromNumber)');
    }

    const url = `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(accountSid)}/Messages.json`;
    const form = new URLSearchParams({ To: to, From: from, Body: body });
    const auth = Buffer.from(`${apiKey}:${apiSecret}`, 'utf8').toString('base64');

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: form.toString(),
    });

    if (!response.ok) {
      const text = await response.text();
      context.error(`Twilio rejected the SMS: ${response.status} ${text}`);
      throw new Error(`Twilio ${response.status}`);
    }

    context.log(`SMS accepted by Twilio for ${to}`);
  },
});
