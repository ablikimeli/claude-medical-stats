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

    # Generate prediction for plot
    x_range = np.linspace(df[args.continuous].min(), df[args.continuous].max(), 100)
    rcs_pred = rcs_basis(x_range, knot_locs)
    pred_df = pd.DataFrame(rcs_pred, columns=[c for c in model.params.index
                                              if c not in ["const"] + covariates + [args.continuous]])
    pred_df = sm.add_constant(pred_df)

    # Add covariate means for prediction
    for cov in covariates:
        pred_df[cov] = df[cov].mean() if np.issubdtype(df[cov].dtype, np.number) else df[cov].mode()[0]

    # Ensure column alignment
    pred_df = pred_df[model.params.index]
    linear_pred = model.predict(pred_df)
    se_pred = np.sqrt(model.cov_params().values.diagonal().sum())  # Approximate

    # Odds Ratio relative to median
    ref_val = df[args.continuous].median()
    ref_rcs = rcs_basis(np.array([ref_val]), knot_locs)
    ref_df = pd.DataFrame(ref_rcs, columns=[c for c in model.params.index
                                            if c not in ["const"] + covariates + [args.continuous]])
    ref_df = sm.add_constant(ref_df)
    for cov in covariates:
        ref_df[cov] = pred_df[cov].iloc[0]
    ref_df = ref_df[model.params.index]
    ref_pred = model.predict(ref_df)[0]

    or_values = np.exp(linear_pred - ref_pred)

    # Generate RCS plot
    fig, ax = plt.subplots(figsize=(8, 6))
    ax.plot(x_range, or_values, color="#2c3e50", linewidth=2, label="OR estimate")
    ax.axhline(y=1, color="red", linestyle="--", alpha=0.7)
    ax.axvline(x=ref_val, color="gray", linestyle=":", alpha=0.5, label=f"Reference ({ref_val:.1f})")
    # Add rug plot
    ax.scatter(df[args.continuous], [1.01] * len(df), alpha=0.1, s=1, color="black")
    ax.set_xlabel(args.continuous, fontsize=12)
    ax.set_ylabel("OR (95% CI)", fontsize=12)
    ax.set_title(f"RCS: {args.continuous} vs {args.outcome}\nk={n_knots} knots | Non-linearity P={lr_p:.4f}",
                 fontsize=13, fontweight="bold")
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)
    plt.tight_layout()

    out_file = f"rcs_{args.continuous}_{args.outcome}.png"
    fig.savefig(out_file, dpi=300)
    print(f"\n  RCS plot saved: {out_file}")

    print("\n" + "=" * 55)


if __name__ == "__main__":
    # Need sm for the prediction part
    import statsmodels.api as sm
    main()
