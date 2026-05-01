#!/usr/bin/env Rscript
# ============================================
# 森林图 (Forest Plot) — 使用 forestplot 包
# 参考: 腾讯云开发者社区 forestplot 教程
# 左侧: 变量名 | 系数 | P值 | OR/HR (95% CI)
# 右侧: 森林图 (方块 + CI线)
# 导出 PNG + PDF
# medical-statistics skill
# ============================================

#' 生成发表级森林图
#'
#' @param data 数据框，必须含: Variable, Effect, Lower, Upper, P_value
#' @param effect_label 效应标签 ("OR (95% CI)" / "HR (95% CI)" / "beta (95% CI)")
#' @param reference 参考值 (OR/HR=1, beta=0)
#' @param filename_prefix 输出前缀
#' @param title 标题
#' @param footnote 脚注
#'
forest_plot <- function(data, effect_label = "OR (95% CI)", reference = 1,
                        filename_prefix = "forest", title = NULL, footnote = NULL) {

  # ── 加载/安装 forestplot ──
  if (!requireNamespace("forestplot", quietly = TRUE)) {
    install.packages("forestplot", repos = "https://cran.r-project.org")
  }
  library(forestplot)
  library(grid)

  # 参数校验
  required_cols <- c("Variable", "Effect", "Lower", "Upper")
  missing <- setdiff(required_cols, names(data))
  if (length(missing) > 0) {
    stop("数据缺少必需列: ", paste(missing, collapse = ", "))
  }

  df <- data
  n <- nrow(df)

  # ── 准备显示文本 ──
  # 效应值文本: OR/HR = 1.234 (1.012-1.456)
  eff_text <- sprintf("%.3f (%.3f–%.3f)", df$Effect, df$Lower, df$Upper)

  # P值文本
  p_text <- ifelse(df$P_value < 0.001, "<0.001",
                   sprintf("%.3f", round(df$P_value, 3)))

  # 系数文本（OR/HR 用 log 尺度显示系数）
  if (reference == 1) {
    coef_text <- sprintf("%.3f", log(df$Effect))
  } else {
    coef_text <- sprintf("%.3f", df$Effect)
  }

  # ── 表头 ──
  # 根据效应类型设置表头
  if (reference == 1) {
    header_coef <- "log(OR/HR)"
    header_eff  <- effect_label
  } else {
    header_coef <- "Coefficient"
    header_eff  <- "beta (95% CI)"
  }

  # 构建 labeltext 矩阵（四列: 变量名, 系数, P值, 效应值）
  tabletext <- cbind(
    c(NA, "Variable", df$Variable),
    c(NA, header_coef, coef_text),
    c(NA, "P value", p_text),
    c(NA, header_eff, eff_text)
  )

  # ── 颜色 ──
  # 参考文章: box = "#D55E00", lines = "#CC79A7", zero = "gray50"
  fp_col <- fpColors(
    box    = "#2166ac",
    lines  = "#4393c3",
    zero   = "gray50",
    hrz_lines = "#333333"
  )

  # ── 确定图形位置和 X 轴范围 ──
  if (reference == 1) {
    # OR/HR: 对数尺度
    x_ticks <- pretty(c(df$Lower, df$Upper, reference), n = 5)
    x_ticks <- x_ticks[x_ticks > 0]
  } else {
    x_ticks <- pretty(c(df$Lower, df$Upper, reference), n = 5)
  }

  # ── 水平分割线 ──
  hrzl <- list("2" = gpar(lwd = 1.5, col = "#333333"))
  # 最后一行下方
  hrzl[[as.character(n + 2)]] <- gpar(lwd = 1.5, col = "#333333")

  # ── 绘制森林图 ──
  p <- forestplot(
    labeltext  = tabletext,
    mean       = c(NA, NA, df$Effect),
    lower      = c(NA, NA, df$Lower),
    upper      = c(NA, NA, df$Upper),
    is.summary = c(TRUE, TRUE, rep(FALSE, n)),

    # 图形位置（第4列之后）
    graph.pos = 4,

    # 颜色
    col = fp_col,

    # X轴
    zero    = reference,
    xlab    = effect_label,
    xticks  = x_ticks,
    xlog    = (reference == 1),

    # CI 线样式
    boxsize       = 0.15,
    lwd.ci        = 1.5,
    ci.vertices   = TRUE,
    ci.vertices.height = 0.08,

    # 行高和图宽
    lineheight = unit(0.8, "cm"),
    graphwidth = unit(0.35, "npc"),
    colgap     = unit(4, "mm"),

    # 字体
    txt_gp = fpTxtGp(
      label   = gpar(fontfamily = "serif", cex = 0.85),
      ticks   = gpar(fontfamily = "serif", cex = 0.8),
      xlab    = gpar(fontfamily = "serif", cex = 0.9, fontface = "bold"),
      title   = gpar(fontfamily = "serif", cex = 1, fontface = "bold")
    ),

    # 分割线
    hrzl_lines = hrzl,

    # 标题
    title = if (!is.null(title)) title else "",

    # 边距
    mar = unit(c(0, 0, 0, 0), "mm"),

    # 不显示 ICE (influence curve)
    fn.ci_norm = fpDrawCircleCI,

    # 抑制冗余输出
    new_page = TRUE
  )

  # ── 导出 ──
  cat(sprintf("\n  📊 生成森林图: %s\n",
              if (!is.null(title)) title else filename_prefix))

  # PNG: 使用 grDevices 的 png() 设备
  png_file <- paste0(filename_prefix, ".png")
  png(png_file, width = 3000, height = max(1200, n * 200 + 600), res = 300)
  attr(p, "forestplot") <- NULL  # 防止双重复制

  # 重新绘制
  forestplot(
    labeltext  = tabletext,
    mean       = c(NA, NA, df$Effect),
    lower      = c(NA, NA, df$Lower),
    upper      = c(NA, NA, df$Upper),
    is.summary = c(TRUE, TRUE, rep(FALSE, n)),
    graph.pos  = 4,
    col        = fp_col,
    zero       = reference,
    xlab       = effect_label,
    xticks     = x_ticks,
    xlog       = (reference == 1),
    boxsize    = 0.15,
    lwd.ci     = 1.5,
    ci.vertices = TRUE,
    ci.vertices.height = 0.08,
    lineheight = unit(0.8, "cm"),
    graphwidth = unit(0.35, "npc"),
    colgap     = unit(4, "mm"),
    txt_gp = fpTxtGp(
      label   = gpar(fontfamily = "serif", cex = 0.85),
      ticks   = gpar(fontfamily = "serif", cex = 0.8),
      xlab    = gpar(fontfamily = "serif", cex = 0.9, fontface = "bold"),
      title   = gpar(fontfamily = "serif", cex = 1, fontface = "bold")
    ),
    hrzl_lines = hrzl,
    title = if (!is.null(title)) title else "",
    mar = unit(c(0, 0, 0, 0), "mm"),
    fn.ci_norm = fpDrawCircleCI,
    new_page = TRUE
  )
  invisible(dev.off())
  cat(sprintf("  ✔ PNG: %s\n", normalizePath(png_file)))

  # PDF
  pdf_file <- paste0(filename_prefix, ".pdf")
  pdf(pdf_file, width = 12, height = max(4, n * 0.65 + 2))
  # 重新绘制
  forestplot(
    labeltext  = tabletext,
    mean       = c(NA, NA, df$Effect),
    lower      = c(NA, NA, df$Lower),
    upper      = c(NA, NA, df$Upper),
    is.summary = c(TRUE, TRUE, rep(FALSE, n)),
    graph.pos  = 4,
    col        = fp_col,
    zero       = reference,
    xlab       = effect_label,
    xticks     = x_ticks,
    xlog       = (reference == 1),
    boxsize    = 0.15,
    lwd.ci     = 1.5,
    ci.vertices = TRUE,
    ci.vertices.height = 0.08,
    lineheight = unit(0.8, "cm"),
    graphwidth = unit(0.35, "npc"),
    colgap     = unit(4, "mm"),
    txt_gp = fpTxtGp(
      label   = gpar(fontfamily = "serif", cex = 0.85),
      ticks   = gpar(fontfamily = "serif", cex = 0.8),
      xlab    = gpar(fontfamily = "serif", cex = 0.9, fontface = "bold"),
      title   = gpar(fontfamily = "serif", cex = 1, fontface = "bold")
    ),
    hrzl_lines = hrzl,
    title = if (!is.null(title)) title else "",
    mar = unit(c(0, 0, 0, 0), "mm"),
    fn.ci_norm = fpDrawCircleCI,
    new_page = TRUE
  )
  invisible(dev.off())
  cat(sprintf("  ✔ PDF: %s\n", normalizePath(pdf_file)))

  # PNG 副本（低分辨率预览）
  return(invisible(p))
}

#' 从多因素模型结果生成森林图（便利函数）
forest_plot_from_model <- function(result_df, model_type, ts = NULL) {
  if (is.null(ts)) ts <- format(Sys.time(), "%Y%m%d_%H%M%S")

  effect_label <- switch(model_type,
    "linear"   = "beta (95% CI)",
    "cox"      = "HR (95% CI)",
    "logistic" = "OR (95% CI)",
    "OR (95% CI)"
  )
  reference <- if (model_type == "linear") 0 else 1
  title_map <- c(linear = "Linear Regression", logistic = "Logistic Regression",
                 cox = "Cox Proportional Hazards")

  prefix <- paste0("forest_", model_type, "_", ts)
  forest_plot(result_df,
              effect_label = effect_label,
              reference    = reference,
              filename_prefix = prefix,
              title = sprintf("Forest Plot: %s", title_map[model_type]))
  return(prefix)
}

if (sys.nframe() == 0) {
  cat("✔ forest_plot.R loaded (forestplot package)\n")
}
