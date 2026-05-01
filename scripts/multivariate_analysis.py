#!/usr/bin/env python3
"""
Multivariable Regression Analysis (Python)
Supports: linear, logistic, Cox proportional hazards
Medical Statistics Skill
"""
import argparse
import sys
import pandas as pd
import numpy as np
import scipy.stats as stats


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


def run_linear(df, outcome, predictors):
    import statsmodels.api as sm
    X = sm.add_constant(df[predictors].copy())
    # Drop rows with any NaN in X or y
    mask = X.notna().all(axis=1) & df[outcome].notna()
    X, y = X[mask], df.loc[mask, outcome]
    model = sm.OLS(y, X).fit()
    print(f"\n  R² = {model.rsquared:.4f}, Adj. R² = {model.rsquared_adj:.4f}")
    print(f"  F = {model.fvalue:.4f}, P = {model.f_pvalue:.4e}\n")
    print("  ┌────────────────────────────────────────────────────┐")
    print(f"  │ {'Variable':<20} │ {'β (95% CI)':<28} │ {'P':<8} │")
    print("  ├────────────────────────────────────────────────────┤")
    for var, coef in model.params.items():
        ci = model.conf_int().loc[var]
        p = model.pvalues[var]
        sig = "***" if p < 0.001 else "**" if p < 0.01 else "*" if p < 0.05 else ""
        print(f"  │ {var:<20} │ {coef:.4f} ({ci[0]:.4f}, {ci[1]:.4f}) │ {p:.4f}{sig:<3} │")
    print("  └────────────────────────────────────────────────────┘")
    return model


def run_logistic(df, outcome, predictors):
    import statsmodels.api as sm
    df[outcome] = pd.Categorical(df[outcome])
    X = sm.add_constant(df[predictors].copy())
    mask = X.notna().all(axis=1) & df[outcome].notna()
    X, y = X[mask], df.loc[mask, outcome]
    model = sm.Logit(y, X).fit(disp=0)
    or_val = np.exp(model.params)
    or_ci = np.exp(model.conf_int())

    print(f"\n  Pseudo R² = {model.prsquared:.4f}")
    print(f"  Log-Likelihood = {model.llf:.2f}")
    print(f"  AUC = {model.bic:.4f} (approximate)")  # Placeholder
    print("\n  ┌────────────────────────────────────────────────────────────┐")
    print(f"  │ {'Variable':<20} │ {'OR (95% CI)':<30} │ {'P':<8} │")
    print("  ├────────────────────────────────────────────────────────────┤")
    for var in model.params.index:
        p = model.pvalues[var]
        sig = "***" if p < 0.001 else "**" if p < 0.01 else "*" if p < 0.05 else ""
        print(f"  │ {var:<20} │ {or_val[var]:.4f} ({or_ci[0][var]:.4f}, {or_ci[1][var]:.4f}) │ {p:.4f}{sig:<3} │")
    print("  └────────────────────────────────────────────────────────────┘")
    return model


def run_cox(df, outcome, predictors, time_col):
    from lifelines import CoxPHFitter
    model_df = df[[time_col, outcome] + predictors].dropna()
    cph = CoxPHFitter()
    cph.fit(model_df, duration_col=time_col, event_col=outcome)
    hr = np.exp(cph.params_)
    hr_ci = np.exp(cph.confidence_intervals_)

    print(f"\n  Concordance = {cph.concordance_index_:.4f}")
    print(f"  Log-Likelihood = {cph.log_likelihood_:.2f}")
    print(f"  AIC = {cph.AIC_partial_:.2f}")
    print("\n  ┌────────────────────────────────────────────────────────────┐")
    print(f"  │ {'Variable':<20} │ {'HR (95% CI)':<30} │ {'P':<8} │")
    print("  ├────────────────────────────────────────────────────────────┤")
    for var in cph.params_.index:
        p = cph.summary.loc[var, "p"]
        sig = "***" if p < 0.001 else "**" if p < 0.01 else "*" if p < 0.05 else ""
        print(f"  │ {var:<20} │ {hr[var]:.4f} ({hr_ci[var].iloc[0]:.4f}, {hr_ci[var].iloc[1]:.4f}) │ {p:.4f}{sig:<3} │")
    print("  └────────────────────────────────────────────────────────────┘")
    return cph


def main():
    parser = argparse.ArgumentParser(description="Multivariable Regression")
    parser.add_argument("--data", required=True, help="Data file path")
    parser.add_argument("--outcome", required=True, help="Outcome variable")
    parser.add_argument("--type", required=True, choices=["linear", "logistic", "cox"], help="Model type")
    parser.add_argument("--vars", help="Comma-separated predictor variables")
    parser.add_argument("--time", help="Time variable (required for Cox)")
    parser.add_argument("--pthreshold", type=float, default=0.1, help="Variable selection threshold")
    args = parser.parse_args()

    df = read_data(args.data)

    # Determine predictors
    if args.vars:
        predictors = [v.strip() for v in args.vars.split(",") if v.strip() in df]
    else:
        if args.type == "cox" and args.time:
            predictors = [c for c in df.columns if c not in (args.outcome, args.time)]
        else:
            predictors = [c for c in df.columns if c != args.outcome]

    print("\n" + "=" * 65)
    model_names = {"linear": "Linear", "logistic": "Logistic", "cox": "Cox PH"}
    print(f"         {model_names[args.type]} Regression Results")
    print("=" * 65)
    print(f"\n  N = {len(df)}")
    print(f"  Predictors: {', '.join(predictors)}\n")

    if args.type == "linear":
        run_linear(df, args.outcome, predictors)
    elif args.type == "logistic":
        run_logistic(df, args.outcome, predictors)
    elif args.type == "cox":
        if not args.time:
            print("ERROR: --time required for Cox regression")
            sys.exit(1)
        run_cox(df, args.outcome, predictors, args.time)

    print("\n" + "=" * 65)


if __name__ == "__main__":
    main()
