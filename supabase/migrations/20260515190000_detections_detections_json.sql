-- Bounding boxes / labels for each detection row (same JSON shape as captured_photo.detections_json).
alter table public.detections
add column if not exists detections_json jsonb;
