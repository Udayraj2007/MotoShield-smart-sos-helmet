/**
 * Smart SOS Helmet - Secure Emergency Voice Call Backend Service
 * 
 * Keeps Twilio Account SID & Auth Token off the mobile app.
 * Exposes a POST /api/emergency-call endpoint for the Flutter app.
 */

const express = require('express');
const twilio = require('twilio');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Load credentials safely from server environment variables
const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID || 'YOUR_TWILIO_ACCOUNT_SID';
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN || 'YOUR_TWILIO_AUTH_TOKEN';
const TWILIO_FROM_NUMBER = process.env.TWILIO_FROM_NUMBER || 'YOUR_TWILIO_PHONE_NUMBER';
const SERVER_PUBLIC_URL = process.env.SERVER_PUBLIC_URL || 'https://your-domain.com';

const client = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);

const EMERGENCY_VOICE_TEXT = 
  "Hello, this is Smart SOS Helmet. An accident has been detected. The emergency location has been shared. Please provide immediate assistance.";

/**
 * TwiML Webhook - Twilio requests this URL when the call is answered by the recipient.
 */
app.all('/api/twiml-voice', (req, res) => {
  const VoiceResponse = twilio.twiml.VoiceResponse;
  const twiml = new VoiceResponse();

  // Spoken voice synthesis with Polly.Aditi Indian English voice (fallback to Polly.Joanna / Alice)
  twiml.say({
    language: 'en-IN',
    voice: 'Polly.Aditi'
  }, EMERGENCY_VOICE_TEXT);

  // Short pause before ending call
  twiml.pause({ length: 2 });

  res.type('text/xml');
  res.send(twiml.toString());
});

/**
 * Outbound Call Dispatch API - Called by Smart SOS Helmet Flutter App
 */
app.post('/api/emergency-call', async (req, res) => {
  try {
    const { to, contactName, mapsUrl } = req.body;

    if (!to) {
      return res.status(400).json({ error: 'Recipient phone number (to) is required.' });
    }

    console.log(`[EMERGENCY CALL] Dispatching automated cloud voice alert to ${contactName} (${to})...`);

    const call = await client.calls.create({
      to: to,
      from: TWILIO_FROM_NUMBER,
      url: `${SERVER_PUBLIC_URL}/api/twiml-voice`,
      statusCallback: `${SERVER_PUBLIC_URL}/api/call-events`,
      statusCallbackEvent: ['initiated', 'ringing', 'answered', 'completed'],
    });

    console.log(`[EMERGENCY CALL] Call dispatched successfully! Call SID: ${call.sid}`);

    return res.status(200).json({
      success: true,
      callSid: call.sid,
      status: call.status,
      message: 'Emergency voice call dispatched successfully.'
    });
  } catch (error) {
    console.error('[EMERGENCY CALL ERROR]', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to dispatch cloud voice call.'
    });
  }
});

/**
 * Status Callback Webhook
 */
app.post('/api/call-events', (req, res) => {
  const { CallSid, CallStatus } = req.body;
  console.log(`[TWILIO STATUS EVENT] Call: ${CallSid} -> Status: ${CallStatus}`);
  res.sendStatus(200);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Smart SOS Helmet Voice Backend running on port ${PORT}`);
});
