// Reads the Trading 212 account total and reconciles Actual's off-budget
// account to it by posting the difference as a single dated transaction.
// Contributions arrive separately as transfers from the bank sync, so the
// adjustments this posts represent market movement.
const api = require('@actual-app/api');
const https = require('https');
const fs = require('fs');

const need = n => {
  const v = process.env[n];
  if (!v) throw new Error(`missing env ${n}`);
  return v;
};

function t212(path) {
  const auth = 'Basic ' + Buffer.from(
    `${need('TRADING212_API_KEY')}:${need('TRADING212_API_SECRET')}`).toString('base64');
  return new Promise((resolve, reject) => {
    https.get({ host: 'live.trading212.com', path: '/api/v0' + path,
                headers: { Authorization: auth, Accept: 'application/json' } }, res => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => res.statusCode === 200
        ? resolve(JSON.parse(body))
        : reject(new Error(`trading212 ${path} -> HTTP ${res.statusCode} ${body.slice(0, 120)}`)));
    }).on('error', reject);
  });
}

const money = p => (p / 100).toFixed(2);

(async () => {
  const cash = await t212('/equity/account/cash');
  const total = Math.round(cash.total * 100);
  console.log(`trading 212: total £${money(total)} (invested £${cash.invested}, unrealised £${cash.ppl})`);

  const dataDir = '/app/data/actual-data';
  fs.mkdirSync(dataDir, { recursive: true });
  await api.init({ dataDir,
                   serverURL: need('ACTUAL_SERVER_URL'), password: need('ACTUAL_PASSWORD') });
  await api.downloadBudget(need('ACTUAL_SYNC_ID'));

  const name = process.env.ACTUAL_ACCOUNT_NAME || 'Trading212';
  const account = (await api.getAccounts()).find(a => a.name === name);
  if (!account) throw new Error(`no account named "${name}" in Actual`);
  if (!account.offbudget) console.warn(`warning: "${name}" is on budget; investment balances belong off budget`);

  const balance = await api.getAccountBalance(account.id);
  const delta = total - balance;
  console.log(`actual: balance £${money(balance)}  delta £${money(delta)}`);

  if (delta === 0) {
    console.log('already in sync - nothing posted');
  } else {
    await api.addTransactions(account.id, [{
      date: new Date().toISOString().slice(0, 10),
      amount: delta,
      notes: `Trading 212 balance sync (total £${money(total)})`,
      cleared: true,
    }]);
    console.log(`posted adjustment of £${money(delta)}`);
  }
  await api.shutdown();
})().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
