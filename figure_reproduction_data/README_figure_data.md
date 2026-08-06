# Figure 1–7 复现数据说明

本目录提供用于直接复现 Python 版 Figure 1–7 的全部 CSV 作图数据。

## 文件清单与对应关系

| 文件名 | 对应图 | 行数 × 列数 | 关键变量 |
|--------|--------|-------------|----------|
| `Figure1_composite_data.csv` | Figure 1 复合图（面板 e/f、四象限等） | 47 × 7 | `country`, `mortality_rank`, `dodji_score`, `priority_score`, `combined_priority_rank`, `regime`, `reclassification_direction` |
| `Figure1a_mortality_burden.csv` | Figure 1a（国家死亡率负担地图） | 47 × 5 | `country`, `map_join_name`, `is_microstate`, `mortality_level`, `mortality_rank` |
| `Figure1b_DODJI_surveillance_credibility.csv` | Figure 1b（DODJI 可信度地图） | 47 × 6 | `country`, `map_join_name`, `is_microstate`, `dodji_score`, `dodji_tier`, `surveillance_gap` |
| `Figure1c_priority_disagreement.csv` | Figure 1c（优先级重排地图） | 47 × 6 | `country`, `map_join_name`, `is_microstate`, `rank_shift_up`, `mortality_rank`, `combined_priority_rank` |
| `Figure2_priority_reordering.csv` | Figure 2（优先级重排：斜率图、汇总、层级、直方图） | 47 × 6 | `country`, `mortality_rank`, `combined_priority_rank`, `rank_shift`, `reclassification`, `regime` |
| `Figure3_governance_landscape.csv` | Figure 3（治理格局：散点、regime tiles、分面、vignettes、DODJI by regime） | 47 × 7 | 同 Figure1_composite_data，用于 regime 分析 |
| `Figure4_evidence_stress_test.csv` | Figure 4（证据压力测试： diverging bars + asterisks） | 10 × 6 | `domain`, `metric`, `value`, `p_value`, `n`, `interpretation` |
| `Figure5_minimum_surveillance_package.csv` | Figure 5（最低监测包蓝图：矩阵、序列、regime 匹配） | 11 × 3 | `maturity_stage`, `component`, `capability` |
| `Figure6_mechanism_regression_results.csv` | Figure 6a（机制森林图） | 6 × 6 | `predictor`, `beta`, `se`, `p_value`, `p_bonferroni`, `p_bh` |
| `Figure6_predictive_validation_results.csv` | Figure 6b（预测验证森林图） | 4 × 7 | `model`, `n_obs`, `n_countries`, `beta`, `se`, `p`, `r2` |
| `Figure7_robustness_correlations.csv` | Figure 7（稳健性相关图） | 9 × 4 | `variant`, `rho`, `n`, `description` |

## 复现代码

完整复现脚本位于项目根目录：

```text
../create_figures_python_nature.py
```

该脚本读取 `../figures_v21_authoritative/source_data/` 下的同名 CSV，输出：

- 7 张主图：`../figures_python_nature/Figure*.svg/pdf/png`
- 30 个独立子面板：`../figures_python_nature_panels/`

## 地图数据特别说明

Figure 1a/1b/1c 为**世界地图**。CSV 中只包含每个国家的数值；地图几何边界需要额外下载：

- **Natural Earth 110m Cultural Vectors**（Admin-0 countries）
- 下载地址：https://www.naturalearthdata.com/downloads/110m-cultural-vectors/
- 当前脚本会自动下载并缓存到 `../data/ne_110m_admin_0_countries/`

如果使用本目录的 CSV 自行复现地图，请确保 `map_join_name` 列与 Natural Earth 的 `ADMIN` 或 `NAME` 字段匹配。

## 数据版本

- CSV 来源：`figures_v21_authoritative/source_data/` 与 `submission/figure1abc_single_panel_data/`
- 对应 Python 图版：`create_figures_python_nature.py` 最新生成的 Figure 1–7
