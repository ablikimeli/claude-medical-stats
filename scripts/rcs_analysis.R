#!/usr/bin/env Rscript
# ============================================
# 限制性立方样条（RCS）分析
# 使用 rcssci 包 (Zhiqiang Nie, 广东省人民医院)
# - rcssci_logistic() / rcssci_cox() / rcssci_linear()
# - 自动输出: 整体关联P值 + 非线性P值
# - 生成4幅发表级PDF图
# - 额外导出预测数据到Excel
# medical-statistics skill
# ============================================

suppressPackageStartupMessages(library(rms))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(readxl))
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)

parse_args <- function(args) {
  params <- list()
  i <- 1
  while (i <= length(args)) {
    if (args[i] == "--data" && i + 1 <= length(args)) {
      params$data <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--outcome" && i + 1 <= length(args)) {
      params$outcome <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--continuous" && i + 1 <= length(args)) {
      params$continuous <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--covariates" && i + 1 <= length(args)) {
      params$covariates <- unlist(strsplit(args[i + 1], ","))
      i <- i + 2
    } else if (args[i] == "--knots" && i + 1 <= length(args)) {
      params$knots <- as.numeric(args[i + 1])
      i <- i + 2
    } else if (args[i] == "--type" && i + 1 <= length(args)) {
      params$type <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--time" && i + 1 <= length(args)) {
      params$time <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--prob" && i + 1 <= length(args)) {
      params$prob <- as.numeric(args[i + 1])
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  return(params)
}

params <- parse_args(args)

if (is.null(params$data) || is.null(params$outcome) || is.null(params$continuous)) {
  stop("请指定: --data <path> --outcome <variable> --continuous <variable>")
}

if (is.null(params$knots)) params$knots <- NA  # NA = 自动AIC选择
if (is.null(params$type)) params$type <- "logistic"
if (is.null(params$prob)) params$prob <- 0.1

# ── 读取数据 ──
ext <- tolower(tools::file_ext(params$data))
df <- switch(ext,
  "csv" = read.csv(params$data, stringsAsFactors = FALSE),
  "xls" = , "xlsx" = read_excel(params$data),
  "sav" = read_sav(params$data),
  "dta" = read_dta(params$data),
  stop("不支持的文件格式: ", ext)
)

x_var <- params$continuous
keep_cols <- c(params$outcome, x_var, params$covariates, params$time)
df <- df[complete.cases(df[, intersect(keep_cols, names(df))]), ]
n_obs <- nrow(df)

# ── 输出标题 ──
cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("        限制性立方样条 (RCS) 分析 — rcssci 包\n")
cat("═══════════════════════════════════════════════════════════════\n\n")
cat(sprintf("  📊 连续变量: %s\n", x_var))
cat(sprintf("  🎯 结局变量: %s\n", params$outcome))
cat(sprintf("  📋 有效样本量: %d\n", n_obs))
cat(sprintf("  变量范围: %.2f – %.2f\n", min(df[[x_var]]), max(df[[x_var]])))

if (!is.na(params$knots)) {
  cat(sprintf("  节点数: %d (用户指定)\n", params$knots))
} else {
  cat("  节点数: 自动选择 (基于AIC)\n")
}

# ── 加载 rcssci ──
if (!requireNamespace("rcssci", quietly = TRUE)) {
  cat("\n  ⚠ rcssci 包未安装，正在安装...\n")
  install.packages("rcssci", repos = "https://cran.r-project.org")
}
library(rcssci)

# ── 创建输出目录 ──
output_dir <- file.path(getwd(), "rcs_output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# ── rcssci 分析 ──
covs <- if (!is.null(params$covariates) && length(params$covariates) > 0) {
  as.list(params$covariates)
} else {
  NULL
}

# rcssci 的 prob 参数: 参考值位置 (0~1), 默认 0.1 (第10百分位数)
cat(sprintf("\n  参考位置 (prob): %.1f (第%.0f百分位数)\n", params$prob, params$prob * 100))

# 使用 tryCatch 包裹以防 rcssci 抛错
rcs_result <- tryCatch({

  if (params$type == "logistic") {
    cat("  模型类型: Logistic 回归\n\n")

    rcssci_logistic(
      data     = df,
      y        = params$outcome,
      x        = x_var,
      covs     = covs,
      prob     = params$prob,
      filepath = output_dir,
      knot     = if (is.na(params$knots)) NA else params$knots
    )

  } else if (params$type == "cox") {
    if (is.null(params$time)) stop("Cox回归需要指定 --time")
    cat("  模型类型: Cox 比例风险回归\n\n")

    rcssci_cox(
      data     = df,
      y        = params$outcome,
      x        = x_var,
      covs     = covs,
      prob     = params$prob,
      filepath = output_dir,
      time     = params$time,
      knot     = if (is.na(params$knots)) NA else params$knots
    )

  } else if (params$type == "linear") {
    cat("  模型类型: 线性回归\n\n")

    rcssci_linear(
      data     = df,
      y        = params$outcome,
      x        = x_var,
      covs     = covs,
      prob     = params$prob,
      filepath = output_dir,
      knot     = if (is.na(params$knots)) NA else params$knots
    )
  }

  TRUE

}, error = function(e) {
  cat(sprintf("\n  ⚠ rcssci 分析出错: %s\n", e$message))
  cat("  回退到 rms::lrm() 手动分析...\n\n")
  return(FALSE)
})

# ── 无论 rcssci 是否成功，都使用 rms 提取 P 值和预测数据 ──
cat("━━━ rms 模型 (P值提取) ━━━\n")

dd <- datadist(df)
options(datadist = "dd")

if (params$type == "logistic") {
  df[[params$outcome]] <- as.factor(df[[params$outcome]])

  if (is.null(params$covariates) || length(params$covariates) == 0) {
    f_rcs <- as.formula(paste(params$outcome, "~ rcs(", x_var, ",",
                              if (is.na(params$knots)) 4 else params$knots, ")"))
    f_lin <- as.formula(paste(params$outcome, "~", x_var))
  } else {
    cov_str <- paste(params$covariates, collapse = " + ")
    k_val <- if (is.na(params$knots)) 4 else params$knots
    f_rcs <- as.formula(paste(params$outcome, "~ rcs(", x_var, ",", k_val, ") +", cov_str))
    f_lin <- as.formula(paste(params$outcome, "~", x_var, "+", cov_str))
  }

  model_rcs <- lrm(f_rcs, data = df, x = TRUE, y = TRUE)
  model_lin <- lrm(f_lin, data = df, x = TRUE, y = TRUE)
  y_label <- "OR (95% CI)"

} else if (params$type == "cox") {
  if (is.null(params$covariates) || length(params$covariates) == 0) {
    f_rcs <- as.formula(paste0("Surv(", params$time, ", ", params$outcome,
                               ") ~ rcs(", x_var, ",",
                               if (is.na(params$knots)) 4 else params$knots, ")"))
    f_lin <- as.formula(paste0("Surv(", params$time, ", ", params$outcome, ") ~ ", x_var))
  } else {
    cov_str <- paste(params$covariates, collapse = " + ")
    k_val <- if (is.na(params$knots)) 4 else params$knots
    f_rcs <- as.formula(paste0("Surv(", params$time, ", ", params$outcome,
                               ") ~ rcs(", x_var, ",", k_val, ") +", cov_str))
    f_lin <- as.formula(paste0("Surv(", params$time, ", ", params$outcome,
                               ") ~ ", x_var, "+", cov_str))
  }

  model_rcs <- cph(f_rcs, data = df, x = TRUE, y = TRUE)
  model_lin <- cph(f_lin, data = df, x = TRUE, y = TRUE)
  y_label <- "HR (95% CI)"

} else {
  # linear
  if (is.null(params$covariates) || length(params$covariates) == 0) {
    f_rcs <- as.formula(paste(params$outcome, "~ rcs(", x_var, ",",
                              if (is.na(params$knots)) 4 else params$knots, ")"))
  } else {
    cov_str <- paste(params$covariates, collapse = " + ")
    k_val <- if (is.na(params$knots)) 4 else params$knots
    f_rcs <- as.formula(paste(params$outcome, "~ rcs(", x_var, ",", k_val, ") +", cov_str))
  }
  model_rcs <- ols(f_rcs, data = df, x = TRUE, y = TRUE)
  model_lin <- NULL
  y_label <- "beta (95% CI)"
}

# ── 方差分析 / P值提取 ──
lrt_anova <- anova(model_rcs)
row_names <- rownames(lrt_anova)
idx_total <- grep(x_var, row_names)[1]
idx_nonlin <- grep("Nonlinear", row_names, ignore.case = TRUE)

p_overall <- if (!is.na(idx_total) && idx_total <= nrow(lrt_anova)) lrt_anova[idx_total, "P"] else NA
p_nonlin  <- if (!is.na(idx_nonlin) && idx_nonlin <= nrow(lrt_anova)) lrt_anova[idx_nonlin, "P"] else NA

# 似然比检验 (RCS vs Linear)
if (!is.null(model_lin) && !inherits(model_lin, "try-error")) {
  lr_stat <- abs(2 * (model_rcs$stats["Model L.R."] - model_lin$stats["Model L.R."]))
  lr_df <- if (is.na(params$knots)) 3 else params$knots - 1
  lr_p <- pchisq(as.numeric(lr_stat), df = lr_df, lower.tail = FALSE)
} else {
  lr_stat <- NA; lr_p <- NA
}

# ── 输出 P 值结果 ──
cat(sprintf("\n  ┌───────────────────────────────────────────────┐\n"))
cat(sprintf("  │  整体关联检验 (Overall)       P = %.4f      │\n", p_overall))
cat(sprintf("  │  非线性检验 (Nonlinear)       P = %.4f      │\n", p_nonlin))
if (!is.na(lr_p)) {
  cat(sprintf("  │  似然比检验 (RCS vs Linear)   P = %.4f      │\n", lr_p))
}
cat(sprintf("  └───────────────────────────────────────────────┘\n"))

is_nonlinear <- !is.na(p_nonlin) && p_nonlin < 0.05
cat(ifelse(is_nonlinear,
  "\n  ✅ 存在显著非线性关系 (P < 0.05)\n",
  "\n  ❌ 未检测到显著非线性关系 (P ≥ 0.05)\n"))
cat("  注: 统计显著性需结合临床意义判断 (BMJ reviewer note)\n")

# ── rcssci 输出文件报告 ──
if (isTRUE(rcs_result)) {
  cat("\n━━━ rcssci 输出文件 ────────────────────────\n")
  pdf_files <- list.files(output_dir, pattern = "\\.(pdf|PDF)$", full.names = TRUE)
  if (length(pdf_files) > 0) {
    cat(sprintf("  共生成 %d 个PDF文件:\n", length(pdf_files)))
    for (f in pdf_files) {
      cat(sprintf("    ✔ %s\n", f))
    }
    # 复制到工作目录
    for (f in pdf_files) {
      file.copy(f, file.path(getwd(), basename(f)), overwrite = TRUE)
      cat(sprintf("  ✔ 已复制到工作目录: %s\n", basename(f)))
    }
  }
}

# ── rms 预测数据导出到 Excel ──
cat("\n━━━ 预测数据导出 ───────────────────────────\n")

# 使用 Predict() 获取预测值
if (requireNamespace("rms", quietly = TRUE)) {
  tryCatch({
    pred_seq <- seq(min(df[[x_var]], na.rm = TRUE),
                    max(df[[x_var]], na.rm = TRUE), length.out = 200)

    pred_rcs <- if (params$type %in% c("logistic", "cox")) {
      Predict(model_rcs, name = x_var, fun = exp, ref.zero = TRUE, conf.int = 0.95)
    } else {
      Predict(model_rcs, name = x_var, ref.zero = TRUE, conf.int = 0.95)
    }

    plot_df <- as.data.frame(pred_rcs)
    names(plot_df)[names(plot_df) == "yhat"] <- "Effect"
    names(plot_df)[names(plot_df) == "lower"] <- "Lower"
    names(plot_df)[names(plot_df) == "upper"] <- "Upper"
    names(plot_df)[names(plot_df) == x_var] <- "x"

    suppressPackageStartupMessages(library(openxlsx))
    excel_file <- paste0("rcs_", params$continuous, "_predictions.xlsx")
    write.xlsx(plot_df, excel_file, overwrite = TRUE)
    cat(sprintf("  ✔ 预测数据 (Excel): %s\n", normalizePath(excel_file)))
  }, error = function(e) {
    cat(sprintf("  ⚠ 预测数据导出失败: %s\n", e$message))
  })
}

# ── 生成一个简单的 ggplot RCS 图（PNG 预览） ──
cat("\n━━━ RCS 预览图 (PNG) ───────────────────────\n")
tryCatch({
  pred_seq <- seq(min(df[[x_var]], na.rm = TRUE),
                  max(df[[x_var]], na.rm = TRUE), length.out = 200)

  pred_rcs <- if (params$type %in% c("logistic", "cox")) {
    Predict(model_rcs, name = x_var, fun = exp, ref.zero = TRUE, conf.int = 0.95)
  } else {
    Predict(model_rcs, name = x_var, ref.zero = TRUE, conf.int = 0.95)
  }

  plot_df <- as.data.frame(pred_rcs)
  names(plot_df)[names(plot_df) == "yhat"] <- "Effect"
  names(plot_df)[names(plot_df) == "lower"] <- "Lower"
  names(plot_df)[names(plot_df) == "upper"] <- "Upper"
  names(plot_df)[names(plot_df) == x_var] <- "x"

  # 确定y轴标签
  y_lab <- if (params$type %in% c("logistic", "cox")) {
    ifelse(params$type == "logistic", "OR (95% CI)", "HR (95% CI)")
  } else {
    "beta (95% CI)"
  }

  ref_val <- median(df[[x_var]], na.rm = TRUE)
  ref_line <- if (params$type == "linear") 0 else 1

  p_gg <- ggplot(plot_df, aes(x = x, y = Effect)) +
    geom_ribbon(aes(ymin = Lower, ymax = Upper), fill = "#2166ac", alpha = 0.18) +
    geom_line(color = "#2c3e50", linewidth = 1.3) +
    geom_hline(yintercept = ref_line, linetype = "dashed", color = "#b2182b", linewidth = 0.8) +
    geom_vline(xintercept = ref_val, linetype = "dotted", color = "gray40", linewidth = 0.7) +
    labs(
      title = sprintf("RCS: %s 与 %s 的关系", x_var, params$outcome),
      subtitle = sprintf("整体 P=%.4f | 非线性 P=%.4f | N=%d",
                         p_overall, p_nonlin, n_obs),
      x = x_var, y = y_lab
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5, color = "gray40"),
      panel.grid.minor = element_blank(),
      panel.border = element_rect(fill = NA, color = "gray80", linewidth = 0.5)
    )

  # 导出PNG
  png_file <- paste0("rcs_", params$continuous, "_preview.png")
  ggsave(png_file, p_gg, width = 8, height = 6, dpi = 300)
  cat(sprintf("  ✔ 预览PNG: %s\n", normalizePath(png_file)))

}, error = function(e) {
  cat(sprintf("  ⚠ 预览图生成失败: %s\n", e$message))
})

cat("\n═══════════════════════════════════════════════════════════════\n")
cat("参考引用:\n")
cat("  rcssci: Nie Z. Visualization of Restricted Cubic Splines. CRAN.\n")
cat("  Harrell FE. Regression Modeling Strategies, 2nd ed. Springer, 2015.\n")
cat("═══════════════════════════════════════════════════════════════\n")
