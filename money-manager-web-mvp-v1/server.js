const express = require("express");
const path = require("path");
const Database = require("better-sqlite3");
const XLSX = require("xlsx");

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
CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  transaction_date TEXT NOT NULL,
  merchant TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount >= 0),
  direction TEXT NOT NULL CHECK(direction IN ('income','expense')),
  category TEXT NOT NULL DEFAULT 'Uncategorized',
  account TEXT NOT NULL DEFAULT 'Main account',
  notes TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS subscriptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount >= 0),
  cadence TEXT NOT NULL DEFAULT 'monthly' CHECK(cadence IN ('monthly','yearly')),
  next_charge_date TEXT,
  trial_ends_on TEXT,
  category TEXT NOT NULL DEFAULT 'Subscriptions',
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS admin_tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'General',
  due_date TEXT,
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','done')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  document_type TEXT NOT NULL DEFAULT 'Receipt',
  expiry_date TEXT,
  notes TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
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

// Health check (must be before static files)
app.get("/api/health",(_,res)=>res.json({ok:true,app:"money-manager"}));

// Static files (after API routes)
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

// Financial activity is stored separately from monthly budget assumptions so the
// ledger can be filtered and audited without changing a user's recurring plan.
const isIsoDate = value => !value || /^\d{4}-\d{2}-\d{2}$/.test(value);
const validAmount = value => value !== "" && value !== null && value !== undefined && Number.isFinite(Number(value)) && Number(value) >= 0;
const rowById = (table,id) => db.prepare(`SELECT * FROM ${table} WHERE id=?`).get(id);

function normalizeDateValue(value){
  if(value instanceof Date && !Number.isNaN(value.valueOf())) return toLocalDateStr(value);
  const text=String(value ?? "").trim();
  if(/^\d{4}-\d{2}-\d{2}$/.test(text)) return text;
  const european=text.match(/^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$/);
  if(european) return `${european[3]}-${european[2].padStart(2,"0")}-${european[1].padStart(2,"0")}`;
  return text;
}

function normalizeTransaction(body){
  const transaction_date=normalizeDateValue(body.transaction_date ?? body.date ?? "");
  const merchant=String(body.merchant ?? body.description ?? body.name ?? "").trim();
  const amount=String(body.amount ?? "").replace(/[^0-9,.-]/g, "").replace(",", ".");
  const rawDirection=String(body.direction ?? body.type ?? "expense").trim().toLowerCase();
  const direction=["income","دخل","in"].includes(rawDirection)?"income": ["expense","مصروف","out"].includes(rawDirection)?"expense":rawDirection;
  const category=String(body.category ?? "Uncategorized").trim()||"Uncategorized";
  const account=String(body.account ?? "Main account").trim()||"Main account";
  const notes=String(body.notes ?? "").trim();
  if(!merchant || !validAmount(amount) || !["income","expense"].includes(direction) || !isIsoDate(transaction_date)) return null;
  return [transaction_date,merchant,Number(amount),direction,category,account,notes];
}

app.get("/api/transactions",(req,res)=>{
  const filters=[], values=[];
  if(req.query.q){ filters.push("(merchant LIKE ? OR category LIKE ? OR notes LIKE ?)"); const q=`%${req.query.q.trim()}%`; values.push(q,q,q); }
  if(["income","expense"].includes(req.query.direction)) { filters.push("direction=?"); values.push(req.query.direction); }
  if(req.query.category){ filters.push("category=?"); values.push(req.query.category); }
  const limit=Math.min(Math.max(Number(req.query.limit)||200,1),500);
  const where=filters.length?`WHERE ${filters.join(" AND ")}`:"";
  res.json(db.prepare(`SELECT * FROM transactions ${where} ORDER BY transaction_date DESC,id DESC LIMIT ?`).all(...values,limit));
});
app.post("/api/transactions",(req,res)=>{
  const data=normalizeTransaction(req.body);
  if(!data) return res.status(400).json({error:"Invalid transaction"});
  const r=db.prepare("INSERT INTO transactions(transaction_date,merchant,amount,direction,category,account,notes) VALUES (?,?,?,?,?,?,?)").run(...data);
  res.status(201).json(rowById("transactions",r.lastInsertRowid));
});
app.put("/api/transactions/:id",(req,res)=>{
  const data=normalizeTransaction(req.body);
  if(!data) return res.status(400).json({error:"Invalid transaction"});
  const r=db.prepare("UPDATE transactions SET transaction_date=?,merchant=?,amount=?,direction=?,category=?,account=?,notes=? WHERE id=?").run(...data,req.params.id);
  if(!r.changes) return res.status(404).json({error:"Transaction not found"}); res.json(rowById("transactions",req.params.id));
});
app.delete("/api/transactions/:id",(req,res)=>{const r=db.prepare("DELETE FROM transactions WHERE id=?").run(req.params.id); if(!r.changes)return res.status(404).json({error:"Transaction not found"}); res.json({ok:true});});

app.post("/api/transactions/import-file", express.raw({type:["text/csv","application/csv","application/vnd.ms-excel","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"],limit:"5mb"}), (req,res)=>{
  if(!Buffer.isBuffer(req.body) || !req.body.length) return res.status(400).json({error:"Choose a CSV or XLSX statement first"});
  let rows;
  try {
    const book=XLSX.read(req.body,{type:"buffer",raw:false});
    const sheet=book.Sheets[book.SheetNames[0]];
    rows=XLSX.utils.sheet_to_json(sheet,{defval:""});
  } catch { return res.status(400).json({error:"This file could not be read as a CSV or XLSX statement"}); }
  if(!rows.length) return res.status(400).json({error:"The statement has no transaction rows"});
  if(rows.length>1000) return res.status(400).json({error:"Import up to 1,000 rows at a time"});
  const transactions=[];
  for(let i=0;i<rows.length;i++){
    const data=normalizeTransaction(rows[i]);
    if(!data) return res.status(400).json({error:`Invalid data in statement row ${i+2}. Required columns: transaction_date (or date), merchant, amount, direction.`});
    transactions.push(data);
  }
  const insert=db.prepare("INSERT INTO transactions(transaction_date,merchant,amount,direction,category,account,notes) VALUES (?,?,?,?,?,?,?)");
  db.transaction(items=>items.forEach(item=>{insert.run(...item);}))(transactions);
  res.status(201).json({ok:true,imported:transactions.length});
});

function subscriptionPayload(body){
  const {name,amount,cadence="monthly",next_charge_date=null,trial_ends_on=null,category="Subscriptions",active=1}=body;
  if(!name?.trim() || !validAmount(amount) || !["monthly","yearly"].includes(cadence) || !isIsoDate(next_charge_date) || !isIsoDate(trial_ends_on)) return null;
  return [name.trim(),Number(amount),cadence,next_charge_date||null,trial_ends_on||null,category.trim()||"Subscriptions",active?1:0];
}
app.get("/api/subscriptions",(_,res)=>res.json(all("subscriptions")));
app.post("/api/subscriptions",(req,res)=>{const data=subscriptionPayload(req.body);if(!data)return res.status(400).json({error:"Invalid subscription"});const r=db.prepare("INSERT INTO subscriptions(name,amount,cadence,next_charge_date,trial_ends_on,category,active) VALUES (?,?,?,?,?,?,?)").run(...data);res.status(201).json(rowById("subscriptions",r.lastInsertRowid));});
app.put("/api/subscriptions/:id",(req,res)=>{const data=subscriptionPayload(req.body);if(!data)return res.status(400).json({error:"Invalid subscription"});const r=db.prepare("UPDATE subscriptions SET name=?,amount=?,cadence=?,next_charge_date=?,trial_ends_on=?,category=?,active=? WHERE id=?").run(...data,req.params.id);if(!r.changes)return res.status(404).json({error:"Subscription not found"});res.json(rowById("subscriptions",req.params.id));});
app.delete("/api/subscriptions/:id",(req,res)=>{const r=db.prepare("DELETE FROM subscriptions WHERE id=?").run(req.params.id);if(!r.changes)return res.status(404).json({error:"Subscription not found"});res.json({ok:true});});

function taskPayload(body){
  const {title,category="General",due_date=null,notes="",status="open"}=body;
  if(!title?.trim() || !isIsoDate(due_date) || !["open","done"].includes(status)) return null;
  return [title.trim(),category.trim()||"General",due_date||null,notes.trim(),status];
}
app.get("/api/admin-tasks",(_,res)=>res.json(db.prepare("SELECT * FROM admin_tasks ORDER BY status,due_date IS NULL,due_date,id DESC").all()));
app.post("/api/admin-tasks",(req,res)=>{const data=taskPayload(req.body);if(!data)return res.status(400).json({error:"Invalid admin task"});const r=db.prepare("INSERT INTO admin_tasks(title,category,due_date,notes,status) VALUES (?,?,?,?,?)").run(...data);res.status(201).json(rowById("admin_tasks",r.lastInsertRowid));});
app.put("/api/admin-tasks/:id",(req,res)=>{const data=taskPayload(req.body);if(!data)return res.status(400).json({error:"Invalid admin task"});const r=db.prepare("UPDATE admin_tasks SET title=?,category=?,due_date=?,notes=?,status=? WHERE id=?").run(...data,req.params.id);if(!r.changes)return res.status(404).json({error:"Task not found"});res.json(rowById("admin_tasks",req.params.id));});
app.delete("/api/admin-tasks/:id",(req,res)=>{const r=db.prepare("DELETE FROM admin_tasks WHERE id=?").run(req.params.id);if(!r.changes)return res.status(404).json({error:"Task not found"});res.json({ok:true});});

function documentPayload(body){
  const {title,document_type="Receipt",expiry_date=null,notes=""}=body;
  if(!title?.trim() || !isIsoDate(expiry_date)) return null;
  return [title.trim(),document_type.trim()||"Receipt",expiry_date||null,notes.trim()];
}
app.get("/api/documents",(_,res)=>res.json(db.prepare("SELECT * FROM documents ORDER BY expiry_date IS NULL,expiry_date,id DESC").all()));
app.post("/api/documents",(req,res)=>{const data=documentPayload(req.body);if(!data)return res.status(400).json({error:"Invalid document"});const r=db.prepare("INSERT INTO documents(title,document_type,expiry_date,notes) VALUES (?,?,?,?)").run(...data);res.status(201).json(rowById("documents",r.lastInsertRowid));});
app.put("/api/documents/:id",(req,res)=>{const data=documentPayload(req.body);if(!data)return res.status(400).json({error:"Invalid document"});const r=db.prepare("UPDATE documents SET title=?,document_type=?,expiry_date=?,notes=? WHERE id=?").run(...data,req.params.id);if(!r.changes)return res.status(404).json({error:"Document not found"});res.json(rowById("documents",req.params.id));});
app.delete("/api/documents/:id",(req,res)=>{const r=db.prepare("DELETE FROM documents WHERE id=?").run(req.params.id);if(!r.changes)return res.status(404).json({error:"Document not found"});res.json({ok:true});});

app.get("/api/settings", (_,res)=>{
  const rows=db.prepare("SELECT key,value FROM settings").all();
  res.json(Object.fromEntries(rows.map(x=>[x.key,x.value])));
});
app.put("/api/settings",(req,res)=>{
  const stmt=db.prepare("INSERT INTO settings(key,value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value");
  const tx=db.transaction(obj=>Object.entries(obj).forEach(([k,v])=>{stmt.run(k,String(v));}));
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

// Format a Date using its local y/m/d components (avoids the UTC-shift bug
// that toISOString() introduces for timezones ahead of UTC).
function toLocalDateStr(d){
  const y=d.getFullYear(), m=String(d.getMonth()+1).padStart(2,"0"), day=String(d.getDate()).padStart(2,"0");
  return `${y}-${m}-${day}`;
}

// Given a day-of-month (1-31) and a reference date, find the next real calendar
// date that bill falls on (clamping to the last day of the month if the month
// is shorter than the given day, e.g. due_day=31 in February).
function nextOccurrence(dueDay, from){
  if(!dueDay) return null;
  const clampToMonth=(y,m,d)=>{
    const lastDay=new Date(y,m+1,0).getDate();
    return new Date(y,m,Math.min(d,lastDay));
  };
  const y=from.getFullYear(), m=from.getMonth();
  let candidate=clampToMonth(y,m,dueDay);
  if(candidate<from){
    const ny=m===11?y+1:y, nm=(m+1)%12;
    candidate=clampToMonth(ny,nm,dueDay);
  }
  return candidate;
}

function computeUpcomingBills(days){
  const today=new Date(); today.setHours(0,0,0,0);
  const horizon=new Date(today); horizon.setDate(horizon.getDate()+days);
  const bills=[];
  const expenseRows=db.prepare("SELECT * FROM expenses WHERE active=1 AND due_day IS NOT NULL").all();
  const debtRows=db.prepare("SELECT * FROM debts WHERE due_day IS NOT NULL").all();
  expenseRows.forEach(r=>{
    const d=nextOccurrence(r.due_day,today);
    if(d && d<=horizon) bills.push({type:"expense",id:r.id,name:r.name,amount:money(Number(r.amount)||0),dueDate:toLocalDateStr(d),daysUntil:Math.round((d-today)/86400000)});
  });
  debtRows.forEach(r=>{
    const d=nextOccurrence(r.due_day,today);
    if(d && d<=horizon && Number(r.minimum_payment)>0) bills.push({type:"debt",id:r.id,name:r.name,amount:money(Number(r.minimum_payment)||0),dueDate:toLocalDateStr(d),daysUntil:Math.round((d-today)/86400000)});
  });
  bills.sort((a,b)=>a.daysUntil-b.daysUntil);
  return {days,count:bills.length,total:money(bills.reduce((s,b)=>s+b.amount,0)),bills};
}

function financialAlerts(days=7){
  const today=toLocalDateStr(new Date());
  const horizonDate=new Date(); horizonDate.setDate(horizonDate.getDate()+days);
  const horizon=toLocalDateStr(horizonDate);
  const subscriptions=db.prepare("SELECT * FROM subscriptions WHERE active=1 AND ((next_charge_date BETWEEN ? AND ?) OR (trial_ends_on BETWEEN ? AND ?)) ORDER BY COALESCE(trial_ends_on,next_charge_date)").all(today,horizon,today,horizon);
  const tasks=db.prepare("SELECT * FROM admin_tasks WHERE status='open' AND due_date BETWEEN ? AND ? ORDER BY due_date").all(today,horizon);
  return {subscriptions,tasks};
}

// Compare completed financial periods using ledger activity when it exists.
// A recurring-budget baseline keeps the comparison useful before a user has
// imported enough transaction history.
function dateKey(date){ return toLocalDateStr(date); }
function addMonths(date, amount){ const copy=new Date(date); copy.setMonth(copy.getMonth()+amount); return copy; }
function ledgerSummary(from, to){
  return db.prepare("SELECT COUNT(*) count, COALESCE(SUM(CASE WHEN direction='income' THEN amount ELSE 0 END),0) income, COALESCE(SUM(CASE WHEN direction='expense' THEN amount ELSE 0 END),0) expenses FROM transactions WHERE transaction_date>=? AND transaction_date<=?").get(from,to);
}
function percentChange(current, previous){
  if(Math.abs(previous)<0.005) return null;
  return Math.round(((current-previous)/Math.abs(previous))*1000)/10;
}
function comparisonForPeriod(currentStart, currentEnd, previousStart, previousEnd, months, plannedIncome, plannedExpenses){
  const currentLedger=ledgerSummary(currentStart,currentEnd);
  const previousLedger=ledgerSummary(previousStart,previousEnd);
  const useActual=currentLedger.count>0 && previousLedger.count>0;
  const current=useActual
    ? {income:Number(currentLedger.income),expenses:Number(currentLedger.expenses)}
    : {income:plannedIncome*months,expenses:plannedExpenses*months};
  const previous=useActual
    ? {income:Number(previousLedger.income),expenses:Number(previousLedger.expenses)}
    : {income:plannedIncome*months,expenses:plannedExpenses*months};
  current.netCashFlow=current.income-current.expenses;
  previous.netCashFlow=previous.income-previous.expenses;
  return {
    source:useActual?"actual":"planned",
    current:{...current,label:`${currentStart} إلى ${currentEnd}`},
    previous:{...previous,label:`${previousStart} إلى ${previousEnd}`},
    changes:Object.fromEntries(["income","expenses","netCashFlow"].map(key=>[key,{amount:money(current[key]-previous[key]),signed:Math.round((current[key]-previous[key])*100)/100,percent:percentChange(current[key],previous[key])}]))
  };
}
function periodComparison(plannedIncome, plannedExpenses){
  const today=new Date();
  const monthStart=new Date(today.getFullYear(),today.getMonth(),1);
  const monthEnd=new Date(today.getFullYear(),today.getMonth()+1,0);
  const previousMonthStart=addMonths(monthStart,-1);
  const previousMonthEnd=new Date(today.getFullYear(),today.getMonth(),0);
  const quarterMonth=Math.floor(today.getMonth()/3)*3;
  const quarterStart=new Date(today.getFullYear(),quarterMonth,1);
  const quarterEnd=new Date(today.getFullYear(),quarterMonth+3,0);
  const previousQuarterStart=new Date(today.getFullYear(),quarterMonth-3,1);
  const previousQuarterEnd=new Date(today.getFullYear(),quarterMonth,0);
  return {
    month:comparisonForPeriod(dateKey(monthStart),dateKey(monthEnd),dateKey(previousMonthStart),dateKey(previousMonthEnd),1,plannedIncome,plannedExpenses),
    quarter:comparisonForPeriod(dateKey(quarterStart),dateKey(quarterEnd),dateKey(previousQuarterStart),dateKey(previousQuarterEnd),3,plannedIncome,plannedExpenses)
  };
}
app.get("/api/upcoming-bills",(req,res)=>{
  const days=Number(req.query.days)||7;
  res.json(computeUpcomingBills(days));
});

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
  const debtMinPayments=db.prepare("SELECT COALESCE(SUM(minimum_payment),0) s FROM debts").get().s;
  const savings=db.prepare("SELECT COALESCE(SUM(amount),0) s FROM savings WHERE active=1").get().s;
  const savingsTarget=db.prepare("SELECT COALESCE(SUM(target_amount),0) s FROM savings WHERE active=1").get().s;
  const monthlySavingsContribution=db.prepare("SELECT COALESCE(SUM(monthly_contribution),0) s FROM savings WHERE active=1").get().s;
  const plan=debtPlan();
  const chartData=getChartData(plan);
  const netCashFlow=money(inc-exp-debtMinPayments-monthlySavingsContribution);
  const upcomingBills=computeUpcomingBills(7);
  const month=new Date().toISOString().slice(0,7);
  const transactionTotals=db.prepare("SELECT COALESCE(SUM(CASE WHEN direction='income' THEN amount ELSE 0 END),0) income, COALESCE(SUM(CASE WHEN direction='expense' THEN amount ELSE 0 END),0) expenses FROM transactions WHERE substr(transaction_date,1,7)=?").get(month);
  const alerts=financialAlerts(7);
  const comparison=periodComparison(Number(inc),Number(exp)+Number(debtMinPayments)+Number(monthlySavingsContribution));
  res.json({income:inc,expenses:exp,available:inc-exp,totalDebt:debt,totalSavings:savings,savingsTarget,monthlySavingsContribution,debtRatio:inc?exp/inc:0,netCashFlow,upcomingBills,transactionTotals,alerts,comparison,plan,chartData});
});

const SANKEY_CHART_COLORS=["--chart-1","--chart-2","--chart-3","--chart-4","--chart-5","--chart-6"];
app.get("/api/cashflow-sankey",(req,res)=>{
  const section=req.query.section;
  const incomeRows=db.prepare("SELECT * FROM income WHERE active=1 ORDER BY id").all();
  const expenseRows=db.prepare("SELECT * FROM expenses WHERE active=1 ORDER BY id").all();
  const debtRows=db.prepare("SELECT * FROM debts ORDER BY id").all();
  const savingsRows=db.prepare("SELECT * FROM savings WHERE active=1 ORDER BY id").all();

  const sliderRange=(val,minFallback,step)=>({min:0,max:Math.max(minFallback,Math.ceil((Number(val)||0)*2/step)*step),step});

  // Section-focused views: instead of the full income -> categories -> line
  // items picture, show just that section's own total broken down into its
  // own line items (e.g. debts page -> total debt payments -> each debt).
  if(section==="expenses"||section==="debts"||section==="savings"){
    const focus={
      expenses:{key:"spending",label:"إجمالي المصروفات",rows:expenseRows,table:"expenses",field:"amount",minFallback:500,step:25},
      debts:{key:"debt_payments",label:"إجمالي سداد الديون",rows:debtRows,table:"debts",field:"minimum_payment",minFallback:200,step:10},
      savings:{key:"savings_category",label:"إجمالي الادخار",rows:savingsRows,table:"savings",field:"monthly_contribution",minFallback:200,step:10},
    }[section];

    const nodes=[{key:focus.key,label:focus.label,type:"expense",parent:null,colorVar:"--chart-1"}];
    focus.rows.forEach((row,i)=>{
      nodes.push({
        key:`${focus.table}_${row.id}`,
        label:row.name?.trim()||`${focus.label} ${row.id}`,
        value:Number(row[focus.field])||0,
        type:"expense",
        parent:focus.key,
        colorVar:SANKEY_CHART_COLORS[i%SANKEY_CHART_COLORS.length],
        slider:sliderRange(row[focus.field],focus.minFallback,focus.step),
        sourceTable:focus.table,sourceId:row.id,updateField:focus.field,raw:row
      });
    });

    return res.json({
      heroMode:"total_expense",
      labels:{
        currencySymbol:"€",
        title:"تدفق الميزانية الشهرية",
        subtitle:`تفصيل ${focus.label}`,
        heroSubtitle:"الإجمالي الشهري",
        incomeLabel:"الدخل",
        expenseLabel:focus.label
      },
      nodes
    });
  }

  const nodes=[];

  // Stage 1 -> 2: income sources feeding the single "Total Income" hub
  incomeRows.forEach((row,i)=>{
    nodes.push({
      key:`income_${row.id}`,
      label:row.name?.trim()||`Income ${row.id}`,
      value:Number(row.amount)||0,
      type:"income",
      parent:"total_income",
      colorVar:SANKEY_CHART_COLORS[i%SANKEY_CHART_COLORS.length],
      slider:sliderRange(row.amount,1000,50),
      sourceTable:"income",sourceId:row.id,updateField:"amount",raw:row
    });
  });
  nodes.push({key:"total_income",label:"إجمالي الدخل",type:"income",parent:null,colorVar:"--chart-1"});

  // Stage 2 -> 3: the three destination categories
  nodes.push({key:"debt_payments",label:"سداد الديون",type:"expense",parent:null,colorVar:"--chart-4"});
  nodes.push({key:"savings_category",label:"الادخار",type:"expense",parent:null,colorVar:"--chart-2"});
  nodes.push({key:"spending",label:"المصروفات",type:"expense",parent:null,colorVar:"--chart-6"});

  // Stage 3 -> 4: individual debts, savings goals, and expenses under each category
  debtRows.forEach((row,i)=>{
    nodes.push({
      key:`debt_${row.id}`,
      label:row.name?.trim()||`Debt ${row.id}`,
      value:Number(row.minimum_payment)||0,
      type:"expense",
      parent:"debt_payments",
      colorVar:SANKEY_CHART_COLORS[i%SANKEY_CHART_COLORS.length],
      slider:sliderRange(row.minimum_payment,200,10),
      sourceTable:"debts",sourceId:row.id,updateField:"minimum_payment",raw:row
    });
  });
  savingsRows.forEach((row,i)=>{
    nodes.push({
      key:`saving_${row.id}`,
      label:row.name?.trim()||`Saving ${row.id}`,
      value:Number(row.monthly_contribution)||0,
      type:"expense",
      parent:"savings_category",
      colorVar:SANKEY_CHART_COLORS[i%SANKEY_CHART_COLORS.length],
      slider:sliderRange(row.monthly_contribution,200,10),
      sourceTable:"savings",sourceId:row.id,updateField:"monthly_contribution",raw:row
    });
  });
  expenseRows.forEach((row,i)=>{
    nodes.push({
      key:`expense_${row.id}`,
      label:row.name?.trim()||`Expense ${row.id}`,
      value:Number(row.amount)||0,
      type:"expense",
      parent:"spending",
      colorVar:SANKEY_CHART_COLORS[i%SANKEY_CHART_COLORS.length],
      slider:sliderRange(row.amount,500,25),
      sourceTable:"expenses",sourceId:row.id,updateField:"amount",raw:row
    });
  });

  // Unallocated surplus (income left over after debts + savings + spending), shown as a 4th category
  const totalIncome=incomeRows.reduce((s,r)=>s+(Number(r.amount)||0),0);
  const totalDebtPay=debtRows.reduce((s,r)=>s+(Number(r.minimum_payment)||0),0);
  const totalSavingsContrib=savingsRows.reduce((s,r)=>s+(Number(r.monthly_contribution)||0),0);
  const totalSpending=expenseRows.reduce((s,r)=>s+(Number(r.amount)||0),0);
  const surplus=totalIncome-totalDebtPay-totalSavingsContrib-totalSpending;
  if(surplus>0.01){
    nodes.push({key:"surplus",label:"فائض غير مخصص",value:surplus,type:"expense",parent:null,colorVar:"--positive"});
  }

  res.json({
    heroMode:section==="income"?"total_income":"total_expense",
    labels:{
      currencySymbol:"€",
      title:"تدفق الميزانية الشهرية",
      subtitle:section==="income"?"كيف يتم توزيع دخلك على الديون والادخار والمصروفات":"من مصادر الدخل إلى الديون، الادخار، والمصروفات",
      heroSubtitle:section==="income"?"إجمالي الدخل الشهري":"إجمالي المخصص شهريًا",
      incomeLabel:"الدخل",
      expenseLabel:"المخصص"
    },
    nodes
  });
});

function getChartData(plan){
  const months=plan.months||[];
  const debts=db.prepare("SELECT * FROM debts ORDER BY id").all();
  const income=db.prepare("SELECT COALESCE(SUM(amount),0) s FROM income WHERE active=1").get().s;
  const expenses=db.prepare("SELECT COALESCE(SUM(amount),0) s FROM expenses WHERE active=1").get().s;
  const monthlySavingsContribution=db.prepare("SELECT COALESCE(SUM(monthly_contribution),0) s FROM savings WHERE active=1").get().s;
  
  // Spending mix data for pie chart
  const totalDebtPayment=debts.reduce((s,d)=>s+Number(d.minimum_payment),0);
  const availableForSavings=Math.max(0,income-expenses-totalDebtPayment);
  
  const spendingMix=[
    {label:'المصاريف',value:expenses,color:'#ef4444'},
    {label:'أقساط الديون',value:totalDebtPayment,color:'#f59e0b'},
    {label:'مساهمة الادخار',value:monthlySavingsContribution,color:'#8b5cf6'},
    {label:'المتبقي',value:Math.max(0,availableForSavings-monthlySavingsContribution),color:'#10b981'}
  ].filter(x=>x.value>0);
  
  // Debt reduction over time
  const debtReduction=months.map((m,i)=>({
    month:m.month,
    remaining:m.remainingDebt,
    achieved:plan.totalDebt?((plan.totalDebt-m.remainingDebt)/plan.totalDebt*100):0
  }));
  
  // Monthly cash flow with savings
  const cashFlow=months.map(m=>({
    month:m.month,
    income:income,
    expenses:expenses,
    debtPayment:m.totalPayment,
    savingsContribution:monthlySavingsContribution,
    cashAfter:income-expenses-m.totalPayment-monthlySavingsContribution
  }));
  
  // Ending cash after all payments (cumulative)
  let cumulativeCash=0;
  let cumulativeSavings=0;
  const endingCash=months.map(m=>{
    cumulativeCash+=income-expenses-m.totalPayment-monthlySavingsContribution;
    cumulativeSavings+=monthlySavingsContribution;
    return{
      month:m.month,
      endingCash:Math.max(0,cumulativeCash),
      cumulativeSavings:cumulativeSavings
    };
  });
  
  // Month-to-month changes with detailed breakdown
  let previousDebt=plan.totalDebt;
  let previousCash=0;
  let previousSavings=0;
  const monthlyChanges=months.map((m,i)=>{
    const debtChange=previousDebt-m.remainingDebt;
    const cashChange=endingCash[i].endingCash-previousCash;
    const savingsChange=endingCash[i].cumulativeSavings-previousSavings;
    previousDebt=m.remainingDebt;
    previousCash=endingCash[i].endingCash;
    previousSavings=endingCash[i].cumulativeSavings;
    
    return{
      month:m.month,
      monthNumber:i+1,
      income:income,
      expenses:expenses,
      debtPayment:m.totalPayment,
      savingsContribution:monthlySavingsContribution,
      debtRemaining:m.remainingDebt,
      debtChange:debtChange,
      cashChange:cashChange,
      savingsChange:savingsChange,
      endingCash:endingCash[i].endingCash,
      cumulativeSavings:endingCash[i].cumulativeSavings,
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

// Catch-all for frontend routes (must be after all API routes)
app.use((req,res)=>{
  res.sendFile(path.join(__dirname,"public","index.html"));
});

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({error: "Internal server error"});
});

app.listen(PORT, "127.0.0.1", () => {
  console.log(`Money Manager running on http://localhost:${PORT}`);
});
