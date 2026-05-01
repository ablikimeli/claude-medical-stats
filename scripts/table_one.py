#!/usr/bin/env python3
"""
Table 1: Baseline Characteristics with Group Comparison (Python)
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


def format_continuous(x):
    """Auto-detect normal vs non-normal and format."""
    x = x.dropna()
    n = len(x)
    if n < 3:
        return (f"n={n}", "", "")
    if n < 5000:
        _, p = stats.shapiro(x)
    else:
        from scipy.stats import kstest
        _, p = kstest(x, "norm", args=(x.mean(), x.std()))

    if p > 0.05:
        return (f"{x.mean():.2f} ± {x.std():.2f}", "normal", p)
    else:
        return (f"{x.median():.2f} ({x.quantile(0.25):.2f}, {x.quantile(0.75):.2f})", "non-normal", p)


def compare_two_groups(x, group, normal):
    """Compare two groups and return test name + P value."""
    unique_groups = group.dropna().unique()
    if len(unique_groups) != 2:
        return ("N/A", float("nan"))
    g1, g2 = unique_groups
    vals1 = x[group == g1].dropna()
    vals2 = x[group == g2].dropna()
    if len(vals1) < 2 or len(vals2) < 2:
        return ("N/A", float("nan"))
    if normal:
        stat, p = stats.ttest_ind(vals1, vals2)
        return ("t-test", p)
    else:
        stat, p = stats.mannwhitneyu(vals1, vals2, alternative="two-sided")
        return ("Wilcoxon rank-sum", p)


def compare_categorical(x, group):
    """Compare categorical variable across groups."""
    ct = pd.crosstab(x, group)
    if ct.size == 0:
        return ("N/A", float("nan"))
    if (ct < 5).any().any():
        _, p = stats.fisher_exact(ct) if ct.shape == (2, 2) else (float("nan"), float("nan"))
        method = "Fisher's exact" if ct.shape == (2, 2) else "Fisher-Freeman-Halton"
        return (method, p) if ct.shape == (2, 2) else ("Fisher-Freeman-Halton", float("nan"))
    else:
        chi2, p, _, _ = stats.chi2_contingency(ct)
        return ("χ² test", p)


def main():
    parser = argparse.ArgumentParser(description="Table 1 Generator")
    parser.add_argument("--data", required=True, help="Data file path")
    parser.add_argument("--outcome", required=True, help="Grouping variable")
    parser.add_argument("--continuous", help="Comma-separated continuous vars")
    parser.add_argument("--categorical", help="Comma-separated categorical vars")
    parser.add_argument("--nonnormal", help="Comma-separated non-normal vars")
    args = parser.parse_args()

    df = read_data(args.data)

    # Auto-detect variable types
    all_vars = [c for c in df.columns if c != args.outcome]
    if args.continuous:
        cont_vars = [v.strip() for v in args.continuous.split(",") if v.strip() in df]
    else:
        cont_vars = [c for c in df.select_dtypes(include=[np.number]).columns
                     if c != args.outcome and df[c].nunique() > 10]

    if args.categorical:
        cat_vars = [v.strip() for v in args.categorical.split(",") if v.strip() in df]
    else:
        cat_vars = [c for c in all_vars if c not in cont_vars]

    if args.nonnormal:
        nonnormal_vars = [v.strip() for v in args.nonnormal.split(",") if v.strip() in df]
    else:
        nonnormal_vars = []

    groups = df[args.outcome].dropna().unique()
    print("\n" + "=" * 65)
    print("         Table 1: Baseline Characteristics")
    print("=" * 65)

    # Continuous variables
    print(f"\n{'Variable':<25}", end="")
    for g in groups:
        print(f"{'Group '+str(g):<25}", end="")
    print(f"{'P-value':<10}{'Method':<20}")

    print("-" * 65)

    sig_vars = []
    for var in cont_vars:
        desc, dist, _ = format_continuous(df[var])
        print(f"{var:<25}", end="")
        for g in groups:
            vals = df[df[args.outcome] == g][var]
            if dist == "normal":
                print(f"{vals.mean():.2f} ± {vals.std():.2f}".ljust(25), end="")
            else:
                print(f"{vals.median():.2f} ({vals.quantile(0.25):.2f}, {vals.quantile(0.75):.2f})".ljust(25), end="")
        if len(groups) == 2:
            method, p = compare_two_groups(df[var], df[args.outcome], dist == "normal")
        else:
            if dist == "normal":
                f_stat, p = stats.f_oneway(*[df[df[args.outcome] == g][var].dropna() for g in groups])
                method = "ANOVA"
            else:
                h_stat, p = stats.kruskal(*[df[df[args.outcome] == g][var].dropna() for g in groups])
                method = "Kruskal-Wallis"
        print(f"{p:.4f}".ljust(10), end="") if not np.isnan(p) else print("N/A".ljust(10), end="")
        print(f"{method:<20}")
        if not np.isnan(p) and p < 0.1:
            sig_vars.append(var)

    # Categorical variables
    for var in cat_vars:
        print(f"{var:<25}", end="")
        for g in groups:
            sub = df[df[args.outcome] == g][var]
            counts = sub.value_counts()
            n = sub.dropna().shape[0]
            # Show the most frequent level
            top = counts.index[0] if len(counts) > 0 else ""
            top_n = counts.iloc[0] if len(counts) > 0 else 0
            pct = top_n / n * 100 if n > 0 else 0
            print(f"{top} {top_n} ({pct:.1f}%)".ljust(25), end="")
        method, p = compare_categorical(df[var], df[args.outcome])
        print(f"{p:.4f}".ljust(10), end="") if not np.isnan(p) else print("N/A".ljust(10), end="")
        print(f"{method:<20}")
        if not np.isnan(p) and p < 0.1:
            sig_vars.append(var)

    print("\n" + "=" * 65)
    if sig_vars:
        print("\nVariables with P < 0.1 (candidates for multivariable model):")
        for v in sig_vars:
            print(f"  ■ {v}")
    else:
        print("\nNo variables with P < 0.1")

    print("=" * 65)


if __name__ == "__main__":
    main()
