# Wrapper: eval v16 on corrected test + copy PR/confusion plots to panel assets.
# See scripts/eval_v16_corrected_test_plots.py

param([switch]$SkipLabelFix)

$Root = "D:\old_PINE"
Set-Location $Root

$args_py = @()
if ($SkipLabelFix) { $args_py += "--skip-label-fix" }

python scripts/eval_v16_corrected_test_plots.py @args_py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

python scripts/plot_v16_panel_graphs.py
Write-Host "`nPanel assets: docs\thesis\assets\v16_selffix\" -ForegroundColor Green
