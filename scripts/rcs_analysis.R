#!/usr/bin/env Rscript
# ============================================
# 限制性立方样条（RCS）分析
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

if (is.null(params$knots)) params$knots <- 4
if (is.null(params$type)) params$type <- "logistic"

# 读取数据
ext <- tolower(tools::file_ext(params$data))
if (ext == "csv") {
  df <- read.csv(params$data, stringsAsFactors = FALSE)
} else if (ext %in% c("xls", "xlsx")) {
  df <- read_excel(params$data)
} else if (ext %in% c("sav")) {
  df <- read_sav(params$data)
} else if (ext %in% c("dta")) {
  df <- read_dta(params$data)
} else {
  stop("不支持的文件格式: ", ext)
}

# 处理缺失值
df <- df[complete.cases(df[, c(params$outcome, params$continuous, params$covariates)]), ]

cat("\n═══════════════════════════════════════════\n")
cat("    限制性立方样条 (RCS) 分析\n")
cat("═══════════════════════════════════════════\n\n")

x_var <- params$continuous
cat(sprintf("连续变量: %s\n", x_var))
cat(sprintf("结局变量: %s\n", params$outcome))
cat(sprintf("节点数: %d\n", params$knots))

# 设置 rms 环境
dd <- datadist(df)
options(datadist = "dd")

# 确定节点位置（默认在固定分位数）
knot_locations <- quantile(df[[x_var]], probs = seq(0, 1, length.out = params$knots + 2)[-c(1, params$knots + 2)])
# 如果节点位置有重复，调整
if (any(duplicated(knot_locations))) {
  params$knots <- params$knots - 1
  knot_locations <- quantile(df[[x_var]], probs = seq(0, 1, length.out = params$knots + 2)[-c(1, params$knots + 2)])
}
cat(sprintf("节点位置 (k=%d): %s\n\n", params$knots, paste(round(knot_locations, 2), collapse = ", ")))

# 构建 RCS 模型
if (params$type == "logistic") {
  df[[params$outcome]] <- as.factor(df[[params$outcome]])

  if (is.null(params$covariates) || length(params$covariates) == 0) {
    formula_rcs <- as.formula(paste(params$outcome, "~ rcs(", x_var, ",", params$knots, ")"))
    formula_linear <- as.formula(paste(params$outcome, "~", x_var))
  } else {
    cov_str <- paste(params$covariates, collapse = " + ")
    formula_rcs <- as.formula(paste(params$outcome, "~ rcs(", x_var, ",", params$knots, ") +", cov_str))
    formula_linear <- as.formula(paste(params$outcome, "~", x_var, "+", cov_str))
  }

  model_rcs <- lrm(formula_rcs, data = df, x = TRUE, y = TRUE)
  model_linear <- lrm(formula_linear, data = df, x = TRUE, y = TRUE)

} else if (params$type == "cox") {
  if (is.null(params$time)) stop("Cox回归需要指定 --time")

  if (is.null(params$covariates) || length(params$covariates) == 0) {
    formula_rcs <- as.formula(paste0("Surv(", params$time, ", ", params$outcome, ") ~ rcs(", x_var, ",", params$knots, ")"))
    formula_linear <- as.formula(paste0("Surv(", params$time, ", ", params$outcome, ") ~ ", x_var))
  } else {
    cov_str <- paste(params$covariates, collapse = " + ")
    formula_rcs <- as.formula(paste0("Surv(", params$time, ", ", params$outcome, ") ~ rcs(", x_var, ",", params$knots, ") +", cov_str))
    formula_linear <- as.formula(paste0("Surv(", params$time, ", ", params$outcome, ") ~ ", x_var, "+", cov_str))
  }

  model_rcs <- cph(formula_rcs, data = df, x = TRUE, y = TRUE)
  model_linear <- cph(formula_linear, data = df, x = TRUE, y = TRUE)
}

# 非线性检验
lrt <- anova(model_rcs)
if (!is.null(model_linear)) {
  lr_stat <- -2 * (logLik(model_linear) - logLik(model_rcs))
  lr_p <- pchisq(as.numeric(lr_stat), df = params$knots - 1, lower.tail = FALSE)
} else {
  lr_p <- NA
}

cat("━━━ 非线性检验结果 ━━━\n")
cat(sprintf("  整体检验 P = %.4f\n", lrt[grep(x_var, rownames(lrt)), "P"]))
cat(sprintf("  非线性检验 P = %.4f\n", lrt[grep("Nonlinear", rownames(lrt)), "P"]))
if (!is.null(model_linear) && !is.na(lr_p)) {
  cat(sprintf("  Likelihood Ratio 检验 P = %.4f\n", lr_p))
}

is_nonlinear <- FALSE
if (lrt[grep("Nonlinear", rownames(lrt)), "P"] < 0.05) {
  cat("  ✅ 存在显著非线性关系 (P < 0.05)\n")
  is_nonlinear <- TRUE
} else {
  cat("  ❌ 未检测到显著非线性关系 (P ≥ 0.05)\n")
}

# 预测
x_range <- seq(min(df[[x_var]], na.rm = TRUE), max(df[[x_var]], na.rm = TRUE), length.out = 100)
newdata <- data.frame(x = x_range)
names(newdata)[1] <- x_var

# 如果有协变量，设置为均值
if (!is.null(params$covariates)) {
  for (cov in params$covariates) {
    if (is.numeric(df[[cov]])) {
      newdata[[cov]] <- mean(df[[cov]], na.rm = TRUE)
    } else {
      newdata[[cov]] <- names(sort(table(df[[cov]]), decreasing = TRUE))[1]
    }
  }
}

pred <- predict(model_rcs, newdata, se.fit = TRUE)

# 计算 OR/HR 和 95% CI
if (params$type %in% c("logistic", "cox")) {
  ref_value <- median(df[[x_var]], na.rm = TRUE)
  ref_pred <- predict(model_rcs, data.frame(x = ref_value, newdata[1, -1, drop = FALSE]), se.fit = TRUE)

  or_values <- exp(pred$linear.predictors - ref_pred$linear.predictors)
  or_se <- pred$se.fit  # 近似

  plot_data <- data.frame(
    x = x_range,
    OR = exp(pred$linear.predictors - ref_pred$linear.predictors),
    Lower = exp(pred$linear.predictors - ref_pred$linear.predictors - 1.96 * pred$se.fit),
    Upper = exp(pred$linear.predictors - ref_pred$linear.predictors + 1.96 * pred$se.fit)
  )
} else {
  plot_data <- data.frame(
    x = x_range,
    y = pred$linear.predictors,
    Lower = pred$linear.predictors - 1.96 * pred$se.fit,
    Upper = pred$linear.predictors + 1.96 * pred$se.fit
  )
}

# 找到拐点（一阶导数为0的点）
if (is_nonlinear) {
  cat("\n━━━ 拐点分析 ━━━\n")
  # 简单的拐点检测：预测值变化率改变符号的点
  diffs <- diff(plot_data$OR) * diff(plot_data$x)
  for (i in 2:(length(diffs) - 1)) {
    if (sign(diffs[i]) != sign(diffs[i + 1])) {
      cat(sprintf("  潜在拐点: %s = %.2f\n", x_var, plot_data$x[i + 1]))
    }
  }
}

# 绘制 RCS 图
cat("\n━━━ 生成RCS图 ━━━\n")

if (params$type %in% c("logistic", "cox")) {
  p <- ggplot(plot_data, aes(x = x, y = OR)) +
    geom_line(color = "#2c3e50", linewidth = 1.2) +
    geom_ribbon(aes(ymin = Lower, ymax = Upper), fill = "#3498db", alpha = 0.2) +
    geom_hline(yintercept = 1, linetype = "dashed", color = "red", linewidth = 0.8) +
    geom_rug(data = df, aes(x = .data[[x_var]], y = NULL), sides = "b", alpha = 0.3) +
    labs(
      title = sprintf("限制性立方样条: %s 与 %s 的关系", x_var, params$outcome),
      subtitle = sprintf("节点数 k=%d | 非线性检验 P=%.4f",
                         params$knots, lrt[grep("Nonlinear", rownames(lrt)), "P"]),
      x = x_var,
      y = ifelse(params$type == "logistic", "OR (95% CI)", "HR (95% CI)")
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5, color = "gray40"),
      panel.grid.minor = element_blank()
    )
} else {
  p <- ggplot(plot_data, aes(x = x, y = y)) +
    geom_line(color = "#2c3e50", linewidth = 1.2) +
    geom_ribbon(aes(ymin = Lower, ymax = Upper), fill = "#3498db", alpha = 0.2) +
    geom_rug(data = df, aes(x = .data[[x_var]], y = NULL), sides = "b", alpha = 0.3) +
    labs(
      title = sprintf("限制性立方样条: %s 与 %s 的关系", x_var, params$outcome),
      subtitle = sprintf("节点数 k=%d | 非线性检验 P=%.4f",
                         params$knots, lrt[grep("Nonlinear", rownames(lrt)), "P"]),
      x = x_var,
      y = "线性预测值"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5, color = "gray40"),
      panel.grid.minor = element_blank()
    )
}

# 保存图片
output_file <- sprintf("rcs_%s_%s.png", params$continuous, params$outcome)
ggsave(output_file, p, width = 8, height = 6, dpi = 300)
cat(sprintf("RCS图已保存: %s\n", output_file))

cat("\n═══════════════════════════════════════════\n")
cat("参考引用:\n")
cat("  Harrell FE. Regression Modeling Strategies. Springer, 2015.\n")
cat("  Durrleman S, Simon R. J Am Stat Assoc. 1989;84:166-175.\n")
cat("═══════════════════════════════════════════\n")
