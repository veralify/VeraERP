const express = require("express");
const path = require("path");
const Database = require("better-sqlite3");

const app = express();
const PORT = process.env.PORT || 3000;
const db = new Database(process.env.DB_PATH || path.join(__dirname, "money-manager.db"));
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

db.exec(`
CREATE TABLE IF NOT EXISTS income (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount >= 0),
  type TEXT NOT NULL DEFAULT 'fixed',
  payday INTEGER,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount >= 0),
  category TEXT NOT NULL DEFAULT 'Fixed',
  due_day INTEGER,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS debts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  balance REAL NOT NULL CHECK(balance >= 0),
  apr REAL NOT NULL DEFAULT 0 CHECK(apr >= 0),
  minimum_payment REAL NOT NULL DEFAULT 0 CHECK(minimum_payment >= 0),
  due_day INTEGER,
  priority INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS savings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  amount REAL NOT NULL DEFAULT 0 CHECK(amount >= 0),
  target_amount REAL NOT NULL DEFAULT 0 CHECK(target_amount >= 0),
  monthly_contribution REAL NOT NULL DEFAULT 0 CHECK(monthly_contribution >= 0),
  category TEXT NOT NULL DEFAULT 'General',
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
`);

function seed() {
  const count = db.prepare("SELECT COUNT(*) c FROM income").get().c;
  if (count) return;
  const addIncome = db.prepare("INSERT INTO income(name,amount,type,payday) VALUES (?,?,?,?)");
  addIncome.run("Salary", 1600, "fixed", 28);
  const addExpense = db.prepare("INSERT INTO expenses(name,amount,category,due_day) VALUES (?,?,?,?)");
  addExpense.run("Intesa San Paolo", 178, "Debt / installment", 1);
  addExpense.run("UniCredit", 316, "Debt / installment", 1);
  addExpense.run("Maria", 500, "Family", 5);
  addExpense.run("Family", 200, "Living", 15);
  const addDebt = db.prepare("INSERT INTO debts(name,balance,apr,minimum_payment,due_day,priority) VALUES (?,?,?,?,?,?)");
  addDebt.run("Court", 3000, 0, 500, 1, 1);
  addDebt.run("Intesa", 6491.72, 11.49, 177.98, 1, 2);
  addDebt.run("UniCredit", 5851.53, 0, 315.75, 1, 3);
  db.prepare("INSERT OR IGNORE INTO settings(key,value) VALUES ('targetMonths','16')").run();
  db.prepare("INSERT OR IGNORE INTO settings(key,value) VALUES ('startDate','2026-09-01')").run();
}
seed();

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

const all = table => db.prepare(`SELECT * FROM ${table} ORDER BY id DESC`).all();
const get = (table, id) => db.prepare(`SELECT * FROM ${table} WHERE id=?`).get(id);

app.get("/api/income", (_,res)=>res.json(all("income")));
app.post("/api/income", (req,res)=>{
  const {name,amount,type="fixed",payday=null,active=1}=req.body;
  if(!name || Number(amount)<0) return res.status(400).json({error:"Invalid income"});
  const r=db.prepare("INSERT INTO income(name,amount,type,payday,active) VALUES (?,?,?,?,?)").run(name,Number(amount),type,payday?Number(payday):null,active?1:0);
  res.json(get("income",r.lastInsertRowid));
});
app.put("/api/income/:id",(req,res)=>{
  const {name,amount,type,payday,active}=req.body;
  db.prepare("UPDATE income SET name=?,amount=?,type=?,payday=?,active=? WHERE id=?").run(name,Number(amount),type,payday?Number(payday):null,active?1:0,req.params.id);
  res.json(get("income",req.params.id));
});
app.delete("/api/income/:id",(req,res)=>{db.prepare("DELETE FROM income WHERE id=?").run(req.params.id);res.json({ok:true});});

app.get("/api/expenses", (_,res)=>res.json(all("expenses")));
app.post("/api/expenses", (req,res)=>{
  const {name,amount,category="Fixed",due_day=null,active=1}=req.body;
  if(!name || Number(amount)<0) return res.status(400).json({error:"Invalid expense"});
  const r=db.prepare("INSERT INTO expenses(name,amount,category,due_day,active) VALUES (?,?,?,?,?)").run(name,Number(amount),category,due_day?Number(due_day):null,active?1:0);
  res.json(get("expenses",r.lastInsertRowid));
});
app.put("/api/expenses/:id",(req,res)=>{
  const {name,amount,category,due_day,active}=req.body;
  db.prepare("UPDATE expenses SET name=?,amount=?,category=?,due_day=?,active=? WHERE id=?").run(name,Number(amount),category,due_day?Number(due_day):null,active?1:0,req.params.id);
  res.json(get("expenses",req.params.id));
});
app.delete("/api/expenses/:id",(req,res)=>{db.prepare("DELETE FROM expenses WHERE id=?").run(req.params.id);res.json({ok:true});});

app.get("/api/debts", (_,res)=>res.json(all("debts")));
app.post("/api/debts", (req,res)=>{
  const {name,balance,apr=0,minimum_payment=0,due_day=null,priority=1}=req.body;
  if(!name || Number(balance)<0) return res.status(400).json({error:"Invalid debt"});
  const r=db.prepare("INSERT INTO debts(name,balance,apr,minimum_payment,due_day,priority) VALUES (?,?,?,?,?,?)").run(name,Number(balance),Number(apr),Number(minimum_payment),due_day?Number(due_day):null,Number(priority));
  res.json(get("debts",r.lastInsertRowid));
});
app.put("/api/debts/:id",(req,res)=>{
  const {name,balance,apr,minimum_payment,due_day,priority}=req.body;
  db.prepare("UPDATE debts SET name=?,balance=?,apr=?,minimum_payment=?,due_day=?,priority=? WHERE id=?").run(name,Number(balance),Number(apr),Number(minimum_payment),due_day?Number(due_day):null,Number(priority),req.params.id);
  res.json(get("debts",req.params.id));
});
app.delete("/api/debts/:id",(req,res)=>{db.prepare("DELETE FROM debts WHERE id=?").run(req.params.id);res.json({ok:true});});

app.get("/api/savings", (_,res)=>res.json(all("savings")));
app.post("/api/savings", (req,res)=>{
  const {name,amount=0,target_amount=0,monthly_contribution=0,category="General",active=1}=req.body;
  if(!name || Number(amount)<0) return res.status(400).json({error:"Invalid savings"});
  const r=db.prepare("INSERT INTO savings(name,amount,target_amount,monthly_contribution,category,active) VALUES (?,?,?,?,?,?)").run(name,Number(amount),Number(target_amount),Number(monthly_contribution),category,active?1:0);
  res.json(get("savings",r.lastInsertRowid));
});
app.put("/api/savings/:id",(req,res)=>{
  const {name,amount,target_amount,monthly_contribution,category,active}=req.body;
  db.prepare("UPDATE savings SET name=?,amount=?,target_amount=?,monthly_contribution=?,category=?,active=? WHERE id=?").run(name,Number(amount),Number(target_amount),Number(monthly_contribution),category,active?1:0,req.params.id);
  res.json(get("savings",req.params.id));
});
app.delete("/api/savings/:id",(req,res)=>{db.prepare("DELETE FROM savings WHERE id=?").run(req.params.id);res.json({ok:true});});

app.get("/api/settings", (_,res)=>{
  const rows=db.prepare("SELECT key,value FROM settings").all();
  res.json(Object.fromEntries(rows.map(x=>[x.key,x.value])));
});
app.put("/api/settings",(req,res)=>{
  const stmt=db.prepare("INSERT INTO settings(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");
  const tx=db.transaction(obj=>Object.entries(obj).forEach(([k,v])=>stmt.run(k,String(v))));
  tx(req.body); res.json({ok:true});
});

function monthsBetween(start, n){
  const d=new Date(start+"T00:00:00");
  return Array.from({length:n},(_,i)=>{
    const x=new Date(d); x.setMonth(d.getMonth()+i);
    return new Date(x.getFullYear(),x.getMonth(),1);
  });
}
function money(x){return Math.max(0,Math.round(x*100)/100)}
function simulate(debts, budget, n){
  let balances=debts.map(d=>Number(d.balance));
  const schedule=[];
  for(let m=0;m<n && balances.some(b=>b>0.005);m++){
    const start=balances.slice();
    let interest=0;
    balances=balances.map((b,i)=>{const x=b*(Number(debts[i].apr)/100/12); interest+=x; return b+x;});
    let remaining=budget;
    const paid=Array(debts.length).fill(0);
    // minimums first, capped by remaining balance
    debts.forEach((d,i)=>{
      const p=Math.min(balances[i],Number(d.minimum_payment),remaining);
      paid[i]+=p; balances[i]-=p; remaining-=p;
    });
    // avalanche: highest APR, then explicit priority
    const order=[...debts.keys()].sort((a,b)=>(Number(debts[b].apr)-Number(debts[a].apr)) || (Number(debts[a].priority)-Number(debts[b].priority)));
    for(const i of order){
      if(remaining<=0) break;
      const p=Math.min(balances[i],remaining);
      paid[i]+=p; balances[i]-=p; remaining-=p;
    }
    schedule.push({start,paid,interest,remainingDebt:balances.reduce((a,b)=>a+b,0)});
  }
  return {schedule,remaining:balances.reduce((a,b)=>a+b,0)};
}
function debtPlan(){
  const income=db.prepare("SELECT COALESCE(SUM(amount),0) s FROM income WHERE active=1").get().s;
  const expenses=db.prepare("SELECT COALESCE(SUM(amount),0) s FROM expenses WHERE active=1").get().s;
  const debts=db.prepare("SELECT * FROM debts ORDER BY id").all();
  const target=Number(db.prepare("SELECT value FROM settings WHERE key='targetMonths'").get()?.value||16);
  const start=db.prepare("SELECT value FROM settings WHERE key='startDate'").get()?.value||"2026-09-01";
  const min=debts.reduce((s,d)=>s+Number(d.minimum_payment),0);
  const available=Math.max(0,income-expenses);
  const total=debts.reduce((s,d)=>s+Number(d.balance),0);
  let lo=min, hi=Math.max(min,available,total+debts.reduce((s,d)=>s+Number(d.balance)*Number(d.apr)/100/12*target,0));
  if(!debts.length) return {income,expenses,available,totalDebt:0,targetMonths:target,startDate:start,budget:0,feasible:true,schedule:[]};
  for(let i=0;i<50;i++){const mid=(lo+hi)/2; const sim=simulate(debts,mid,target); if(sim.remaining<=0.01) hi=mid; else lo=mid;}
  const budget=hi;
  const feasible=budget<=available+0.01;
  const sim=simulate(debts,feasible?budget:available,target);
  const dates=monthsBetween(start,target);
  return {
    income,expenses,available,totalDebt:total,targetMonths:target,startDate:start,
    requiredMonthly:money(budget),feasible,usedMonthly:money(feasible?budget:available),
    projectedRemaining:money(sim.remaining),
    months: dates.map((d,i)=>({
      month:d.toISOString().slice(0,7),
      payments:Object.fromEntries(debts.map((x,j)=>[x.name,money(sim.schedule[i]?.paid[j]||0)])),
      totalPayment:money((sim.schedule[i]?.paid||[]).reduce((a,b)=>a+b,0)),
      remainingDebt:money(sim.schedule[i]?.remainingDebt||0)
    }))
  };
}
app.get("/api/plan",(_,res)=>res.json(debtPlan()));
app.get("/api/dashboard",(_,res)=>{
  const inc=db.prepare("SELECT COALESCE(SUM(amount),0) s FROM income WHERE active=1").get().s;
  const exp=db.prepare("SELECT COALESCE(SUM(amount),0) s FROM expenses WHERE active=1").get().s;
  const debt=db.prepare("SELECT COALESCE(SUM(balance),0) s FROM debts").get().s;
  const savings=db.prepare("SELECT COALESCE(SUM(amount),0) s FROM savings WHERE active=1").get().s;
  const savingsTarget=db.prepare("SELECT COALESCE(SUM(target_amount),0) s FROM savings WHERE active=1").get().s;
  const monthlySavingsContribution=db.prepare("SELECT COALESCE(SUM(monthly_contribution),0) s FROM savings WHERE active=1").get().s;
  const plan=debtPlan();
  const chartData=getChartData(plan);
  res.json({income:inc,expenses:exp,available:inc-exp,totalDebt:debt,totalSavings:savings,savingsTarget,monthlySavingsContribution,debtRatio:inc?exp/inc:0,plan,chartData});
});

function getChartData(plan){
  const months=plan.months||[];
  const debts=db.prepare("SELECT * FROM debts ORDER BY id").all();
  const income=db.prepare("SELECT COALESCE(SUM(amount),0) s FROM income WHERE active=1").get().s;
  const expenses=db.prepare("SELECT COALESCE(SUM(amount),0) s FROM expenses WHERE active=1").get().s;
  
  // Spending mix data for pie chart
  const totalDebtPayment=debts.reduce((s,d)=>s+Number(d.minimum_payment),0);
  const availableForSavings=Math.max(0,income-expenses-totalDebtPayment);
  
  const spendingMix=[
    {label:'المصاريف',value:expenses,color:'#ef4444'},
    {label:'أقساط الديون',value:totalDebtPayment,color:'#f59e0b'},
    {label:'الادخار المتاح',value:availableForSavings,color:'#10b981'}
  ].filter(x=>x.value>0);
  
  // Debt reduction over time
  const debtReduction=months.map((m,i)=>({
    month:m.month,
    remaining:m.remainingDebt,
    achieved:plan.totalDebt?((plan.totalDebt-m.remainingDebt)/plan.totalDebt*100):0
  }));
  
  // Monthly cash flow
  const cashFlow=months.map(m=>({
    month:m.month,
    income:income,
    expenses:expenses,
    debtPayment:m.totalPayment,
    cashAfter:income-expenses-m.totalPayment
  }));
  
  // Ending cash after all payments (cumulative)
  let cumulativeCash=0;
  const endingCash=months.map(m=>{
    cumulativeCash+=income-expenses-m.totalPayment;
    return{
      month:m.month,
      endingCash:Math.max(0,cumulativeCash)
    };
  });
  
  // Month-to-month changes with detailed breakdown
  let previousDebt=plan.totalDebt;
  let previousCash=0;
  const monthlyChanges=months.map((m,i)=>{
    const debtChange=previousDebt-m.remainingDebt;
    const cashChange=endingCash[i].endingCash-previousCash;
    previousDebt=m.remainingDebt;
    previousCash=endingCash[i].endingCash;
    
    return{
      month:m.month,
      monthNumber:i+1,
      income:income,
      expenses:expenses,
      debtPayment:m.totalPayment,
      debtRemaining:m.remainingDebt,
      debtChange:debtChange,
      cashChange:cashChange,
      endingCash:endingCash[i].endingCash,
      cumulativeSavings:endingCash[i].endingCash,
      debtProgress:plan.totalDebt?((plan.totalDebt-m.remainingDebt)/plan.totalDebt*100):0
    };
  });
  
  return{
    spendingMix,
    debtReduction,
    cashFlow,
    endingCash,
    monthlyChanges
  };
}

app.use((req,res)=>res.sendFile(path.join(__dirname,"public","index.html")));
app.get("/api/health",(_,res)=>res.json({ok:true,app:"money-manager"}));

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({error: "Internal server error"});
});

app.listen(PORT, "127.0.0.1", () => {
  console.log(`Money Manager running on http://localhost:${PORT}`);
});
