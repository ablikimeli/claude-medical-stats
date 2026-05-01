#!/usr/bin/env python3
"""
Utility functions for biostatistical analysis (Python)
Medical Statistics Skill
"""
import numpy as np
import pandas as pd
import scipy.stats as stats
import warnings


def check_normality(x, alpha=0.05):
    """
    Check normality with automatic test selection.
    Returns dict with normality status, P-value, and description.
    """
    x = x.dropna()
    n = len(x)
    if n < 3:
        return {"normality": "insufficient", "p": float("nan"), "desc": f"n={n}"}

    if n < 5000:
        w, p = stats.shapiro(x)
        test = "Shapiro-Wilk"
    else:
        from scipy.stats import kstest
        stat, p = kstest(x, "norm", args=(x.mean(), x.std()))
        test = "Kolmogorov-Smirnov"

    skew = stats.skew(x)
    kurt = stats.kurtosis(x, fisher=True)

    if p > alpha:
        result = {
            "normality": "normal",
            "p": p,
            "test": test,
            "desc": f"Mean ± SD = {x.mean():.2f} ± {x.std():.2f}",
            "method": "parametric (t-test / ANOVA)"
        }
    else:
        result = {
            "normality": "non-normal",
            "p": p,
            "test": test,
            "desc": f"Median (Q1, Q3) = {x.median():.2f} ({x.quantile(0.25):.2f}, {x.quantile(0.75):.2f})",
            "method": "non-parametric (Wilcoxon / Kruskal-Wallis)"
        }

    result.update({"n": n, "skewness": round(skew, 3), "kurtosis": round(kurt, 3)})
    return result


def compare_two_groups(x, group, method="auto"):
    """
    Compare two groups with automatic method selection.
    Returns dict with method, statistic, P-value, and note.
    """
    x = x.dropna()
    g = group.loc[x.index].dropna()
    common = x.index.intersection(g.index)
    x, g = x.loc[common], g.loc[common]
    groups = g.unique()
    if len(groups) != 2:
        return {"method": "error", "note": "Need exactly 2 groups"}
    g1, g2 = groups
    v1, v2 = x[g == g1], x[g == g2]
    if len(v1) < 2 or len(v2) < 2:
        return {"method": "error", "note": "Insufficient observations"}

    if method == "auto":
        norm1 = check_normality(v1)["normality"] == "normal"
        norm2 = check_normality(v2)["normality"] == "normal"
        _, var_p = stats.levene(v1, v2)
        var_equal = var_p > 0.05

        if norm1 and norm2 and var_equal:
            t, p = stats.ttest_ind(v1, v2)
            return {"method": "Student's t-test", "statistic": t, "p": p,
                    "note": "Normal, equal variances"}
        elif norm1 and norm2 and not var_equal:
            t, p = stats.ttest_ind(v1, v2, equal_var=False)
            return {"method": "Welch's t-test", "statistic": t, "p": p,
                    "note": "Normal, unequal variances"}
        else:
            u, p = stats.mannwhitneyu(v1, v2, alternative="two-sided")
            return {"method": "Mann-Whitney U", "statistic": u, "p": p,
                    "note": "Non-normal, non-parametric test"}
    else:
        return {"method": "user-specified", "note": f"Using {method}"}


def compare_multiple_groups(x, group):
    """Compare ≥3 groups."""
    x = x.dropna()
    g = group.loc[x.index].dropna()
    grouped = [x[g == val].dropna().values for val in g.unique() if len(x[g == val].dropna()) >= 2]
    if len(grouped) < 2:
        return {"method": "error", "note": "Need ≥2 groups with data"}

    # Check normality per group
    all_normal = all(len(v) >= 3 and stats.shapiro(v)[1] > 0.05 for v in grouped)

    if all_normal:
        f, p = stats.f_oneway(*grouped)
        return {"method": "One-way ANOVA", "statistic": f, "p": p,
                "posthoc": "Tukey HSD"}
    else:
        h, p = stats.kruskal(*grouped)
        return {"method": "Kruskal-Wallis", "statistic": h, "p": p,
                "posthoc": "Dunn's test with Bonferroni"}


def compare_categorical(contingency_table):
    """Compare categorical variables: χ² or Fisher's exact."""
    if (contingency_table < 5).any().any():
        if contingency_table.shape == (2, 2):
            odds, p = stats.fisher_exact(contingency_table)
            return {"method": "Fisher's exact", "statistic": odds, "p": p}
        else:
            return {"method": "Fisher-Freeman-Halton", "p": float("nan"),
                    "note": "Larger tables not supported for exact test"}
    else:
        chi2, p, dof, expected = stats.chi2_contingency(contingency_table)
        return {"method": "χ² test", "statistic": chi2, "p": p, "df": dof}


def compute_auc(y_true, y_pred):
    """Compute AUC-ROC."""
    from sklearn.metrics import roc_auc_score, roc_curve
    auc = roc_auc_score(y_true, y_pred)
    fpr, tpr, thresholds = roc_curve(y_true, y_pred)
    # DeLong SE approximation
    n1 = sum(y_true == 1)
    n0 = sum(y_true == 0)
    q1 = auc / (2 - auc)
    q2 = 2 * auc**2 / (1 + auc)
    se = np.sqrt((auc * (1 - auc) + (n1 - 1) * (q1 - auc**2) + (n0 - 1) * (q2 - auc**2)) / (n1 * n0))
    ci_low = max(0, auc - 1.96 * se)
    ci_high = min(1, auc + 1.96 * se)
    return {"auc": auc, "se": se, "ci": (ci_low, ci_high)}


def compute_evalue(est, ci_low=None, ci_high=None):
    """Compute E-value for sensitivity to unmeasured confounding."""
    import math

    def e_value_point(rr):
        if rr <= 1:
            return 1.0
        return rr + math.sqrt(rr * (rr - 1))

    def e_value_ci(ci_bound):
        if ci_bound <= 1:
            return 1.0
        return e_value_point(ci_bound)

    result = {"point_evalue": e_value_point(est)}
    if ci_low is not None:
        result["ci_evalue"] = e_value_ci(ci_low)
    if ci_high is not None:
        result["ci_high_evalue"] = e_value_ci(ci_high)
    return result


def describe_dataframe(df):
    """Comprehensive data description for reporting."""
    n_total = len(df)
    n_complete = len(df.dropna())
    report = {
        "N_total": n_total,
        "N_complete": n_complete,
        "pct_complete": round(n_complete / n_total * 100, 1),
        "missing_report": {}
    }
    for col in df.columns:
        n_miss = df[col].isna().sum()
        if n_miss > 0:
            report["missing_report"][col] = {
                "n_missing": n_miss,
                "pct_missing": round(n_miss / n_total * 100, 1)
            }
    return report
