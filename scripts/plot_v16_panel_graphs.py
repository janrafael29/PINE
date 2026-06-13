#!/usr/bin/env python3
"""Generate mealybug_v16_selffix training curves for panel slides."""

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
CSV = ROOT / "runs/retrain/mealybug_v16_selffix/results.csv"
OUT = ROOT / "docs/thesis/assets/v16_selffix"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    df = pd.read_csv(CSV)
    df.columns = [c.strip() for c in df.columns]
    ep = df["epoch"]
    best_i = df["metrics/mAP50(B)"].idxmax()
    best_ep = int(df.loc[best_i, "epoch"])
    best_map = df.loc[best_i, "metrics/mAP50(B)"] * 100

    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    fig.patch.set_facecolor("#0f172a")
    for ax in axes.flat:
        ax.set_facecolor("#1e293b")
        ax.tick_params(colors="#94a3b8")
        ax.xaxis.label.set_color("#94a3b8")
        ax.yaxis.label.set_color("#94a3b8")
        ax.title.set_color("#f8fafc")
        ax.grid(True, alpha=0.25, color="#334155")

    axes[0, 0].plot(ep, df["train/box_loss"], label="train", color="#38bdf8", lw=1.5)
    axes[0, 0].plot(ep, df["val/box_loss"], label="val", color="#fbbf24", lw=1.5)
    axes[0, 0].set_title("Box loss")
    axes[0, 0].legend(facecolor="#1e293b", labelcolor="#f8fafc")

    axes[0, 1].plot(ep, df["train/cls_loss"], label="train", color="#38bdf8", lw=1.5)
    axes[0, 1].plot(ep, df["val/cls_loss"], label="val", color="#fbbf24", lw=1.5)
    axes[0, 1].set_title("Classification loss")
    axes[0, 1].legend(facecolor="#1e293b", labelcolor="#f8fafc")

    axes[1, 0].plot(ep, df["metrics/precision(B)"], color="#2563eb", lw=1.5, label="Precision")
    axes[1, 0].plot(ep, df["metrics/recall(B)"], color="#16a34a", lw=1.5, label="Recall")
    axes[1, 0].set_title("Precision & Recall (val)")
    axes[1, 0].set_ylim(0, 1)
    axes[1, 0].legend(facecolor="#1e293b", labelcolor="#f8fafc")

    axes[1, 1].plot(ep, df["metrics/mAP50(B)"], color="#4ade80", lw=2, label="mAP@0.5")
    axes[1, 1].plot(ep, df["metrics/mAP50-95(B)"], color="#ea580c", lw=1.5, label="mAP@0.5:0.95")
    axes[1, 1].axvline(best_ep, color="#fbbf24", ls="--", alpha=0.7, lw=1)
    axes[1, 1].scatter([best_ep], [df.loc[best_i, "metrics/mAP50(B)"]], color="#fbbf24", s=60, zorder=5)
    axes[1, 1].set_title(f"mAP (val) — best ep {best_ep}: {best_map:.1f}% @0.5")
    axes[1, 1].set_ylim(0, 1)
    axes[1, 1].legend(facecolor="#1e293b", labelcolor="#f8fafc")

    fig.suptitle(
        "mealybug_v16_selffix — Training curves (1280px, fine-tune from v15)",
        color="#f8fafc",
        fontsize=14,
        y=1.02,
    )
    plt.tight_layout()
    fig.savefig(OUT / "v16_selffix_training_curves.png", dpi=150, facecolor=fig.get_facecolor(), bbox_inches="tight")
    plt.close()

    fig2, ax = plt.subplots(1, 1, figsize=(11, 4.5))
    fig2.patch.set_facecolor("#0f172a")
    ax.set_facecolor("#1e293b")
    ax.plot(ep, df["metrics/mAP50(B)"], color="#4ade80", lw=2.2, label="mAP@0.5")
    ax.plot(ep, df["metrics/recall(B)"], color="#16a34a", lw=1.5, alpha=0.85, label="Recall")
    ax.plot(ep, df["metrics/precision(B)"], color="#38bdf8", lw=1.5, alpha=0.85, label="Precision")
    ax.axvline(best_ep, color="#fbbf24", ls="--", alpha=0.6, label=f"Best val mAP ep {best_ep}")
    ax.set_xlabel("Epoch", color="#94a3b8")
    ax.set_ylabel("Score", color="#94a3b8")
    ax.set_title(
        "Version 16 (mealybug_v16_selffix) — Validation metrics during training",
        color="#f8fafc",
        fontsize=13,
    )
    ax.set_ylim(0, 1)
    ax.tick_params(colors="#94a3b8")
    ax.legend(loc="lower right", facecolor="#1e293b", labelcolor="#f8fafc")
    ax.grid(True, alpha=0.25, color="#334155")
    plt.tight_layout()
    fig2.savefig(OUT / "v16_selffix_map_progression.png", dpi=150, facecolor=fig2.get_facecolor(), bbox_inches="tight")
    plt.close()

    print(f"Wrote graphs to {OUT}")
    print(f"Best val mAP@0.5: epoch {best_ep} = {best_map:.1f}%")


if __name__ == "__main__":
    main()
