#!/usr/bin/env python3
"""
Normality Assessment Script (Python)
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


def normality_report(x, var_name):
    x = x.dropna()
    n = len(x)
    if n < 3:
        return None

    mean_val = x.mean()
    sd_val = x.std()
    median_val = x.median()
    q1, q3 = x.quantile(0.25), x.quantile(0.75)
    skew = stats.skew(x)
    kurt = stats.kurtosis(x, fisher=True)

    if n < 5000:
        w, p = stats.shapiro(x)
        test_name = "Shapiro-Wilk"
    else:
        from scipy.stats import kstest
        stat, p = kstest(x, "norm", args=(mean_val, sd_val))
        w = stat
        test_name = "Kolmogorov-Smirnov"

    if p > 0.05:
        normality = "Normal"
        desc = f"Mean ± SD = {mean_val:.2f} ± {sd_val:.2f}"
        rec_method = "Parametric (t-test / ANOVA)"
    else:
        normality = "Non-normal"
        desc = f"Median (Q1, Q3) = {median_val:.2f} ({q1:.2f}, {q3:.2f})"
        rec_method = "Non-parametric (Wilcoxon / Kruskal-Wallis)"

    return {
        "variable": var_name, "n": n,
        "mean": round(mean_val, 3), "sd": round(sd_val, 3),
        "median": round(median_val, 3), "Q1": round(q1, 3), "Q3": round(q3, 3),
        "skewness": round(skew, 3), "kurtosis": round(kurt, 3),
        "test": test_name, "statistic": round(w, 4), "P": round(p, 4),
        "normality": normality, "description": desc,
        "recommended_method": rec_method
    }


def main():
    parser = argparse.ArgumentParser(description="Normality Assessment")
    parser.add_argument("--data", required=True, help="Data file path")
    parser.add_argument("--vars", help="Comma-separated variable names")
    args = parser.parse_args()

    df = read_data(args.data)
    print("\n" + "=" * 55)
    print("         Normality Assessment Results")
    print("=" * 55 + "\n")

    if args.vars:
        continuous_vars = [v.strip() for v in args.vars.split(",") if v.strip() in df]
    else:
        continuous_vars = [c for c in df.select_dtypes(include=[np.number]).columns
                           if df[c].nunique() > 10]

    results = []
    for var in continuous_vars:
        res = normality_report(df[var], var)
        if res is None:
            continue
        results.append(res)

        # Detailed output
        print(f"  ■ {var} (n={res['n']})")
        print(f"    {res['test']} P = {res['P']:.4f}")
        if res['normality'] == "Normal":
            print(f"    ✅ Normal (P > 0.05)")
        else:
            print(f"    ❌ Non-normal (P ≤ 0.05)")
        print(f"    {res['description']}")
        print("    " + "-" * 35)

    # Summary table
    print("\n" + "─" * 55)
    print(" Summary")
    print("─" * 55)
    res_df = pd.DataFrame(results)
    print(res_df.to_string(index=False,
          columns=["variable", "n", "P", "normality", "recommended_method"]))

    # Method recommendations
    print("\n" + "─" * 55)
    print(" Method Recommendations")
    print("─" * 55)
    for r in results:
        print(f"  {r['variable']}: {r['recommended_method']}")

    print("\n" + "=" * 55)


if __name__ == "__main__":
    main()
