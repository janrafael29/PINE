$ErrorActionPreference = "Stop"

$zip = "D:\old_PINE\share_bundle.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }

$paths = @(
  "D:\old_PINE\docs\training\MODEL_PERFORMANCE_ALL_VERSIONS.md",
  "D:\old_PINE\docs\V14_TRAINING_LOG.md",
  "D:\old_PINE\docs\V15_TRAINING_LOG.md",
  "D:\old_PINE\docs\V16_TRAINING_LOG.md",
  "D:\old_PINE\docs\V17_TRAINING_LOG.md",
  "D:\old_PINE\docs\V18_TRAINING_LOG.md",
  "D:\old_PINE\docs\training\MODEL_METRICS_V13AFIX_AND_COMPARISON.md",

  "D:\old_PINE\runs\retrain\mealybug_v13afix\weights\best.pt",
  "D:\old_PINE\runs\retrain\mealybug_v15_full\weights\best.pt",
  "D:\old_PINE\runs\retrain\mealybug_v16_selffix\weights\best.pt",
  "D:\old_PINE\runs\retrain\mealybug_v17_sam-2\weights\best.pt",
  "D:\old_PINE\runs\retrain\mealybug_v18_nosam\weights\best.pt",

  "D:\old_PINE\runs\retrain\mealybug_v15_full\results.csv",
  "D:\old_PINE\runs\retrain\mealybug_v15_full\args.yaml",
  "D:\old_PINE\runs\retrain\mealybug_v16_selffix\results.csv",
  "D:\old_PINE\runs\retrain\mealybug_v16_selffix\args.yaml",
  "D:\old_PINE\runs\retrain\mealybug_v17_sam-2\results.csv",
  "D:\old_PINE\runs\retrain\mealybug_v17_sam-2\args.yaml",
  "D:\old_PINE\runs\retrain\mealybug_v18_nosam\results.csv",
  "D:\old_PINE\runs\retrain\mealybug_v18_nosam\args.yaml",

  "D:\old_PINE\vast_download\labels_snapshots\mealybug_v13afix_label_snapshots.tar.gz",
  "D:\old_PINE\vast_download\config\data.yaml",
  "D:\old_PINE\vast_download\config\data_fixed.yaml",
  "D:\old_PINE\vast_download\config\data_v15.yaml",

  "D:\old_PINE\lib\core\constants.dart",
  "D:\old_PINE\assets\model\best.tflite",
  "D:\old_PINE\assets\model\README.md"
)

$existing = @()
$missing = @()
foreach ($p in $paths) {
  if (Test-Path $p) { $existing += $p } else { $missing += $p }
}

foreach ($m in $missing) { Write-Host "MISSING: $m" }

Compress-Archive -Path $existing -DestinationPath $zip -Force

$z = Get-Item $zip
Write-Host "ZIP_OK: $zip"
Write-Host "ZIP_BYTES: $($z.Length)"
Write-Host "FILES_INCLUDED: $($existing.Count)"

