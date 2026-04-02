const express = require('express');
const cors = require('cors');
const Stripe = require('stripe');

const app = express();
app.use(cors());
app.use(express.json());

const stripe = Stripe(process.env.STRIPE_TEST_SECRET_KEY);

app.post('/connection_token', async (req, res) => {
  try {
    const token = await stripe.terminal.connectionTokens.create();
    res.json({ secret: token.secret });
  } catch (err) {
    console.error('Erreur connection_token:', err);
    res.status(500).json({ error: err.message });
  }
});

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
      capture_method: 'manual',
    });
    console.log(`PaymentIntent créé: ${intent.id} - ${intent.amount} ${intent.currency}`);
    res.json({ client_secret: intent.client_secret });
  } catch (err) {
    console.error('Erreur create_payment_intent:', err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/update_payment_intent_amount', async (req, res) => {
  const { payment_intent_id, new_amount } = req.body;
  console.log(`Requête reçue pour update: ${payment_intent_id} -> ${new_amount}`);
  if (!payment_intent_id || !new_amount) {
    return res.status(400).json({ error: 'Missing payment_intent_id or new_amount' });
  }
  try {
    const intent = await stripe.paymentIntents.update(payment_intent_id, {
      amount: parseInt(new_amount),
    });
    console.log(`Montant mis à jour pour ${payment_intent_id} : ${intent.amount}`);
    res.json(intent);
  } catch (err) {
    console.error('Erreur update_payment_intent_amount:', err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/capture_payment_intent', async (req, res) => {
  const { payment_intent_id } = req.body;
  if (!payment_intent_id) {
    return res.status(400).json({ error: 'Missing payment_intent_id' });
  }
  try {
    const intent = await stripe.paymentIntents.capture(payment_intent_id);
    console.log(`PaymentIntent capturé: ${intent.id} - montant final ${intent.amount}`);
    res.json(intent);
  } catch (err) {
    console.error('Erreur capture_payment_intent:', err);
    res.status(500).json({ error: err.message });
  }
});

app.get('/ping', (req, res) => {
  res.json({ status: 'ok' });
});

const port = process.env.PORT || 10000;
app.listen(port, () => console.log(`Backend running on port ${port}`));
