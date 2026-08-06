# GBD 2019 下载与跨版本稳健性分析说明

## 当前状态

- `E:\药物滥用\数据16\数据16` 文件夹内只有 **GBD 2021** 数据，没有 GBD 2019。
- 因此真正的“跨版本稳健性”（GBD 2019 vs. GBD 2021）仍需补充 GBD 2019 数据。
- 已准备就绪脚本：`run_gbd2019_vs_2021_robustness.py`。

## 如何获取 GBD 2019 数据

1. 打开 IHME GBD Results Tool：
   <https://vizhub.healthdata.org/gbd-results/>

2. 点击 **Download results**（可能需要免费注册/登录）。

3. 在下载界面选择：
   - **GBD version**：GBD 2019
   - **Location**：Select all countries（或仅选 47 个 DODJI 国家）
   - **Cause**：
     - 主分析：Drug use disorders
     - 可选：Opioid use disorders（如需与 GBD 2021 的 opioid-only 稳健性对应）
   - **Measure**：Deaths
   - **Metric**：Rate
   - **Age**：Age-standardized
   - **Sex**：Both
   - **Year**：1990–2019

4. 下载 CSV 文件（通常命名为 `IHME-GBD_2019_DATA-xxxxxxxx-x.csv`）。

5. 将 CSV 文件放到：
   ```
   E:\药物滥用\GBD_2019\
   ```
   或修改 `run_gbd2019_vs_2021_robustness.py` 中的 `GBD_2019_FILE` / `GBD_2019_DIR` 路径。

## 运行跨版本稳健性分析

```bash
cd C:\Users\fhj\DODJI_Lancet_v15_submission
C:\Users\fhj\AppData\Local\Programs\Python\Python313\python.exe run_gbd2019_vs_2021_robustness.py
```

## 输出文件

运行成功后将生成：

- `results_v17/gbd2019_vs_2021_robustness_summary.csv`  
  包含 Spearman 相关系数、regime 稳定性、Priority-I Jaccard 指数等。
- `results_v17/gbd2019_vs_2021_country_ranks.csv`  
  每个国家在 GBD 2019 与 GBD 2021 下的 DODJI 分数、排名及排名变化。
- `results_v17/gbd2019_vs_2021_regime_comparison.csv`  
  GBD 2019 与 GBD 2021 的 regime 交叉表。

## 预期解读

- 若 Spearman ρ 较高（例如 >0.70），说明 DODJI 对 GBD 版本选择不敏感，跨版本稳健性良好。
- 若 ρ 较低，则需在论文中说明 DODJI 结果受 GBD 版本更新影响，并讨论可能原因（如模型方法、 covariate 选择、死因分类调整等）。
