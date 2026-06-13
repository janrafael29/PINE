# Anonymized Statistician Export

Use `supabase/statistician_anonymized_export.sql` to create a safer handoff set
for an external statistician.

## Share these files

- `detections_joined_anon.csv`
- `field_summary_anon.csv`
- `image_manifest_anon.csv`
- `images/` only if image review is required
- this README (or a shortened version)

## Do not share

- raw table exports from `profiles`, `fields`, or `detections`
- raw UUIDs (`user_id`, `field_id`, detection ids)
- email addresses, phone numbers, display names
- exact addresses / field names
- `image_rename_helper_private.csv`
- original Supabase image URLs or storage paths

## Important privacy note

The CSV files created by the anonymized SQL use pseudonymous codes such as:

- `PID-...` for participants
- `FIELD-...` for fields
- `DET-...` for detections
- `IMG-...` for image filenames

These codes are generated from a private salt that **you must choose** and keep
secret. Use the **same salt** in all queries for one export package.

Images are only **pseudonymized**, not fully anonymized. The file names can be
safe, but the pixel content may still reveal:

- farms / field layouts
- roads / nearby houses
- workers / people
- timestamps or labels visible in the image itself

If strict anonymity is required, do **not** share images without separate
review, consent, or redaction.

## How to create the CSVs

1. Open Supabase `SQL Editor`.
2. Open `supabase/statistician_anonymized_export.sql`.
3. Replace `REPLACE_WITH_PRIVATE_RANDOM_SALT` with one private random string.
4. Run each query **one at a time**.
5. Download the result of each query as CSV.

Recommended file names:

- Query 1 -> `detections_joined_anon.csv`
- Query 2 -> `field_summary_anon.csv`
- Query 3 -> `image_manifest_anon.csv`
- Query 4 -> `image_rename_helper_private.csv` (**keep private**)

## How to prepare the images

If the statistician needs image review:

1. Download the relevant images from the Supabase `detections` storage bucket.
2. Keep `image_rename_helper_private.csv` on your side only.
3. Rename each downloaded image to the matching `exported_filename`.
4. Put the renamed files into an `images/` folder.
5. Share the `images/` folder together with `image_manifest_anon.csv`.

The statistician should receive only the anonymized filenames, not the original
Supabase URLs.

## Column guide

### `detections_joined_anon.csv`

- `detection_code`: anonymized detection identifier
- `participant_id`: anonymized participant / owner identifier
- `field_code`: anonymized field identifier, blank if unassigned
- `captured_date`: calendar date of the detection
- `captured_month`: first day of the capture month, useful for grouping
- `has_field`: whether the detection was linked to a field
- `has_image`: whether an image exists
- `exported_filename`: anonymized image filename if an image exists
- `confidence_pct`: model confidence converted to percent scale
- `mealybug_count`: counted mealybugs for the detection
- `has_mealybugs`: boolean pest flag
- `has_coordinates`: whether coordinates were recorded
- `latitude_approx_2dp`: latitude rounded to 2 decimal places
- `longitude_approx_2dp`: longitude rounded to 2 decimal places

### `field_summary_anon.csv`

- `field_code`: anonymized field identifier
- `participant_id`: anonymized owner identifier
- `field_created_date`: field creation date
- `field_updated_date`: latest field update date
- `image_count_cached`: cached image count stored on the field row
- `has_preview_image`: whether a preview image exists
- `detections_count`: number of detections linked to the field
- `total_mealybugs`: summed mealybug count across linked detections
- `avg_confidence_pct`: mean confidence on percent scale
- `first_detection_date`: earliest linked detection date
- `last_detection_date`: latest linked detection date

### `image_manifest_anon.csv`

- `detection_code`: anonymized detection identifier
- `participant_id`: anonymized owner identifier
- `field_code`: anonymized field identifier, blank if unassigned
- `captured_date`: detection date
- `exported_filename`: anonymized image filename shared in `images/`
- `mealybug_count`: counted mealybugs
- `confidence_pct`: confidence on percent scale
- `has_mealybugs`: boolean pest flag

## Suggested package structure

```text
statistician-export/
  README.md
  detections_joined_anon.csv
  field_summary_anon.csv
  image_manifest_anon.csv
  images/
```

## Final check before sharing

Confirm that the package you send does **not** contain:

- email addresses
- display names
- phone numbers
- raw UUIDs
- exact field names / addresses
- original image URLs
- the private rename helper CSV
