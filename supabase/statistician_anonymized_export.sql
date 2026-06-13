-- Anonymized export for an external statistician.
--
-- HOW TO USE
-- 1) In EACH query below, replace REPLACE_WITH_PRIVATE_RANDOM_SALT with the
--    same private random string that only you keep.
-- 2) Run one SELECT at a time in Supabase SQL Editor.
-- 3) Download the result grid as CSV.
--
-- IMPORTANT
-- - The CSVs produced by Queries 1-3 are safe to share more broadly.
-- - Query 4 is PRIVATE ONLY and should never be sent to the statistician
--   because it includes the original image URL/path so you can rename files.

-- ---------------------------------------------------------------------------
-- Query 1: detections_joined_anon.csv
-- Detection-level anonymized export.
-- ---------------------------------------------------------------------------
with params as (
  select 'REPLACE_WITH_PRIVATE_RANDOM_SALT'::text as salt
)
select
  'DET-' || upper(substr(md5(params.salt || ':det:' || d.id::text), 1, 12))
    as detection_code,
  'PID-' || upper(substr(md5(params.salt || ':user:' || d.user_id::text), 1, 10))
    as participant_id,
  case
    when d.field_id is null then null
    else 'FIELD-' || upper(substr(md5(params.salt || ':field:' || d.field_id::text), 1, 10))
  end as field_code,
  d.created_at::date as captured_date,
  date_trunc('month', d.created_at)::date as captured_month,
  (d.field_id is not null) as has_field,
  (d.image_url is not null and btrim(d.image_url) <> '') as has_image,
  case
    when d.image_url is null or btrim(d.image_url) = '' then null
    else
      'IMG-' || upper(substr(md5(params.salt || ':img:' || d.id::text), 1, 12)) ||
      case
        when d.image_url ilike '%.png%' then '.png'
        when d.image_url ilike '%.webp%' then '.webp'
        when d.image_url ilike '%.jpeg%' then '.jpeg'
        else '.jpg'
      end
  end as exported_filename,
  case
    when d.confidence is null then null
    when d.confidence <= 1 then round((d.confidence * 100)::numeric, 2)
    else round(d.confidence::numeric, 2)
  end as confidence_pct,
  coalesce(d.count, 0) as mealybug_count,
  d.has_mealybugs,
  (d.latitude is not null and d.longitude is not null) as has_coordinates,
  case when d.latitude is null then null else round(d.latitude::numeric, 2) end
    as latitude_approx_2dp,
  case when d.longitude is null then null else round(d.longitude::numeric, 2) end
    as longitude_approx_2dp
from public.detections d
cross join params
order by captured_date, detection_code;

-- ---------------------------------------------------------------------------
-- Query 2: field_summary_anon.csv
-- Field-level anonymized summary.
-- ---------------------------------------------------------------------------
with params as (
  select 'REPLACE_WITH_PRIVATE_RANDOM_SALT'::text as salt
),
detection_summary as (
  select
    d.field_id,
    count(*)::int as detections_count,
    coalesce(sum(coalesce(d.count, 0)), 0)::int as total_mealybugs,
    avg(
      case
        when d.confidence is null then null
        when d.confidence <= 1 then d.confidence * 100
        else d.confidence
      end
    ) as avg_confidence_pct,
    min(d.created_at::date) as first_detection_date,
    max(d.created_at::date) as last_detection_date
  from public.detections d
  group by d.field_id
)
select
  'FIELD-' || upper(substr(md5(params.salt || ':field:' || f.id::text), 1, 10))
    as field_code,
  'PID-' || upper(substr(md5(params.salt || ':user:' || f.user_id::text), 1, 10))
    as participant_id,
  f.created_at::date as field_created_date,
  f.updated_at::date as field_updated_date,
  f.image_count as image_count_cached,
  (f.preview_image_path is not null and btrim(f.preview_image_path) <> '')
    as has_preview_image,
  coalesce(ds.detections_count, 0) as detections_count,
  coalesce(ds.total_mealybugs, 0) as total_mealybugs,
  round(ds.avg_confidence_pct::numeric, 2) as avg_confidence_pct,
  ds.first_detection_date,
  ds.last_detection_date
from public.fields f
cross join params
left join detection_summary ds on ds.field_id = f.id
order by field_code;

-- ---------------------------------------------------------------------------
-- Query 3: image_manifest_anon.csv
-- Public/statistician-facing image manifest with anonymized filenames only.
-- ---------------------------------------------------------------------------
with params as (
  select 'REPLACE_WITH_PRIVATE_RANDOM_SALT'::text as salt
)
select
  'DET-' || upper(substr(md5(params.salt || ':det:' || d.id::text), 1, 12))
    as detection_code,
  'PID-' || upper(substr(md5(params.salt || ':user:' || d.user_id::text), 1, 10))
    as participant_id,
  case
    when d.field_id is null then null
    else 'FIELD-' || upper(substr(md5(params.salt || ':field:' || d.field_id::text), 1, 10))
  end as field_code,
  d.created_at::date as captured_date,
  'IMG-' || upper(substr(md5(params.salt || ':img:' || d.id::text), 1, 12)) ||
    case
      when d.image_url ilike '%.png%' then '.png'
      when d.image_url ilike '%.webp%' then '.webp'
      when d.image_url ilike '%.jpeg%' then '.jpeg'
      else '.jpg'
    end as exported_filename,
  coalesce(d.count, 0) as mealybug_count,
  case
    when d.confidence is null then null
    when d.confidence <= 1 then round((d.confidence * 100)::numeric, 2)
    else round(d.confidence::numeric, 2)
  end as confidence_pct,
  d.has_mealybugs
from public.detections d
cross join params
where d.image_url is not null
  and btrim(d.image_url) <> ''
order by captured_date, detection_code;

-- ---------------------------------------------------------------------------
-- Query 4: image_rename_helper_private.csv
-- PRIVATE ONLY. Keep this to yourself to rename / match downloaded images.
-- Do NOT send this file because it contains original image references.
-- ---------------------------------------------------------------------------
with params as (
  select 'REPLACE_WITH_PRIVATE_RANDOM_SALT'::text as salt
)
select
  'IMG-' || upper(substr(md5(params.salt || ':img:' || d.id::text), 1, 12)) ||
    case
      when d.image_url ilike '%.png%' then '.png'
      when d.image_url ilike '%.webp%' then '.webp'
      when d.image_url ilike '%.jpeg%' then '.jpeg'
      else '.jpg'
    end as exported_filename,
  d.image_url as original_image_reference
from public.detections d
cross join params
where d.image_url is not null
  and btrim(d.image_url) <> ''
order by exported_filename;
