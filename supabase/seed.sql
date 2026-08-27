-- Minimal plan-agnostic nutrition seed data. Values are per 100 g unless serving says otherwise.

insert into public.food_sources (id, code, name, priority, is_active)
values
  ('11111111-1111-1111-1111-111111111111', 'usda', 'USDA FoodData Central', 100, true),
  ('22222222-2222-2222-2222-222222222222', 'openfoodfacts', 'Open Food Facts', 80, true),
  ('33333333-3333-3333-3333-333333333333', 'verified_internal', 'Veralify Verified Internal', 90, true),
  ('44444444-4444-4444-4444-444444444444', 'user_submitted', 'User Submitted', 20, true),
  ('55555555-5555-5555-5555-555555555555', 'ai_estimated', 'AI Estimated', 10, true)
on conflict (code) do update set name = excluded.name, priority = excluded.priority, is_active = excluded.is_active;

insert into public.foods (id, source, external_id, name, brand, serving_size, serving_unit, calories, protein_g, carbs_g, fat_g, fiber_g, sugar_g, sodium_mg, metadata)
values
  ('aaaaaaaa-0001-0000-0000-000000000001', 'usda', 'fdc-chicken-breast-cooked-100g', 'Chicken breast, cooked, roasted, skinless', null, 100, 'g', 165, 31.02, 0, 3.57, 0, 0, 74, '{"basis":"per_100g"}'),
  ('aaaaaaaa-0002-0000-0000-000000000002', 'usda', 'fdc-white-rice-cooked-100g', 'White rice, cooked, long-grain', null, 100, 'g', 130, 2.69, 28.17, 0.28, 0.4, 0.05, 1, '{"basis":"per_100g"}'),
  ('aaaaaaaa-0003-0000-0000-000000000003', 'usda', 'fdc-banana-raw-100g', 'Banana, raw', null, 100, 'g', 89, 1.09, 22.84, 0.33, 2.6, 12.23, 1, '{"basis":"per_100g"}'),
  ('aaaaaaaa-0004-0000-0000-000000000004', 'usda', 'fdc-egg-whole-cooked-100g', 'Egg, whole, cooked, hard-boiled', null, 100, 'g', 155, 12.58, 1.12, 10.61, 0, 1.12, 124, '{"basis":"per_100g"}'),
  ('aaaaaaaa-0005-0000-0000-000000000005', 'usda', 'fdc-oats-rolled-dry-100g', 'Oats, rolled, dry', null, 100, 'g', 379, 13.15, 67.7, 6.52, 10.1, 0.99, 6, '{"basis":"per_100g"}'),
  ('aaaaaaaa-0006-0000-0000-000000000006', 'usda', 'fdc-salmon-atlantic-cooked-100g', 'Salmon, Atlantic, cooked', null, 100, 'g', 206, 22.1, 0, 12.35, 0, 0, 61, '{"basis":"per_100g"}'),
  ('aaaaaaaa-0007-0000-0000-000000000007', 'usda', 'fdc-broccoli-cooked-100g', 'Broccoli, cooked, boiled, drained', null, 100, 'g', 35, 2.38, 7.18, 0.41, 3.3, 1.39, 41, '{"basis":"per_100g"}'),
  ('aaaaaaaa-0008-0000-0000-000000000008', 'usda', 'fdc-greek-yogurt-plain-nonfat-100g', 'Greek yogurt, plain, nonfat', null, 100, 'g', 59, 10.19, 3.6, 0.39, 0, 3.24, 36, '{"basis":"per_100g"}'),
  ('aaaaaaaa-0009-0000-0000-000000000009', 'usda', 'fdc-almonds-raw-100g', 'Almonds, raw', null, 100, 'g', 579, 21.15, 21.55, 49.93, 12.5, 4.35, 1, '{"basis":"per_100g"}'),
  ('aaaaaaaa-0010-0000-0000-000000000010', 'usda', 'fdc-sweet-potato-baked-100g', 'Sweet potato, baked in skin', null, 100, 'g', 90, 2.01, 20.71, 0.15, 3.3, 6.48, 36, '{"basis":"per_100g"}')
on conflict (source, external_id) do update set
  name = excluded.name,
  serving_size = excluded.serving_size,
  serving_unit = excluded.serving_unit,
  calories = excluded.calories,
  protein_g = excluded.protein_g,
  carbs_g = excluded.carbs_g,
  fat_g = excluded.fat_g,
  fiber_g = excluded.fiber_g,
  sugar_g = excluded.sugar_g,
  sodium_mg = excluded.sodium_mg,
  metadata = excluded.metadata;

insert into public.food_nutrition_versions (food_id, version, nutrition, change_reason)
select f.id, 1,
       jsonb_build_object(
         'serving_size', f.serving_size,
         'serving_unit', f.serving_unit,
         'calories', f.calories,
         'protein_g', f.protein_g,
         'carbs_g', f.carbs_g,
         'fat_g', f.fat_g,
         'fiber_g', f.fiber_g,
         'sugar_g', f.sugar_g,
         'sodium_mg', f.sodium_mg,
         'source', f.source,
         'external_id', f.external_id
       ),
       'provider_sync'
from public.foods f
where f.source = 'usda'
on conflict (food_id, version) do update set nutrition = excluded.nutrition;

insert into public.food_external_mappings (food_id, food_source_id, external_id, last_synced_at)
select f.id, fs.id, f.external_id, now()
from public.foods f
join public.food_sources fs on fs.code = f.source
where f.source = 'usda'
on conflict (food_source_id, external_id) do update set food_id = excluded.food_id, last_synced_at = excluded.last_synced_at;

insert into public.food_servings (food_id, label, grams)
values
  ('aaaaaaaa-0001-0000-0000-000000000001', '100 g', 100),
  ('aaaaaaaa-0001-0000-0000-000000000001', '1 cup chopped (140 g)', 140),
  ('aaaaaaaa-0002-0000-0000-000000000002', '100 g', 100),
  ('aaaaaaaa-0002-0000-0000-000000000002', '1 cup cooked (158 g)', 158),
  ('aaaaaaaa-0003-0000-0000-000000000003', '100 g', 100),
  ('aaaaaaaa-0003-0000-0000-000000000003', '1 medium banana (118 g)', 118),
  ('aaaaaaaa-0004-0000-0000-000000000004', '100 g', 100),
  ('aaaaaaaa-0004-0000-0000-000000000004', '1 large egg (50 g)', 50),
  ('aaaaaaaa-0005-0000-0000-000000000005', '100 g', 100),
  ('aaaaaaaa-0005-0000-0000-000000000005', '1/2 cup dry (40 g)', 40),
  ('aaaaaaaa-0006-0000-0000-000000000006', '100 g', 100),
  ('aaaaaaaa-0006-0000-0000-000000000006', '1 fillet (154 g)', 154),
  ('aaaaaaaa-0007-0000-0000-000000000007', '100 g', 100),
  ('aaaaaaaa-0007-0000-0000-000000000007', '1 cup chopped (156 g)', 156),
  ('aaaaaaaa-0008-0000-0000-000000000008', '100 g', 100),
  ('aaaaaaaa-0008-0000-0000-000000000008', '3/4 cup (170 g)', 170),
  ('aaaaaaaa-0009-0000-0000-000000000009', '100 g', 100),
  ('aaaaaaaa-0009-0000-0000-000000000009', '1 oz (28 g)', 28),
  ('aaaaaaaa-0010-0000-0000-000000000010', '100 g', 100),
  ('aaaaaaaa-0010-0000-0000-000000000010', '1 medium (114 g)', 114)
on conflict (food_id, label) do update set grams = excluded.grams;
