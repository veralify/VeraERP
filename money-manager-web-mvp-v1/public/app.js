const state = { page: "dashboard", transactionQuery: "", comparisonMode: "month", comparison: null };

const $ = (selector) => document.querySelector(selector);

const modalClose = $("#modal-close");

if (modalClose) {
  modalClose.addEventListener("click", closeModal);
}

const modal = $("#modal");

if (modal) {
  modal.addEventListener("click", (event) => {
    if (event.target === modal) {
      closeModal();
    }
  });
}

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
  localStorage.setItem("money-manager-theme", theme);
  $("#theme-toggle")?.setAttribute("aria-label", theme === "dark" ? "تفعيل المظهر الفاتح" : "تفعيل المظهر الداكن");
}

applyTheme(localStorage.getItem("money-manager-theme") || "light");
$("#theme-toggle")?.addEventListener("click", () => {
  applyTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
});

const fmt = (n) =>
  new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "EUR",
    maximumFractionDigits: 2,
  }).format(Number(n || 0));

const esc = (s) =>
  String(s ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;",
  }[c]));

function formatDelta(value) {
  const numeric = Number(value || 0);
  return `${numeric > 0 ? "+" : numeric < 0 ? "−" : ""}${fmt(Math.abs(numeric))}`;
}

function renderPeriodComparison(mode = state.comparisonMode) {
  if (!state.comparison?.[mode]) return;
  state.comparisonMode = mode;
  const comparison = state.comparison[mode];
  const labels = {
    income: ["الدخل", "زيادة الدخل"],
    expenses: ["الإنفاق والالتزامات", "تغير الإنفاق"],
    netCashFlow: ["صافي التدفق", "تغير السيولة"],
  };
  const metrics = Object.entries(labels).map(([key, [title, detail]]) => {
    const change = comparison.changes[key];
    const isExpense = key === "expenses";
    const favorable = isExpense ? change.signed <= 0 : change.signed >= 0;
    const changeClass = change.signed === 0 ? "neutral" : favorable ? "up" : "down";
    const percent = change.percent === null ? "لا توجد فترة سابقة" : `${change.percent > 0 ? "+" : ""}${change.percent}%`;
    return `<div class="comparison-metric">
      <span>${title}</span>
      <strong>${fmt(comparison.current[key])}</strong>
      <div class="comparison-change ${changeClass}"><b>${formatDelta(change.signed)}</b><small>${percent} · ${detail}</small></div>
    </div>`;
  }).join("");

  $("#comparison-metrics").innerHTML = metrics;
  $("#comparison-source").textContent = comparison.source === "actual" ? "مقارنة فعلية من سجل المعاملات" : "مقارنة مبنية على خطتك الشهرية";
  $("#comparison-range").textContent = `الحالي: ${comparison.current.label} · السابق: ${comparison.previous.label}`;
  document.querySelectorAll("[data-comparison-mode]").forEach((button) => {
    button.classList.toggle("active", button.dataset.comparisonMode === mode);
  });
}

async function api(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });

  const text = await response.text();

  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { error: text };
  }

  if (!response.ok) {
    throw new Error(data.error || `Request failed (${response.status})`);
  }

  return data;
}

/* =========================
   Navigation
========================= */

const pageMeta = {
  dashboard: ["لوحة التحكم", "نظرة سريعة على وضعك المالي"],
  income: ["مصادر الدخل", "أضف كل مصادر الدخل الثابتة والمتغيرة"],
  expenses: ["المصاريف", "تابع التزاماتك ومصاريفك الشهرية"],
  transactions: ["سجل المعاملات", "ابحث وصنّف كل حركة مالية في مكان واحد"],
  subscriptions: ["رادار الاشتراكات", "تابع الرسوم المتكررة والتجارب المجانية"],
  debts: ["الديون", "سجل الأرصدة والفوائد والأقساط"],
  savings: ["المدخرات", "تابع أهدافك الادخارية ومساهماتك الشهرية"],
  plan: ["خطة سداد الديون", "خطة شهرية تلقائية حسب المدة والقدرة المالية"],
  "admin-tasks": ["المهام والمواعيد", "تابع الضرائب والتجديدات والمهام الإدارية"],
  documents: ["الوثائق والإيصالات", "سجل منظم للضمانات والإيصالات والمستندات المهمة"],
};

function setPage(page) {
  state.page = page;

  document.querySelectorAll(".nav").forEach((item) => {
    item.classList.toggle("active", item.dataset.page === page);
  });

  const meta = pageMeta[page];

  if (meta) {
    $("#title").textContent = meta[0];
    $("#subtitle").textContent = meta[1];
  }

  render();
}

document.querySelectorAll(".nav").forEach((item) => {
  item.addEventListener("click", () => {
    setPage(item.dataset.page);
  });
});

/* =========================
   Render
========================= */

async function render() {
  try {
    if (state.page === "dashboard") await dashboard();
    if (state.page === "income") await listPage("income");
    if (state.page === "expenses") await listPage("expenses");
    if (state.page === "transactions") await listPage("transactions");
    if (state.page === "subscriptions") await listPage("subscriptions");
    if (state.page === "debts") await listPage("debts");
    if (state.page === "savings") await listPage("savings");
    if (state.page === "plan") await planPage();
    if (state.page === "admin-tasks") await listPage("admin-tasks");
    if (state.page === "documents") await listPage("documents");
  } catch (error) {
    console.error(error);

    $("#content").innerHTML = `
      <div class="notice bad">
        <strong>حدث خطأ</strong>
        <br>
        ${esc(error.message)}
      </div>
    `;
  }
}

/* =========================
   Dashboard
========================= */

async function dashboard() {
  const data = await api("/api/dashboard");
  const plan = data.plan;
  const chartData = data.chartData;

  const progress = plan.totalDebt
    ? Math.max(
        0,
        Math.min(
          100,
          (1 - plan.projectedRemaining / plan.totalDebt) * 100
        )
      )
    : 0;

  const months = plan.months || [];
  const finalEndingCash = chartData.endingCash.length > 0 
    ? chartData.endingCash[chartData.endingCash.length - 1].endingCash 
    : 0;
  const monthlyChanges = chartData.monthlyChanges || [];

  $("#content").innerHTML = `
    <section class="dashboard-hero">
      <div>
        <span class="eyebrow">نظرة هذا الشهر</span>
        <h2>أموالك تحت السيطرة</h2>
        <p>اتخذ الخطوة التالية بناءً على وضعك النقدي الحالي.</p>
      </div>
      <div class="hero-balance ${data.netCashFlow >= 0 ? "positive" : "negative"}">
        <span>صافي التدفق المتاح</span>
        <strong>${fmt(data.netCashFlow)}</strong>
        <small>${data.netCashFlow >= 0 ? "بعد المصاريف والأقساط والادخار" : "تحتاج الخطة إلى تخفيض التزامات"}</small>
      </div>
    </section>

    ${sankeyWidgetPanel()}

    <div class="metric-grid">
      <article class="metric-card income-card">
        <div class="metric-heading"><span class="metric-icon">↙</span><span>الدخل الشهري</span></div>
        <strong>${fmt(data.income)}</strong>
        <p>مصادر دخل نشطة</p>
      </article>
      <article class="metric-card expense-card">
        <div class="metric-heading"><span class="metric-icon">↗</span><span>المصاريف الأساسية</span></div>
        <strong>${fmt(data.expenses)}</strong>
        <p>${(data.debtRatio * 100).toFixed(1)}% من دخلك الشهري</p>
      </article>
      <article class="metric-card ${data.upcomingBills.count ? "risk-card" : "safe-card"}">
        <div class="metric-heading"><span class="metric-icon">◷</span><span>استحقاقات 7 أيام</span></div>
        <strong>${data.upcomingBills.count}</strong>
        <p>${data.upcomingBills.count ? `${fmt(data.upcomingBills.total)} تحتاج متابعة` : "لا توجد دفعات عاجلة"}</p>
      </article>
      <article class="metric-card debt-card">
        <div class="metric-heading"><span class="metric-icon">◎</span><span>إجمالي الديون</span></div>
        <strong>${fmt(data.totalDebt)}</strong>
        <p>${progress.toFixed(0)}% من مسار الخطة الحالي</p>
      </article>
    </div>

    <div class="action-bar" aria-label="إجراءات سريعة">
      <div><span class="eyebrow">إجراءات سريعة</span><strong>سجّل ما حدث الآن</strong></div>
      <div class="quick-actions">
        <button class="btn secondary" data-quick-action="expenses">إضافة مصروف</button>
        <button class="btn" data-quick-action="transactions">تسجيل معاملة</button>
        <button class="btn secondary" data-quick-action="admin-tasks">مهمة إدارية</button>
      </div>
    </div>

    <section class="comparison-panel">
      <div class="comparison-head">
        <div>
          <span class="eyebrow">مراقبة الأداء</span>
          <h2>مقارنة الفترات</h2>
          <p id="comparison-source"></p>
        </div>
        <div class="period-toggle" role="group" aria-label="فترة المقارنة">
          <button type="button" data-comparison-mode="month" class="active">شهري</button>
          <button type="button" data-comparison-mode="quarter">ربعي</button>
        </div>
      </div>
      <div class="comparison-metrics" id="comparison-metrics"></div>
      <p class="comparison-range" id="comparison-range"></p>
    </section>

    ${(data.alerts.subscriptions.length || data.alerts.tasks.length) ? `
      <div class="grid two">
        <div class="panel alert-panel">
          <div class="panel-head"><h2>تنبيهات الاشتراكات</h2><span class="badge bad">${data.alerts.subscriptions.length}</span></div>
          ${data.alerts.subscriptions.length ? data.alerts.subscriptions.map((item) => `<div class="kpi"><span>${esc(item.name)}${item.trial_ends_on ? " · تنتهي التجربة " + item.trial_ends_on : " · خصم " + (item.next_charge_date || "قريبًا")}</span><b>${fmt(item.amount)}</b></div>`).join("") : ""}
        </div>
        <div class="panel alert-panel">
          <div class="panel-head"><h2>مهام قريبة</h2><span class="badge ${data.alerts.tasks.length ? "bad" : "good"}">${data.alerts.tasks.length}</span></div>
          ${data.alerts.tasks.length ? data.alerts.tasks.map((item) => `<div class="kpi"><span>${esc(item.title)} · ${item.due_date}</span><b>${esc(item.category)}</b></div>`).join("") : ""}
        </div>
      </div>` : ""}

    <div class="panel">

      <div class="panel-head">
        <h2>الفواتير القادمة (خلال 7 أيام)</h2>
        <span class="badge ${data.upcomingBills.count > 0 ? "bad" : "good"}">
          ${data.upcomingBills.count} فاتورة
        </span>
      </div>

      ${
        data.upcomingBills.bills.length === 0
          ? `<div class="notice good">لا توجد فواتير مستحقة خلال الأيام السبعة القادمة 🎉</div>`
          : `
            <div class="table-responsive">
              <table>
                <thead>
                  <tr>
                    <th>الاسم</th>
                    <th>النوع</th>
                    <th>تاريخ الاستحقاق</th>
                    <th>خلال</th>
                    <th>المبلغ</th>
                  </tr>
                </thead>
                <tbody>
                  ${data.upcomingBills.bills
                    .map(
                      (b) => `
                        <tr>
                          <td>${esc(b.name)}</td>
                          <td>${b.type === "debt" ? "قسط دين" : "مصروف"}</td>
                          <td>${b.dueDate}</td>
                          <td class="${b.daysUntil <= 2 ? "bad" : ""}">${
                        b.daysUntil === 0 ? "اليوم" : `بعد ${b.daysUntil} يوم`
                      }</td>
                          <td>${fmt(b.amount)}</td>
                        </tr>
                      `
                    )
                    .join("")}
                </tbody>
              </table>
            </div>
          `
      }

    </div>

    <div class="grid two">

      <div class="panel">

        <div class="panel-head">
          <h2>تقدم التخلص من الديون</h2>

          <span class="badge ${plan.feasible ? "good" : "bad"}">
            ${plan.feasible ? "الخطة قابلة للتنفيذ" : "الخطة تحتاج تعديل"}
          </span>
        </div>

        <div class="value">${progress.toFixed(0)}%</div>

        <div class="progress">
          <div style="width:${progress}%"></div>
        </div>

        <div class="kpi">
          <span>المدة المستهدفة</span>
          <b>${plan.targetMonths} شهر</b>
        </div>

        <div class="kpi">
          <span>القسط الشهري المطلوب</span>
          <b>${fmt(plan.requiredMonthly)}</b>
        </div>

        <div class="kpi">
          <span>المتبقي المتوقع</span>
          <b>${fmt(plan.projectedRemaining)}</b>
        </div>

      </div>

      <div class="panel">

        <div class="panel-head">
          <h2>الرصيد النهائي بعد جميع المدفوعات</h2>
        </div>

        <div class="value good">${fmt(finalEndingCash)}</div>

        <div class="kpi">
          <span>بعد ${plan.targetMonths} شهر</span>
          <b>من تنفيذ الخطة</b>
        </div>

        <div class="kpi">
          <span>التراكم الشهري</span>
          <b class="blue">تلقائي</b>
        </div>

        <div class="kpi">
          <span>الحالة</span>
          <b class="${finalEndingCash > 0 ? 'good' : 'bad'}">
            ${finalEndingCash > 0 ? 'إيجابي' : 'سلبي'}
          </b>
        </div>

      </div>

    </div>

    <div class="grid two">

      <div class="panel">

        <div class="panel-head">
          <h2>توزيع الدخل الشهري</h2>
        </div>

        <div class="chart-container">
          <canvas id="spendingMixChart"></canvas>
        </div>

      </div>

      <div class="panel">

        <div class="panel-head">
          <h2>تخفيض الديون بمرور الوقت</h2>
        </div>

        <div class="chart-container">
          <canvas id="debtReductionChart"></canvas>
        </div>

      </div>

    </div>

    <div class="panel">

      <div class="panel-head">
        <h2>التدفق النقدي الشهري</h2>

        <button class="btn secondary" id="show-plan-btn">
          عرض الخطة كاملة
        </button>
      </div>

      <div class="chart-container">
        <canvas id="cashFlowChart"></canvas>
      </div>

    </div>

    <div class="panel">

      <div class="panel-head">
        <h2>التغيرات الشهرية الكاملة</h2>
        <span class="badge">${monthlyChanges.length} شهر</span>
      </div>

      <div class="table-responsive">
        <table>

          <thead>
            <tr>
              <th>الشهر</th>
              <th>الدخل</th>
              <th>المصاريف</th>
              <th>سداد الديون</th>
              <th>مساهمة الادخار</th>
              <th>الديون المتبقية</th>
              <th>تخفيض الديون</th>
              <th>التدفق النقدي</th>
              <th>الرصيد التراكمي</th>
              <th>الادخار التراكمي</th>
              <th>التقدم %</th>
            </tr>
          </thead>

          <tbody>
            ${monthlyChanges
              .map(
                (m) => `
                  <tr>
                    <td>${m.month}</td>
                    <td>${fmt(m.income)}</td>
                    <td>${fmt(m.expenses)}</td>
                    <td>${fmt(m.debtPayment)}</td>
                    <td class="good">${fmt(m.savingsContribution)}</td>
                    <td class="${m.debtRemaining > 0 ? 'bad' : 'good'}">${fmt(m.debtRemaining)}</td>
                    <td class="good">${fmt(m.debtChange)}</td>
                    <td class="${m.cashChange >= 0 ? 'good' : 'bad'}">${fmt(m.cashChange)}</td>
                    <td class="blue">${fmt(m.endingCash)}</td>
                    <td class="good">${fmt(m.cumulativeSavings)}</td>
                    <td>${m.debtProgress.toFixed(1)}%</td>
                  </tr>
                `
              )
              .join("")}
          </tbody>

        </table>
      </div>

    </div>
  `;

  // Initialize charts
  initSpendingMixChart(chartData.spendingMix);
  initDebtReductionChart(chartData.debtReduction);
  initCashFlowChart(chartData.cashFlow);

  $("#show-plan-btn")?.addEventListener("click", () => {
    setPage("plan");
  });

  document.querySelectorAll("[data-quick-action]").forEach((button) => {
    button.addEventListener("click", () => openForm(button.dataset.quickAction));
  });

  state.comparison = data.comparison;
  renderPeriodComparison(state.comparisonMode);
  document.querySelectorAll("[data-comparison-mode]").forEach((button) => {
    button.addEventListener("click", () => renderPeriodComparison(button.dataset.comparisonMode));
  });

  initSankeyWidget();
}

function sankeyWidgetPanel({ interactive = true, section = null } = {}) {
  const params = new URLSearchParams();
  if (!interactive) params.set("sliders", "0");
  if (section) params.set("section", section);
  const query = params.toString();
  const src = `/cashflow-sankey.html${query ? `?${query}` : ""}`;
  return `
    <div class="panel">

      <div class="panel-head">
        <h2>تدفق الأموال (Sankey)</h2>
      </div>

      <iframe
        id="sankeyWidgetFrame"
        src="${src}"
        style="width:100%;border:0;display:block;"
        title="Cashflow Sankey Widget"
      ></iframe>

    </div>
  `;
}

function initSankeyWidget() {
  const frame = document.getElementById("sankeyWidgetFrame");
  if (!frame || frame.dataset.resizeBound) return;
  frame.dataset.resizeBound = "1";
  frame.style.height = "600px";
  window.addEventListener("message", (event) => {
    if (event.data?.type === "widget-resize" && event.source === frame.contentWindow) {
      frame.style.height = `${event.data.height}px`;
    }
  });
}

/* =========================
   Chart Functions
========================= */

function initSpendingMixChart(data) {
  const ctx = document.getElementById('spendingMixChart');
  if (!ctx) return;

  new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: data.map(d => d.label),
      datasets: [{
        data: data.map(d => d.value),
        backgroundColor: data.map(d => d.color),
        borderWidth: 0
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: true,
      plugins: {
        legend: {
          position: 'bottom',
          rtl: true,
          labels: {
            font: {
              family: "'Cairo', sans-serif"
            }
          }
        },
        tooltip: {
          callbacks: {
            label: function(context) {
              const value = context.raw;
              const total = context.dataset.data.reduce((a, b) => a + b, 0);
              const percentage = ((value / total) * 100).toFixed(1);
              const formattedValue = new Intl.NumberFormat("en-US", {
                style: "currency",
                currency: "EUR",
                maximumFractionDigits: 2,
              }).format(value);
              return `${context.label}: ${formattedValue} (${percentage}%)`;
            }
          }
        }
      }
    }
  });
}

function initDebtReductionChart(data) {
  const ctx = document.getElementById('debtReductionChart');
  if (!ctx) return;

  new Chart(ctx, {
    type: 'line',
    data: {
      labels: data.map(d => d.month.slice(5)), // Show only month part
      datasets: [{
        label: 'الديون المتبقية',
        data: data.map(d => d.remaining),
        borderColor: '#ef4444',
        backgroundColor: 'rgba(239, 68, 68, 0.1)',
        fill: true,
        tension: 0.4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: true,
      plugins: {
        legend: {
          display: false
        },
        tooltip: {
          callbacks: {
            label: function(context) {
              return `المتبقي: ${fmt(context.raw)}`;
            }
          }
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            callback: function(value) {
              return fmt(value);
            }
          }
        }
      }
    }
  });
}

function initCashFlowChart(data) {
  const ctx = document.getElementById('cashFlowChart');
  if (!ctx) return;

  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: data.map(d => d.month.slice(5)),
      datasets: [
        {
          label: 'الدخل',
          data: data.map(d => d.income),
          backgroundColor: '#10b981'
        },
        {
          label: 'المصاريف',
          data: data.map(d => d.expenses),
          backgroundColor: '#ef4444'
        },
        {
          label: 'سداد الديون',
          data: data.map(d => d.debtPayment),
          backgroundColor: '#f59e0b'
        },
        {
          label: 'مساهمة الادخار',
          data: data.map(d => d.savingsContribution),
          backgroundColor: '#8b5cf6'
        },
        {
          label: 'الصافي',
          data: data.map(d => d.cashAfter),
          backgroundColor: '#3b82f6'
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: true,
      plugins: {
        legend: {
          position: 'top',
          rtl: true,
          labels: {
            font: {
              family: "'Cairo', sans-serif"
            }
          }
        },
        tooltip: {
          callbacks: {
            label: function(context) {
              return `${context.dataset.label}: ${fmt(context.raw)}`;
            }
          }
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            callback: function(value) {
              return fmt(value);
            }
          }
        }
      }
    }
  });
}

/* =========================
   Config
========================= */

const configs = {
  income: {
    title: "مصادر الدخل",
    button: "إضافة مصدر دخل",

    fields: [
      ["name", "اسم المصدر", "text", true],
      ["amount", "المبلغ الشهري", "number", true],
      ["type", "النوع", "select", true],
      ["payday", "يوم الاستلام", "number", false],
    ],
  },

  expenses: {
    title: "المصاريف",
    button: "إضافة مصروف",

    fields: [
      ["name", "اسم المصروف", "text", true],
      ["amount", "المبلغ الشهري", "number", true],
      ["category", "التصنيف", "text", true],
      ["due_day", "يوم الاستحقاق", "number", false],
    ],
  },

  transactions: {
    title: "سجل المعاملات",
    button: "إضافة معاملة",
    fields: [
      ["transaction_date", "تاريخ المعاملة", "date", true],
      ["merchant", "التاجر / الوصف", "text", true],
      ["amount", "المبلغ", "number", true],
      ["direction", "النوع", "select", true, [["expense", "مصروف"], ["income", "دخل"]]],
      ["category", "التصنيف", "text", false],
      ["account", "الحساب", "text", false],
      ["notes", "ملاحظات", "text", false],
    ],
  },

  subscriptions: {
    title: "الاشتراكات",
    button: "إضافة اشتراك",
    fields: [
      ["name", "اسم الخدمة", "text", true],
      ["amount", "المبلغ", "number", true],
      ["cadence", "التكرار", "select", true, [["monthly", "شهري"], ["yearly", "سنوي"]]],
      ["next_charge_date", "تاريخ الخصم القادم", "date", false],
      ["trial_ends_on", "انتهاء التجربة", "date", false],
      ["category", "التصنيف", "text", false],
      ["active", "الحالة", "select", true, [["1", "نشط"], ["0", "متوقف"]]],
    ],
  },

  debts: {
    title: "الديون",
    button: "إضافة دين",

    fields: [
      ["name", "اسم الدائن / الدين", "text", true],
      ["balance", "الرصيد الحالي", "number", true],
      ["apr", "الفائدة السنوية %", "number", false],
      ["minimum_payment", "الحد الأدنى للقسط", "number", false],
      ["due_day", "يوم الاستحقاق", "number", false],
      ["priority", "الأولوية", "number", false],
    ],
  },

  savings: {
    title: "المدخرات",
    button: "إضافة هدف ادخار",

    fields: [
      ["name", "اسم الهدف / الحساب", "text", true],
      ["amount", "المبلغ المدخر حاليًا", "number", true],
      ["target_amount", "المبلغ المستهدف", "number", false],
      ["monthly_contribution", "المساهمة الشهرية", "number", false],
      ["category", "التصنيف", "text", false],
    ],
  },

  "admin-tasks": {
    title: "المهام والمواعيد",
    button: "إضافة مهمة",
    fields: [
      ["title", "عنوان المهمة", "text", true],
      ["category", "التصنيف", "text", false],
      ["due_date", "تاريخ الاستحقاق", "date", false],
      ["notes", "ملاحظات", "text", false],
      ["status", "الحالة", "select", true, [["open", "مفتوحة"], ["done", "مكتملة"]]],
    ],
  },

  documents: {
    title: "الوثائق والإيصالات",
    button: "إضافة وثيقة",
    fields: [
      ["title", "اسم الوثيقة", "text", true],
      ["document_type", "النوع", "select", true, [["Receipt", "إيصال"], ["Warranty", "ضمان"], ["Insurance", "تأمين"], ["Tax", "ضريبة"], ["Other", "أخرى"]]],
      ["expiry_date", "تاريخ الانتهاء / التجديد", "date", false],
      ["notes", "ملاحظات أو مكان الحفظ", "text", false],
    ],
  },
};

/* =========================
   Lists
========================= */

async function listPage(type) {
  const endpoint = type === "transactions" && state.transactionQuery
    ? `/api/transactions?q=${encodeURIComponent(state.transactionQuery)}`
    : `/api/${type}`;
  const rows = await api(endpoint);
  const config = configs[type];

  const columns = {
    income: ["name", "amount", "type", "payday"],
    expenses: ["name", "amount", "category", "due_day"],
    debts: [
      "name",
      "balance",
      "apr",
      "minimum_payment",
      "due_day",
      "priority",
    ],
    savings: [
      "name",
      "amount",
      "target_amount",
      "monthly_contribution",
      "category",
    ],
    transactions: ["transaction_date", "merchant", "amount", "direction", "category", "account"],
    subscriptions: ["name", "amount", "cadence", "next_charge_date", "trial_ends_on", "category", "active"],
    "admin-tasks": ["title", "category", "due_date", "status"],
    documents: ["title", "document_type", "expiry_date", "notes"],
  }[type];

  const heads = {
    name: "الاسم",
    amount: "المبلغ",
    balance: "الرصيد",
    type: "النوع",
    category: "التصنيف",
    payday: "يوم الاستلام",
    due_day: "الاستحقاق",
    apr: "الفائدة %",
    minimum_payment: "الحد الأدنى",
    priority: "الأولوية",
    target_amount: "المستهدف",
    monthly_contribution: "المساهمة الشهرية",
    transaction_date: "التاريخ",
    merchant: "التاجر / الوصف",
    direction: "النوع",
    account: "الحساب",
    cadence: "التكرار",
    next_charge_date: "الخصم القادم",
    trial_ends_on: "انتهاء التجربة",
    active: "الحالة",
    title: "المهمة",
    due_date: "الاستحقاق",
    status: "الحالة",
    document_type: "النوع",
    expiry_date: "الانتهاء / التجديد",
    notes: "ملاحظات",
  };

  $("#content").innerHTML = `
    ${sankeyWidgetPanel({ interactive: false, section: type })}

    <div class="panel">

      <div class="panel-head">

        <h2>${config.title}</h2>

        <div class="panel-controls">
          ${type === "transactions" ? `<button class="btn secondary" id="import-statement-btn">استيراد كشف</button><button class="btn secondary" id="export-transactions-btn">تصدير CSV</button>` : ""}
          <button class="btn" id="add-item-btn">+ ${config.button}</button>
        </div>

      </div>

      ${type === "transactions" ? `<input id="statement-file" class="hidden" type="file" accept=".csv,.xlsx,.xls,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet">` : ""}

      ${type === "transactions" ? `
        <div class="ledger-filters">
          <input id="transaction-search" type="search" value="${esc(state.transactionQuery)}" placeholder="ابحث باسم التاجر أو التصنيف أو الملاحظات">
          <span class="label">${rows.length} معاملة</span>
        </div>` : ""}

      ${
        rows.length
          ? `
            <table>

              <thead>
                <tr>
                  ${columns
                    .map((column) => `<th>${heads[column]}</th>`)
                    .join("")}

                  <th>إجراءات</th>
                </tr>
              </thead>

              <tbody>

                ${rows
                  .map(
                    (row) => `
                    <tr>

                      ${columns
                        .map((column) => {
                          let value = row[column];

                          if (
                            column === "amount" ||
                            column === "balance" ||
                            column === "minimum_payment" ||
                            column === "target_amount" ||
                            column === "monthly_contribution"
                          ) {
                            value = fmt(value);
                          }

                          if (column === "direction") value = value === "income" ? "دخل" : "مصروف";
                          if (column === "cadence") value = value === "yearly" ? "سنوي" : "شهري";
                          if (column === "active") value = Number(value) ? "نشط" : "متوقف";
                          if (column === "status") value = value === "done" ? "مكتملة" : "مفتوحة";

                          if (column === "apr") {
                            value =
                              Number(value || 0).toFixed(2) + "%";
                          }

                          if (
                            type === "income" &&
                            column === "type"
                          ) {
                            value =
                              value === "variable"
                                ? "متغير"
                                : "ثابت";
                          }

                          return `<td>${esc(value ?? "—")}</td>`;
                        })
                        .join("")}

                      <td>

                        <div class="actions">

                          <button
                            class="icon-btn edit-btn"
                            data-id="${row.id}"
                          >
                            تعديل
                          </button>

                          <button
                            class="icon-btn delete-btn"
                            data-id="${row.id}"
                          >
                            حذف
                          </button>

                        </div>

                      </td>

                    </tr>
                  `
                  )
                  .join("")}

              </tbody>

            </table>
          `
          : `
            <div class="empty">
              لا توجد بيانات بعد.
              أضف أول عنصر من الزر أعلاه.
            </div>
          `
      }

    </div>
  `;

  /* Add */

  $("#add-item-btn").addEventListener("click", () => {
    openForm(type);
  });

  $("#transaction-search")?.addEventListener("input", (event) => {
    state.transactionQuery = event.target.value;
    clearTimeout(window.transactionSearchTimer);
    window.transactionSearchTimer = setTimeout(() => listPage("transactions"), 250);
  });

  $("#import-statement-btn")?.addEventListener("click", () => $("#statement-file")?.click());
  $("#statement-file")?.addEventListener("change", async (event) => {
    const [file] = event.target.files || [];
    if (!file) return;
    await importStatement(file);
    event.target.value = "";
  });
  $("#export-transactions-btn")?.addEventListener("click", () => exportTransactions(rows));

  /* Edit */

  document.querySelectorAll(".edit-btn").forEach((button) => {
    button.addEventListener("click", () => {
      const id = Number(button.dataset.id);

      const row = rows.find(
        (item) => Number(item.id) === id
      );

      if (row) {
        openForm(type, row);
      }
    });
  });

  /* Delete */

  document.querySelectorAll(".delete-btn").forEach((button) => {
    button.addEventListener("click", async () => {
      const id = Number(button.dataset.id);

      await removeRow(type, id);
    });
  });

  initSankeyWidget();
}

function csvCell(value) {
  const text = String(value ?? "");
  return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function exportTransactions(rows) {
  const headers = ["transaction_date", "merchant", "amount", "direction", "category", "account", "notes"];
  const csv = [headers.join(","), ...rows.map((row) => headers.map((key) => csvCell(row[key])).join(","))].join("\n");
  const url = URL.createObjectURL(new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = `money-manager-transactions-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

async function importStatement(file) {
  const button = $("#import-statement-btn");
  const supported = /\.(csv|xlsx|xls)$/i.test(file.name);
  if (!supported) {
    alert("اختر ملف CSV أو XLSX فقط.");
    return;
  }
  try {
    button.disabled = true;
    button.textContent = "جارٍ الاستيراد...";
    const response = await fetch("/api/transactions/import-file", {
      method: "POST",
      headers: { "Content-Type": file.type || (file.name.toLowerCase().endsWith(".csv") ? "text/csv" : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") },
      body: await file.arrayBuffer(),
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(payload.error || "تعذر استيراد الملف.");
    state.transactionQuery = "";
    await listPage("transactions");
    alert(`تم استيراد ${payload.imported} معاملة بنجاح.`);
  } catch (error) {
    alert(error.message || "تعذر استيراد الملف.");
  } finally {
    if (button) {
      button.disabled = false;
      button.textContent = "استيراد كشف";
    }
  }
}

/* =========================
   Modal
========================= */

function openForm(type, row = {}) {
  const config = configs[type];
  const editing = Boolean(row.id);

  $("#modal-title").textContent =
    (editing ? "تعديل " : "إضافة ") +
    config.title.replace("مصادر ", "").replace("ال", "");

  $("#modal-body").innerHTML = `
    <form id="data-form" class="form-grid">

      ${config.fields
        .map(([key, label, inputType, required, options]) => {

          if (inputType === "select") {
            const selectOptions = options || [["fixed", "ثابت"], ["variable", "متغير"]];
            const selectedValue = String(row[key] ?? selectOptions[0][0]);

            return `
              <div class="field">

                <label>${label}</label>

              <select name="${key}">
                ${selectOptions.map(([value, text]) => `<option value="${esc(value)}" ${String(value) === selectedValue ? "selected" : ""}>${esc(text)}</option>`).join("")}

              </select>

              </div>
            `;
          }

          return `
            <div class="field">

              <label>${label}</label>

              <input
                name="${key}"
                type="${inputType}"
                step="0.01"
                value="${esc(row[key] ?? "")}"
                ${required ? "required" : ""}
              />

            </div>
          `;
        })
        .join("")}

    </form>

    <div
      id="form-error"
      class="notice bad hidden"
    ></div>

    <div class="form-actions">

      <button
        class="btn"
        id="save-btn"
        type="button"
      >
        حفظ
      </button>

      <button
        class="btn secondary"
        id="cancel-btn"
        type="button"
      >
        إلغاء
      </button>

    </div>
  `;

  $("#modal").classList.remove("hidden");

  $("#cancel-btn").addEventListener(
    "click",
    closeModal
  );

  $("#save-btn").addEventListener(
    "click",
    () => saveForm(type, row)
  );

  $("#data-form").addEventListener(
    "submit",
    (event) => {
      event.preventDefault();
      saveForm(type, row);
    }
  );
}

/* =========================
   Save
========================= */

async function saveForm(type, row = {}) {
  const form = $("#data-form");
  const saveButton = $("#save-btn");
  const errorBox = $("#form-error");

  if (!form) {
    console.error("Form not found");
    return;
  }

  errorBox.classList.add("hidden");

  const formData = new FormData(form);
  const data = Object.fromEntries(formData.entries());

  const numericFields = [
    "amount",
    "balance",
    "apr",
    "minimum_payment",
    "payday",
    "due_day",
    "priority",
    "target_amount",
    "monthly_contribution",
    "active",
  ];

  numericFields.forEach((field) => {
    if (field in data) {
      data[field] =
        data[field] === ""
          ? 0
          : Number(data[field]);
    }
  });

  /* Validation */

  if (!data.name?.trim()) {
    errorBox.textContent = "من فضلك أدخل الاسم.";
    errorBox.classList.remove("hidden");
    return;
  }

  if (
    ("amount" in data && data.amount < 0) ||
    ("balance" in data && data.balance < 0) ||
    ("minimum_payment" in data && data.minimum_payment < 0)
  ) {
    errorBox.textContent =
      "المبلغ لا يمكن أن يكون بالسالب.";
    errorBox.classList.remove("hidden");
    return;
  }

  try {
    saveButton.disabled = true;
    saveButton.textContent = "جاري الحفظ...";

    const url = row.id
      ? `/api/${type}/${row.id}`
      : `/api/${type}`;

    const method = row.id ? "PUT" : "POST";

    console.log("Saving:", {
      url,
      method,
      data,
    });

    await api(url, {
      method,
      body: JSON.stringify(data),
    });

    closeModal();

    await render();

  } catch (error) {
    console.error("Save failed:", error);

    errorBox.textContent =
      error.message || "تعذر حفظ البيانات.";

    errorBox.classList.remove("hidden");

    saveButton.disabled = false;
    saveButton.textContent = "حفظ";
  }
}

/* =========================
   Delete
========================= */

async function removeRow(type, id) {
  if (!confirm("هل أنت متأكد من حذف هذا العنصر؟")) {
    return;
  }

  try {
    await api(`/api/${type}/${id}`, {
      method: "DELETE",
    });

    await render();

  } catch (error) {
    alert(error.message);
  }
}

/* =========================
   Modal Close
========================= */

function closeModal() {
  $("#modal").classList.add("hidden");
}

/* =========================
   Debt Plan
========================= */

async function planPage() {
  const plan = await api("/api/plan");
  const settings = await api("/api/settings");

  const columns = [
    "month",
    ...Object.keys(plan.months[0]?.payments || {}),
    "totalPayment",
    "remainingDebt",
  ];

  $("#content").innerHTML = `
    ${sankeyWidgetPanel({ interactive: false })}

    <div class="panel">

      <div class="panel-head">

        <h2>إعدادات الخطة</h2>

        <button
          class="btn"
          id="save-plan-btn"
        >
          حفظ وإعادة الحساب
        </button>

      </div>

      <div class="form-grid">

        <div class="field">

          <label>
            مدة التخلص من الديون (بالشهور)
          </label>

          <input
            id="targetMonths"
            type="number"
            min="1"
            value="${settings.targetMonths || 16}"
          />

        </div>

        <div class="field">

          <label>
            تاريخ بداية الخطة
          </label>

          <input
            id="startDate"
            type="date"
            value="${settings.startDate || "2026-09-01"}"
          />

        </div>

      </div>

      <div class="notice ${plan.feasible ? "good" : "bad"}">

        ${
          plan.feasible
            ? `الخطة قابلة للتنفيذ.
               تحتاج إلى ${fmt(plan.requiredMonthly)}
               شهريًا من أصل ${fmt(plan.available)} متاح.`
            : `الخطة غير قابلة للتنفيذ خلال
               ${plan.targetMonths} شهرًا.
               المطلوب ${fmt(plan.requiredMonthly)}
               بينما المتاح ${fmt(plan.available)}.
               جرّب مدة أطول أو خفض المصاريف/زيادة الدخل.`
        }

      </div>

    </div>

    <div class="panel">

      <div class="panel-head">

        <h2>الملخص</h2>

        <span class="badge">
          Avalanche
        </span>

      </div>

      <div class="grid cards">

        <div class="card">
          <div class="label">إجمالي الدين</div>
          <div class="value bad">
            ${fmt(plan.totalDebt)}
          </div>
        </div>

        <div class="card">
          <div class="label">الدفع الشهري المطلوب</div>
          <div class="value">
            ${fmt(plan.requiredMonthly)}
          </div>
        </div>

        <div class="card">
          <div class="label">المتاح</div>
          <div class="value good">
            ${fmt(plan.available)}
          </div>
        </div>

        <div class="card">
          <div class="label">المتبقي بنهاية الخطة</div>
          <div class="value">
            ${fmt(plan.projectedRemaining)}
          </div>
        </div>

      </div>

    </div>

    <div class="panel">

      <div class="panel-head">
        <h2>الجدول الشهري</h2>
      </div>

      ${
        plan.months.length
          ? `
            <table>

              <thead>
                <tr>
                  ${columns
                    .map((column) => `
                      <th>
                        ${
                          column === "month"
                            ? "الشهر"
                            : column === "totalPayment"
                            ? "إجمالي السداد"
                            : column === "remainingDebt"
                            ? "الرصيد المتبقي"
                            : esc(column)
                        }
                      </th>
                    `)
                    .join("")}
                </tr>
              </thead>

              <tbody>

                ${plan.months
                  .map(
                    (month) => `
                      <tr>

                        ${columns
                          .map((column) => `
                            <td>
                              ${
                                column === "month"
                                  ? month.month
                                  : column === "totalPayment" ||
                                    column === "remainingDebt"
                                  ? fmt(month[column])
                                  : fmt(
                                      month.payments[column]
                                    )
                              }
                            </td>
                          `)
                          .join("")}

                      </tr>
                    `
                  )
                  .join("")}

              </tbody>

            </table>
          `
          : `
            <div class="empty">
              أضف ديونًا أولًا.
            </div>
          `
      }

    </div>
  `;

  $("#save-plan-btn").addEventListener(
    "click",
    savePlanSettings
  );

  initSankeyWidget();
}

/* =========================
   Plan Settings
========================= */

async function savePlanSettings() {
  try {
    await api("/api/settings", {
      method: "PUT",

      body: JSON.stringify({
        targetMonths: Number($("#targetMonths").value),
        startDate: $("#startDate").value,
      }),
    });

    await render();

  } catch (error) {
    alert(error.message);
  }
}

/* =========================
   Start
========================= */

setPage("dashboard");
