#!/usr/bin/env python3
"""
Restricted Cubic Spline (RCS) Analysis (Python)
Medical Statistics Skill
"""
import argparse
import sys
import pandas as pd
import numpy as np
import scipy.stats as stats
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def read_data(filepath):
    ext = filepath.split(".")[-1].lower()
    if ext == "csv":
        return pd.read_csv(filepath)
    elif ext in ("xls", "xlsx"):
        return pd.read_excel(filepath)
    elif ext == "sav":
        import pyreadstat
        return pd.read_spss(filepath)
    elif ext == "dta":
        return pd.read_stata(filepath)
    else:
        raise ValueError(f"Unsupported format: {ext}")


def rcs_basis(x, knots):
    """Generate restricted cubic spline basis."""
    n = len(x)
    k = len(knots)
    basis = np.zeros((n, k - 1))
    basis[:, 0] = x.copy()
    tj = knots
    for j in range(1, k - 1):
        basis[:, j] = np.maximum(0, x - tj[j]) ** 3
        basis[:, j] -= np.maximum(0, x - tj[k - 2]) ** 3 * (tj[k - 1] - tj[j]) / (tj[k - 1] - tj[k - 2])
        basis[:, j] += np.maximum(0, x - tj[k - 1]) ** 3 * (tj[k - 2] - tj[j]) / (tj[k - 1] - tj[k - 2])
    return basis


def run_rcs_logistic(df, outcome, cont_var, covariates, knots_pos, n_knots):
    import statsmodels.api as sm

    x = df[cont_var].values
    # Set knot locations
    knot_locs = np.percentile(x[np.isfinite(x)], knots_pos)
    knot_locs = np.unique(knot_locs)
    n_knots = len(knot_locs)

    # RCS basis
    rcs = rcs_basis(x, knot_locs)
    rcs_cols = [f"{cont_var}_rcs_{i}" for i in range(rcs.shape[1])]
    X_rcs = pd.DataFrame(rcs, columns=rcs_cols, index=df.index)
    if covariates:
        X_rcs[covariates] = df[covariates].values
    X_rcs = sm.add_constant(X_rcs)
    mask = X_rcs.notna().all(axis=1) & df[outcome].notna()
    X_rcs, y = X_rcs[mask], df.loc[mask, outcome]
    model = sm.Logit(y, X_rcs).fit(disp=0)

    # Linear model for comparison
    X_lin = pd.DataFrame({cont_var: df[cont_var].values})
    if covariates:
        X_lin[covariates] = df[covariates].values
    X_lin = sm.add_constant(X_lin)
    X_lin, y_lin = X_lin[mask], df.loc[mask, outcome]
    model_lin = sm.Logit(y_lin, X_lin).fit(disp=0)

    # Likelihood ratio test for nonlinearity
    lr_stat = 2 * (model.llf - model_lin.llf)
    lr_p = 1 - stats.chi2.cdf(lr_stat, n_knots - 1)

    return model, knot_locs, lr_stat, lr_p


def main():
    parser = argparse.ArgumentParser(description="RCS Analysis")
    parser.add_argument("--data", required=True, help="Data file path")
    parser.add_argument("--outcome", required=True, help="Outcome variable")
    parser.add_argument("--continuous", required=True, help="Continuous variable for RCS")
    parser.add_argument("--covariates", help="Comma-separated covariates")
    parser.add_argument("--knots", type=int, default=4, help="Number of knots")
    parser.add_argument("--type", default="logistic", choices=["logistic", "cox"])
    parser.add_argument("--time", help="Time variable (for Cox)")
    args = parser.parse_args()

    df = read_data(args.data)

    covariates = []
    if args.covariates:
        covariates = [v.strip() for v in args.covariates.split(",") if v.strip() in df]

    # Knot positions based on sample size
    if args.knots == 3:
        knots_pos = [10, 50, 90]
    elif args.knots == 4:
        knots_pos = [5, 35, 65, 95]
    else:
        knots_pos = [5, 27.5, 50, 72.5, 95]

    n_knots = args.knots

    print("\n" + "=" * 55)
    print("     Restricted Cubic Spline (RCS) Analysis")
    print("=" * 55 + "\n")
    print(f"  Continuous variable: {args.continuous}")
    print(f"  Outcome: {args.outcome}")
    if covariates:
        print(f"  Covariates: {', '.join(covariates)}")
    print(f"  Knots (k={n_knots})\n")

    if args.type == "logistic":
        model, knot_locs, lr_stat, lr_p = run_rcs_logistic(
            df, args.outcome, args.continuous, covariates, knots_pos, n_knots)
    else:
        print("  Python RCS for Cox is in development; falling back to statsmodels.")
        model, knot_locs, lr_stat, lr_p = run_rcs_logistic(
            df, args.outcome, args.continuous, covariates, knots_pos, n_knots)

    print(f"  Knot locations: {np.round(knot_locs, 2)}")
    print(f"\n  ── Nonlinearity Test ──")
    print(f"  LR statistic = {lr_stat:.4f}")
    print(f"  P-value = {lr_p:.4f}")
    if lr_p < 0.05:
        print(f"  ✅ Significant non-linear relationship (P < 0.05)")
    else:
        print(f"  ❌ No significant non-linearity (P ≥ 0.05)")

    # Generate prediction for plot using delta method for CI
    x_range = np.linspace(df[args.continuous].min(), df[args.continuous].max(), 200)
    rcs_pred = rcs_basis(x_range, knot_locs)

    # Build prediction DataFrame matching model design
    rcs_cols = [f"{args.continuous}_rcs_{i}" for i in range(rcs_pred.shape[1])]
    pred_df = pd.DataFrame(rcs_pred, columns=rcs_cols)
    pred_df = sm.add_constant(pred_df)
    # Rename to match model param names
    param_names = model.params.index.tolist()
    col_map = {}
    for i, col in enumerate(rcs_cols):
        col_map[col] = [p for p in param_names if p.startswith(f"{args.continuous}_rcs_")][i] if len([p for p in param_names if p.startswith(f"{args.continuous}_rcs_")]) > i else col

    # Add covariates at fixed values
    for cov in covariates:
        pred_df[cov] = df[cov].mean() if np.issubdtype(df[cov].dtype, np.number) else df[cov].mode()[0]

    # Ensure column order matches model params
    for p in param_names:
        if p not in pred_df.columns:
            pred_df[p] = 0
    pred_df = pred_df[param_names]

    # Linear predictor and SE via delta method
    X_pred = pred_df.values
    cov_beta = model.cov_params().values
    linear_pred = X_pred @ model.params.values
    var_pred = np.diag(X_pred @ cov_beta @ X_pred.T)
    se_pred = np.sqrt(np.maximum(var_pred, 0))

    # Odds Ratio relative to median reference
    ref_val = df[args.continuous].median()
    ref_rcs = rcs_basis(np.array([ref_val]), knot_locs)
    ref_df = pd.DataFrame(ref_rcs, columns=rcs_cols)
    ref_df = sm.add_constant(ref_df)
    for cov in covariates:
        ref_df[cov] = pred_df[cov].iloc[0]
    for p in param_names:
        if p not in ref_df.columns:
            ref_df[p] = 0
    ref_df = ref_df[param_names]
    ref_linpred = (ref_df.values @ model.params.values)[0]

    or_values = np.exp(linear_pred - ref_linpred)
    or_lower = np.exp(linear_pred - ref_linpred - 1.96 * se_pred)
    or_upper = np.exp(linear_pred - ref_linpred + 1.96 * se_pred)

    # Build export data
    export_data = pd.DataFrame({
        args.continuous: x_range,
        "OR": or_values,
        "CI_Lower": or_lower,
        "CI_Upper": or_upper,
        "logOR": linear_pred - ref_linpred,
        "logOR_SE": se_pred
    })

    # Generate RCS plot with proper CI bands
    fig, ax = plt.subplots(figsize=(9, 6.5))
    ax.fill_between(x_range, or_lower, or_upper, alpha=0.2, color="#3498db", label="95% CI")
    ax.plot(x_range, or_values, color="#2c3e50", linewidth=2, label="OR estimate")
    ax.axhline(y=1, color="red", linestyle="--", alpha=0.7, linewidth=0.9)
    ax.axvline(x=ref_val, color="gray", linestyle=":", alpha=0.5, linewidth=0.9,
               label=f"Reference ({ref_val:.1f})")
    ax.scatter(df[args.continuous], [1.01] * len(df), alpha=0.08, s=2, color="gray", label="Data")
    ax.set_xlabel(args.continuous, fontsize=12, fontweight="bold")
    ax.set_ylabel("OR (95% CI)", fontsize=12, fontweight="bold")
    ax.set_title(f"RCS: {args.continuous} vs {args.outcome}\n"
                 f"k={n_knots} knots | Non-linearity P={lr_p:.4f}",
                 fontsize=13, fontweight="bold")
    ax.legend(fontsize=9, loc="upper right")
    ax.grid(True, alpha=0.25, linestyle=":")
    plt.tight_layout()

    # Export: PNG + PDF + Excel
    from export_utils import save_plot_dual, export_to_excel, timestamp
    ts = timestamp()
    base_name = f"rcs_{args.continuous}_{args.outcome}_{ts}"
    save_plot_dual(fig, base_name, width=9, height=6.5)
    export_to_excel(export_data, f"{base_name}_data.xlsx",
                    sheet_name="RCS_Predictions",
                    title=f"RCS Predictions: {args.continuous} vs {args.outcome}")
    plt.close(fig)

    print(f"\n  Reference value: {args.continuous} = {ref_val:.2f} (median)")
    print(f"  Knot locations: {np.round(knot_locs, 2)}")
    print(f"  Non-linearity LR test: P = {lr_p:.4f}")

    print("\n" + "=" * 55)


if __name__ == "__main__":
    import statsmodels.api as sm
    main()
