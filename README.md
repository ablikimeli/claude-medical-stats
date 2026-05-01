# medical-statistics

医学统计分析 Claude Code Skill

## 功能

- ✅ **正态性检验**：自动判断连续变量的分布类型
- ✅ **Table 1 基线特征表**：单因素分析，输出标准三线表
- ✅ **多因素回归**：支持 Logistic / Cox / 线性回归
- ✅ **限制性立方样条 (RCS)**：探索连续变量与结局的非线性关系
- ✅ **用户交互**：每步方法选择都征求用户意见，支持自定义方法

## 安装

```bash
# 克隆到 Claude Code skills 目录
git clone https://github.com/ablikimeli/medical-statistics.git ~/.claude/skills/medical-statistics

# 或在项目中使用
git clone https://github.com/ablikimeli/medical-statistics.git .claude/skills/medical-statistics
```

## 使用

在 Claude Code 中发送以下命令触发：

```
/medical-statistics
```

或直接提出统计分析需求，Skill 会自动触发。

## 依赖

需要 R (≥ 4.0) 和以下 R 包：
- tableone, rms, Hmisc, ggplot2
- dplyr, tidyr, haven, readxl
- survival, survminer, splines

## 目录结构

```
medical-statistics/
├── SKILL.md           # 主技能定义
├── FORMS.md           # 交互模板
├── scripts/           # R 分析脚本
│   ├── normality_test.R
│   ├── table_one.R
│   ├── multivariate_analysis.R
│   └── rcs_analysis.R
├── references/        # 参考文档
│   ├── statistical_methods_reference.md
│   └── rcs_guide.md
└── evals/             # 测试用例
```

## 作者

[ablikimeli](https://github.com/ablikimeli)
