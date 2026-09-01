const state = { page: "dashboard" };

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
  debts: ["الديون", "سجل الأرصدة والفوائد والأقساط"],
  savings: ["المدخرات", "تابع أهدافك الادخارية ومساهماتك الشهرية"],
  plan: ["خطة سداد الديون", "خطة شهرية تلقائية حسب المدة والقدرة المالية"],
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
    if (state.page === "debts") await listPage("debts");
    if (state.page === "savings") await listPage("savings");
    if (state.page === "plan") await planPage();
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
    <div class="grid cards">

      <div class="card">
        <div class="label">إجمالي الدخل الشهري</div>
        <div class="value blue">${fmt(data.income)}</div>
      </div>

      <div class="card">
        <div class="label">إجمالي المصاريف</div>
        <div class="value">${fmt(data.expenses)}</div>
        <div class="label">${(data.debtRatio * 100).toFixed(1)}% من الدخل</div>
      </div>

      <div class="card">
        <div class="label">المتاح قبل الديون</div>
        <div class="value ${data.available >= 0 ? "good" : "bad"}">
          ${fmt(data.available)}
        </div>
      </div>

      <div class="card">
        <div class="label">إجمالي الديون</div>
        <div class="value bad">${fmt(data.totalDebt)}</div>
      </div>

      <div class="card">
        <div class="label">إجمالي المدخرات</div>
        <div class="value good">${fmt(data.totalSavings)}</div>
        ${
          data.savingsTarget
            ? `<div class="label">${((data.totalSavings / data.savingsTarget) * 100).toFixed(1)}% من الهدف</div>`
            : ""
        }
      </div>

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
              <th>الديون المتبقية</th>
              <th>تخفيض الديون</th>
              <th>التدفق النقدي</th>
              <th>الرصيد التراكمي</th>
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
                    <td class="${m.debtRemaining > 0 ? 'bad' : 'good'}">${fmt(m.debtRemaining)}</td>
                    <td class="good">${fmt(m.debtChange)}</td>
                    <td class="${m.cashChange >= 0 ? 'good' : 'bad'}">${fmt(m.cashChange)}</td>
                    <td class="blue">${fmt(m.endingCash)}</td>
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
};

/* =========================
   Lists
========================= */

async function listPage(type) {
  const rows = await api(`/api/${type}`);
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
  };

  $("#content").innerHTML = `
    <div class="panel">

      <div class="panel-head">

        <h2>${config.title}</h2>

        <button class="btn" id="add-item-btn">
          + ${config.button}
        </button>

      </div>

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
        .map(([key, label, inputType, required]) => {

          if (inputType === "select") {
            const fixedSelected =
              row[key] !== "variable" ? "selected" : "";

            const variableSelected =
              row[key] === "variable" ? "selected" : "";

            return `
              <div class="field">

                <label>${label}</label>

                <select name="${key}">

                  <option
                    value="fixed"
                    ${fixedSelected}
                  >
                    ثابت
                  </option>

                  <option
                    value="variable"
                    ${variableSelected}
                  >
                    متغير
                  </option>

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
    ("balance" in data && data.balance < 0)
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