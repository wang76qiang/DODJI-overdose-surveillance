# -*- coding: utf-8 -*-
"""Generate supplementary figures S1-S3 (matplotlib, Okabe-Ito palette matching main figures)."""
import sys
sys.stdout.reconfigure(encoding='utf-8')
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from scipy import stats

plt.rcParams.update({
    'font.family': 'Arial', 'font.size': 7.5, 'axes.linewidth': 0.6,
    'axes.titlesize': 8, 'axes.titleweight': 'bold', 'axes.labelsize': 7.5,
    'xtick.labelsize': 6.5, 'ytick.labelsize': 6.5, 'legend.fontsize': 6.5,
    'svg.fonttype': 'none', 'pdf.fonttype': 42,
})
INK, MID = '#272727', '#767676'
REGIME_COLORS = {'Medical-system-driven': '#0072B2', 'Low-burden / protected': '#009E73',
                 'Data-quality-limited': '#E69F00', 'Insufficient exposure data': '#D55E00'}
OUT = 'figures_redraw_nature_v2/r'
MM = 1/25.4

def strip(ax):
    for s in ('top', 'right'):
        ax.spines[s].set_visible(False)

# ================= Figure S1: annual DODJI trajectories =================
panel = pd.read_csv('results_v17/annual_dodji_panel.csv')
recl = pd.read_csv('results_v17/reclassification_table_v17.csv')
reg_map = dict(zip(recl.country, recl.typology))
panel['regime'] = panel.country.map(reg_map).fillna('Additional (predictive sample)')

order = ['Medical-system-driven', 'Low-burden / protected', 'Data-quality-limited',
         'Insufficient exposure data', 'Additional (predictive sample)']
fig, axes = plt.subplots(2, 3, figsize=(183*MM, 100*MM), sharex=True, sharey=True)
axes = axes.flatten()
for i, reg in enumerate(order):
    ax = axes[i]
    sub = panel[panel.regime == reg]
    col = REGIME_COLORS.get(reg, '#999999')
    for ctry, g in sub.groupby('country'):
        g = g.sort_values('year')
        ax.plot(g.year, g.dodji_annual, color=col, lw=0.5, alpha=0.45)
    mean = sub.groupby('year').dodji_annual.mean()
    ax.plot(mean.index, mean.values, color=INK, lw=1.2)
    ax.axhline(0, color=MID, lw=0.5, ls=(0, (3, 2)))
    n = sub.country.nunique()
    label = {'Low-burden / protected': 'Low-burden/\nprotected',
             'Insufficient exposure data': 'Insufficient\nexposure data',
             'Additional (predictive sample)': 'Additional 16 countries\n(predictive sample only)'}.get(reg, reg)
    ax.set_title(f'{label}  (n={n})', loc='left', color=col if reg in REGIME_COLORS else INK)
    ax.set_xticks([1995, 2005, 2015])
    strip(ax)
    if i % 3 == 0:
        ax.set_ylabel('Annual DODJI')
    if i >= 3:
        ax.set_xlabel('Year')
axes[5].axis('off')
fig.suptitle('')
fig.tight_layout(w_pad=1.2, h_pad=1.4)
fig.savefig(f'{OUT}/Supplementary_FigureS1_annual_dodji_trajectories.png', dpi=600)
fig.savefig(f'{OUT}/Supplementary_FigureS1_annual_dodji_trajectories.pdf')
plt.close(fig)
print('S1 saved')

# ================= Figure S2: variant scatters =================
cross = pd.read_csv('results_v17/who_gbd_cross_source_dodji.csv')          # n=30
nongbd = pd.read_csv('results_v17/non_gbd_dodji_variant.csv')[['country', 'dodji_score', 'non_gbd_dodji']].dropna()
age = pd.read_csv('results_v17/gbd2021_ageband_country_scores.csv')        # n=37

panels = [
    ('a', 'WHO\u2013GBD cross-source variant', cross.primary_dodji, cross.who_gbd_dodji, 'Primary DODJI', 'WHO\u2013GBD variant'),
    ('b', 'Civil-registration-proxy variant', nongbd.dodji_score, nongbd.non_gbd_dodji, 'Primary DODJI', 'Non-GBD proxy variant'),
    ('c', 'Age-band variant (15\u201349 years)', age.primary_dodji, age['15-49 years'], 'Primary DODJI', 'Age-band DODJI'),
    ('d', 'Age-band variant (65+ years)', age.primary_dodji, age['65+ years'], 'Primary DODJI', 'Age-band DODJI'),
]
fig, axes = plt.subplots(2, 2, figsize=(120*MM, 110*MM))
axes = axes.flatten()
for (tag, title, x, y, xl, yl), ax in zip(panels, axes):
    rho, p = stats.spearmanr(x, y)
    ax.scatter(x, y, s=9, color='#0072B2', alpha=0.75, edgecolors='none')
    lo, hi = min(x.min(), y.min()), max(x.max(), y.max())
    ax.plot([lo, hi], [lo, hi], color=MID, lw=0.6, ls=(0, (3, 2)))
    ax.set_xlabel(xl); ax.set_ylabel(yl)
    ax.set_title(f'{tag}  {title}', loc='left')
    ax.text(0.04, 0.94, f'\u03c1 = {rho:.2f}   n = {len(x)}', transform=ax.transAxes,
            fontsize=7, va='top', color=INK)
    strip(ax)
fig.tight_layout(w_pad=1.6, h_pad=1.6)
fig.savefig(f'{OUT}/Supplementary_FigureS2_variant_scatters.png', dpi=600)
fig.savefig(f'{OUT}/Supplementary_FigureS2_variant_scatters.pdf')
plt.close(fig)
print('S2 saved; rhos:', [round(stats.spearmanr(x, y)[0], 3) for _, _, x, y, _, _ in panels])

# ================= Figure S3: microstate sensitivity =================
ms = pd.read_csv('results_v17/microstate_sensitivity_v17.csv')
labels = {'DODJI vs death under-registration': 'Death under-registration',
          'DODJI vs external surveillance capacity': 'Surveillance-capacity indices',
          'DODJI vs log GDP': 'log GDP per capita'}
fig, ax = plt.subplots(figsize=(120*MM, 55*MM))
ys = [2, 1, 0]
for (lab, y) in zip(['DODJI vs death under-registration', 'DODJI vs external surveillance capacity', 'DODJI vs log GDP'], ys):
    full = ms[(ms.validation == lab) & (ms['sample'] == 'all_countries')].r.iloc[0]
    excl = ms[(ms.validation == lab) & (ms['sample'] == 'excluding_microstates')].r.iloc[0]
    ax.plot([full, excl], [y, y], color='#C9C9C9', lw=1.2, zorder=1)
    ax.scatter([full], [y], s=28, color='#0072B2', zorder=2, label='All countries' if y == 2 else None)
    ax.scatter([excl], [y], s=28, color='#D55E00', zorder=2, label='Excluding six microstates' if y == 2 else None)
    ax.text(max(full, excl) + 0.03, y, f'{full:.2f} \u2192 {excl:.2f}', va='center', fontsize=7, color=INK)
ax.axvline(0, color=MID, lw=0.5, ls=(0, (3, 2)))
ax.set_yticks(ys)
ax.set_yticklabels([labels[l] for l in ['DODJI vs death under-registration', 'DODJI vs external surveillance capacity', 'DODJI vs log GDP']])
ax.set_xlabel('Pearson correlation with DODJI (r)')
ax.set_xlim(-0.65, 0.85)
ax.legend(loc='lower left', frameon=False, fontsize=6.5)
strip(ax)
fig.tight_layout()
fig.savefig(f'{OUT}/Supplementary_FigureS3_microstate_sensitivity.png', dpi=600)
fig.savefig(f'{OUT}/Supplementary_FigureS3_microstate_sensitivity.pdf')
plt.close(fig)
print('S3 saved')
