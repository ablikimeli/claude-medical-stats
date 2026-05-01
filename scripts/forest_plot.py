#!/usr/bin/env python3
"""
Forest Plot Generator
For displaying multivariable regression results:
- Variable names, effect size (OR/HR/beta), 95% CI, P-value
- Exports to PNG + PDF
Medical Statistics Skill
"""
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from datetime import datetime


def forest_plot(data, effect_label="OR (95% CI)", reference=1,
                filename_prefix="forest", title=None, footnote=None):
    """
    Generate a publication-quality forest plot.

    Parameters
    ----------
    data : pd.DataFrame
        Must contain columns: Variable, Effect, Lower, Upper, [P_value]
    effect_label : str
        Label for x-axis ("OR (95% CI)", "HR (95% CI)", "beta (95% CI)")
    reference : float
        Reference value (1 for OR/HR, 0 for beta)
    filename_prefix : str
        Output file prefix
    title : str
        Plot title
    footnote : str
        Caption text
    """
    required = ["Variable", "Effect", "Lower", "Upper"]
    missing = [c for c in required if c not in data.columns]
    if missing:
        raise ValueError(f"Missing required columns: {missing}")

    df = data.copy()

    # Significance stars
    if "P_value" in df.columns:
        def star(p):
            if pd.isna(p):
                return ""
            elif p < 0.001:
                return "***"
            elif p < 0.01:
                return "**"
            elif p < 0.05:
                return "*"
            else:
                return "ns"
        df["Sig"] = df["P_value"].apply(star)
    else:
        df["Sig"] = ""

    # Display text
    if "P_value" in df.columns:
        df["DisplayText"] = df.apply(
            lambda r: f"{r['Effect']:.3f} ({r['Lower']:.3f}–{r['Upper']:.3f})  {r['P_value']:.4f}{r['Sig']}",
            axis=1
        )
    else:
        df["DisplayText"] = df.apply(
            lambda r: f"{r['Effect']:.3f} ({r['Lower']:.3f}–{r['Upper']:.3f})",
            axis=1
        )

    # Reverse order so first row is at top
    df = df.iloc[::-1].reset_index(drop=True)
    df["y_pos"] = range(len(df))

    # Set up the plot
    use_log = reference == 1
    n_vars = len(df)

    fig_height = max(4, n_vars * 0.5 + 1.5)
    fig, ax = plt.subplots(figsize=(10, fig_height))

    # X axis range
    all_vals = pd.concat([df["Lower"], df["Upper"], pd.Series([reference])])
    x_min, x_max = all_vals.min(), all_vals.max()
    x_pad = (x_max - x_min) * 0.15 if x_max != x_min else 0.5
    x_lim = (x_min - x_pad, x_max + x_pad)

    # Reference line
    ax.axvline(x=reference, color="#b2182b", linestyle="--", linewidth=0.8, alpha=0.7, zorder=1)

    # CI lines
    for _, row in df.iterrows():
        ax.plot([row["Lower"], row["Upper"]], [row["y_pos"], row["y_pos"]],
                color="gray30", linewidth=1.5, solid_capstyle="round", zorder=2)

    # Point estimates with color by significance
    color_map = {"***": "#b2182b", "**": "#d6604d", "*": "#f4a582", "ns": "gray60", "": "gray40"}
    for _, row in df.iterrows():
        color = color_map.get(row["Sig"], "gray40")
        ax.scatter(row["Effect"], row["y_pos"], color=color, s=60, zorder=3, edgecolors="white", linewidth=0.5)

    # Text labels on the right
    for _, row in df.iterrows():
        ax.text(x_lim[1], row["y_pos"], row["DisplayText"],
                ha="right", va="center", fontsize=8.5, fontfamily="serif")

    # Y axis labels (variable names)
    ax.set_yticks(df["y_pos"])
    ax.set_yticklabels(df["Variable"], fontsize=10, fontfamily="serif")

    # X axis
    if use_log:
        ax.set_xscale("log")
        ax.xaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: f"{x:.2f}"))

    ax.set_xlabel(effect_label, fontsize=11, fontweight="bold")
    ax.set_title(title or f"Forest Plot: {effect_label}",
                 fontsize=13, fontweight="bold", pad=12)

    # Caption / footnote
    caption = footnote or "Significance: *** P<0.001, ** P<0.01, * P<0.05, ns = not significant"
    ax.set_xlim(x_lim)
    ax.grid(True, axis="x", alpha=0.25, linestyle=":")
    ax.grid(False, axis="y")
    ax.axhline(y=-0.5, color="gray80", linewidth=0.5)

    # Reference annotation
    if use_log:
        ax.text(reference, ax.get_ylim()[0] - 0.3, "Reference",
                ha="center", fontsize=8, color="#b2182b", alpha=0.6)

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("gray80")
    ax.spines["bottom"].set_color("gray80")

    fig.text(0.02, 0.01, caption, fontsize=7.5, color="gray50", fontfamily="serif")

    plt.tight_layout()

    # Export
    print(f"\n  Generating forest plot: {title or filename_prefix}")

    png_file = f"{filename_prefix}.png"
    fig.savefig(png_file, dpi=300, bbox_inches="tight")
    print(f"  ✔ PNG: {png_file}")

    pdf_file = f"{filename_prefix}.pdf"
    fig.savefig(pdf_file, format="pdf", bbox_inches="tight")
    print(f"  ✔ PDF: {pdf_file}")

    plt.close(fig)
    return fig


def forest_plot_from_model(result_df, model_type, ts=None):
    """Convenience wrapper: create forest plot from model results DataFrame."""
    if ts is None:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")

    if model_type == "linear":
        effect_label = "beta (95% CI)"
        reference = 0
    elif model_type == "cox":
        effect_label = "HR (95% CI)"
        reference = 1
    else:
        effect_label = "OR (95% CI)"
        reference = 1

    titles = {"linear": "Linear Regression", "logistic": "Logistic Regression",
              "cox": "Cox Proportional Hazards"}
    prefix = f"forest_{model_type}_{ts}"

    forest_plot(result_df, effect_label=effect_label, reference=reference,
                filename_prefix=prefix, title=f"Forest Plot: {titles.get(model_type, model_type)}")
    return prefix


if __name__ == "__main__":
    print("✔ forest_plot.py loaded")
