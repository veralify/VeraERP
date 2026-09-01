# Money Manager — Web App MVP

نسخة أولى كاملة من تطبيق إدارة مالية شخصية، مبنية على فكرة ملف `Manage My Money v3.xlsx`.

## المزايا

- Dashboard تفاعلي.
- إدارة مصادر الدخل.
- إدارة المصاريف الشهرية.
- إدارة الديون.
- Debt Plan تلقائي بطريقة Avalanche.
- تحديد مدة التخلص من الديون.
- اختبار قابلية الخطة للتنفيذ مقارنة بالدخل والمصاريف.
- قاعدة بيانات SQLite محلية.
- واجهة عربية RTL ومتجاوبة مع الهاتف.
- بيانات أولية مأخوذة من أمثلة الملف الأصلي.

## التشغيل

يتطلب Node.js 18+.

```bash
npm install
npm start
```

ثم افتح:

http://localhost:3000

للتطوير:

```bash
npm run dev
```

قاعدة البيانات تنشأ تلقائيًا باسم `money-manager.db`.

## منطق Debt Plan

1. يحسب الدخل الشهري الفعال.
2. يطرح المصاريف الفعالة.
3. يحسب الحد الأدنى للأقساط.
4. يبحث عن أقل ميزانية شهرية تحقق التخلص من كل الديون خلال المدة المحددة.
5. يوزع الحد الأدنى أولًا، ثم يوجه المبلغ الإضافي إلى الدين الأعلى فائدة، مع استخدام الأولوية ككاسر تعادل.
6. إذا تجاوزت الميزانية المطلوبة المبلغ المتاح، يعرض التطبيق أن الخطة غير قابلة للتنفيذ.

## الخطوات المقترحة بعد الـ MVP

- تسجيل الدخول والمستخدمون.
- PostgreSQL/Supabase بدل SQLite عند النشر.
- معاملات فعلية ومصاريف متغيرة.
- Cash Flow شهري.
- إشعارات الاستحقاقات.
- تقارير PDF/Excel.
- Multiple currencies.
- سيناريوهات ومقارنة Snowball vs Avalanche.


## Troubleshooting

Use this v1.1 package as a clean replacement for the previous ZIP.

```bash
rm -rf node_modules
npm install
npm start
```

Do not update npm just to run this project.
