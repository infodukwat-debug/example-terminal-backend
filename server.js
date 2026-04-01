const express = require('express');
const cors = require('cors');
const Stripe = require('stripe');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Clé Stripe (test) – doit être définie dans l'environnement Render
const stripe = Stripe(process.env.STRIPE_TEST_SECRET_KEY);

// Route pour obtenir un token de connexion
app.post('/connection_token', async (req, res) => {
  try {
    const token = await stripe.terminal.connectionTokens.create();
    res.json({ secret: token.secret });
  } catch (error) {
    console.error('Erreur connection_token:', error);
    res.status(500).json({ error: error.message });
  }
});

// Route pour créer un PaymentIntent (préautorisation)
app.post('/create_payment_intent', async (req, res) => {
  const { amount, currency } = req.body;
  if (!amount || !currency) {
    return res.status(400).json({ error: 'Missing amount or currency' });
  }
  try {
    const intent = await stripe.paymentIntents.create({
      amount: parseInt(amount),
      currency: currency,
      payment_method_types: ['card_present'],
      capture_method: 'manual', // Préautorisation
    });
    res.json({ client_secret: intent.client_secret });
  } catch (error) {
    console.error('Erreur create_payment_intent:', error);
    res.status(500).json({ error: error.message });
  }
});

// Route pour capturer un PaymentIntent
app.post('/capture_payment_intent', async (req, res) => {
  const { payment_intent_id } = req.body;
  if (!payment_intent_id) {
    return res.status(400).json({ error: 'Missing payment_intent_id' });
  }
  try {
    const intent = await stripe.paymentIntents.capture(payment_intent_id);
    res.json(intent);
  } catch (error) {
    console.error('Erreur capture_payment_intent:', error);
    res.status(500).json({ error: error.message });
  }
});

// Route ping pour tester
app.get('/ping', (req, res) => {
  res.json({ status: 'ok', timestamp: Date.now() });
});

const port = process.env.PORT || 10000;
app.listen(port, () => {
  console.log(`Backend démarré sur le port ${port}`);
});
