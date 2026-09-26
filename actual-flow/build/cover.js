const api = require('@actual-app/api');
const fs = require('fs');

// Imported notes carry the bank's boilerplate. Strip it, but never touch #tags -
// tags live in this same field and none of these patterns match a #word.
const tidyNote = s => (s || '')
  .replace(/^(Visa purchase|Contactless Payment|Direct debit|Bank credit|Payment to|Transfer from)\s+/i, '')
  .replace(/\bAPPLEPAY\b/gi, '')
  .replace(/\s+\d{4}-\d{2}-\d{2}\s*$/, '')
  .replace(/\b\d{6,}\b/g, '')
  .replace(/\s{2,}/g, ' ')
  .trim();
const m = c => `£${(c/100).toFixed(2)}`;
// Sets each category's budget equal to what it actually spent, for the months
// given. Nothing is planned - it just marks spending as covered so the budget
// screen reads settled instead of overspent.
(async () => {
  // Default to last month and this month - late-arriving transactions can
  // land in the previous month. Computed here because busybox date has no -d.
  let months = process.argv.slice(2);
  if (!months.length) {
    const now = new Date();
    const prev = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const fmt = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    months = [fmt(prev), fmt(now)];
  }
  const ab = JSON.parse(fs.readFileSync('/app/config/config.json','utf8')).actualBudget;
  await api.init({ dataDir:'/app/config/actual-data', serverURL: ab.serverUrl, password: ab.password });
  await api.downloadBudget(ab.budgetSyncId);
  for (const month of months) {
    let n = 0;
    const b = await api.getBudgetMonth(month);
    for (const g of b.categoryGroups) {
      if (g.is_income) continue;
      for (const c of (g.categories || [])) {
        const want = -c.spent;
        if (want === c.budgeted) continue;
        await api.setBudgetAmount(month, c.id, want);
        n++;
      }
    }
    const after = await api.getBudgetMonth(month);
    console.log(`${month}: covered ${n} categories | budgeted ${m(after.totalBudgeted)} spent ${m(after.totalSpent)} toBudget ${m(after.toBudget)}`);
  }
  // tidy any notes that still carry bank boilerplate
  let tidied = 0;
  for (const a of await api.getAccounts()) {
    for (const t of await api.getTransactions(a.id, months[0] + '-01', months[months.length - 1] + '-31')) {
      const clean = tidyNote(t.notes);
      if (clean && clean !== t.notes) { await api.updateTransaction(t.id, { notes: clean }); tidied++; }
    }
  }
  if (tidied) console.log(`tidied ${tidied} notes`);
  await api.sync();
  await api.shutdown();
})().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
