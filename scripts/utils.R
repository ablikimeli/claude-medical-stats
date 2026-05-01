#!/usr/bin/env Rscript
# ============================================
# 医学统计工具函数
# medical-statistics skill
# ============================================

#' 安装并加载R包
ensure_packages <- function(packages) {
  installed <- rownames(installed.packages())
  for (pkg in packages) {
    if (!pkg %in% installed) {
      cat(sprintf("正在安装: %s\n", pkg))
      install.packages(pkg, repos = "https://cran.r-project.org")
    }
  }
  invisible(lapply(packages, library, character.only = TRUE))
}

#' 描述统计自动选择
#' 正态: Mean ± SD, 非正态: Median (Q1, Q3)
describe_continuous <- function(x) {
  x <- x[!is.na(x)]
  n <- length(x)
  if (n < 3) return(list(text = sprintf("n=%d", n), method = "样本量不足"))

  if (n < 5000) {
    p <- shapiro.test(x)$p.value
  } else {
    p <- ks.test(x, "pnorm", mean(x), sd(x))$p.value
  }

  if (p > 0.05) {
    list(
      text = sprintf("%.2f ± %.2f", mean(x), sd(x)),
      method = "参数检验",
      normality = TRUE,
      p = p
    )
  } else {
    list(
      text = sprintf("%.2f (%.2f-%.2f)", median(x), quantile(x, 0.25), quantile(x, 0.75)),
      method = "非参数检验",
      normality = FALSE,
      p = p
    )
  }
}

#' 自动选择两组比较方法
select_two_group_test <- function(x, group) {
  x <- x[!is.na(x)]
  group <- group[!is.na(x)]

  if (length(unique(group)) != 2) {
    return(list(method = "错误", note = "分组变量必须有2个水平"))
  }

  # 正态性
  p_normal <- shapiro.test(x)$p.value
  # 方差齐性
  var_test <- var.test(x ~ group)
  var_equal <- var_test$p.value > 0.05

  if (p_normal > 0.05 && var_equal) {
    t_result <- t.test(x ~ group, var.equal = TRUE)
    list(
      method = "独立样本t检验",
      statistic = t_result$statistic,
      p_value = t_result$p.value,
      note = "正态分布且方差齐"
    )
  } else if (p_normal > 0.05 && !var_equal) {
    t_result <- t.test(x ~ group, var.equal = FALSE)
    list(
      method = "Welch t检验",
      statistic = t_result$statistic,
      p_value = t_result$p.value,
      note = "正态分布但方差不齐"
    )
  } else {
    w_result <- wilcox.test(x ~ group)
    list(
      method = "Wilcoxon秩和检验",
      statistic = w_result$statistic,
      p_value = w_result$p.value,
      note = "非正态分布，使用非参数检验"
    )
  }
}

#' 自动选择多组比较方法
select_multigroup_test <- function(x, group) {
  x <- x[!is.na(x)]
  group <- factor(group[!is.na(x)])

  # 每组正态性
  groups <- levels(group)
  all_normal <- TRUE
  for (g in groups) {
    sub_x <- x[group == g]
    if (length(sub_x) >= 3) {
      if (shapiro.test(sub_x)$p.value <= 0.05) {
        all_normal <- FALSE
        break
      }
    }
  }

  if (all_normal) {
    aov_result <- summary(aov(x ~ group))
    list(
      method = "单因素ANOVA",
      statistic = aov_result[[1]]$`F value`[1],
      p_value = aov_result[[1]]$`Pr(>F)`[1],
      note = "各组均正态分布",
      posthoc = "Tukey HSD"
    )
  } else {
    kw_result <- kruskal.test(x ~ group)
    list(
      method = "Kruskal-Wallis检验",
      statistic = kw_result$statistic,
      p_value = kw_result$p.value,
      note = "存在非正态分布组",
      posthoc = "Dunn检验"
    )
  }
}

#' 检查并安装必需包
required_packages <- c("tableone", "rms", "Hmisc", "ggplot2",
                       "dplyr", "tidyr", "foreign", "haven",
                       "readxl", "survival", "survminer", "splines")

ensure_packages(required_packages)
cat("✔ 所有必需包已就绪\n")
