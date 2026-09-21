const api = require('@actual-app/api');
const fs = require('fs');
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
  await api.sync();
  await api.shutdown();
})().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
