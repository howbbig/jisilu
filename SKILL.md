---
name: jisilu-registered-convertibles
description: Fetch the current Jisilu pending-convertible-bond feed and write only projects at the "同意注册" stage, including estimated per-share debt allotment and an allotment safety cushion, to a two-tab-delimited stock.log file. Use when asked to refresh this registered-convertible watchlist; do not use for historical issuance research.
---

# Jisilu Registered Convertibles

Fetch `https://www.jisilu.cn/webapi/cb/pre/` as JSON. This is a current watchlist, not a complete historical dataset.

Write `stock.log` in this skill's root directory. Overwrite only that file, unless the user specifies another destination. Do not create Markdown output.

For routine refreshes, run `scripts/refresh_stock_log.sh [output-path]`. With no argument it changes to the skill root and writes to `./stock.log`; an explicit output path overrides that default. The script fetches, filters, writes atomically, records its Shanghai run time, and validates the two-Tab field separators. It also reads the latest stock price and total market capitalization from Eastmoney's public quote endpoint for the per-share allotment and safety-cushion estimates.

Include only records whose current progress is exactly `同意注册`. For each record, write these fields in this order, separated by **two literal Tab characters**:

`正股名称（正股代码）\t\t发行规模（亿元）\t\t当前价（元）\t\t估算每股配债额（元）\t\t估算配债安全垫\t\t同意注册日`

- Extract the registration date from the `progress_full` timeline entry ending in `同意注册`.
- Estimate per-share allotment as `发行规模（元）÷ 估算总股本`, equivalently `发行规模（元）× 当前价 ÷ 总市值`. Show it in yuan rounded to two decimal places.
- Estimate the safety cushion as `估算每股配债额 ÷ 当前价 × 0.57`, equivalently `发行规模（元）÷ 总市值 × 0.57`. Show it as a percentage rounded to two decimal places. Both estimates change with the quote and may differ from the final allotment after changes in share capital or the final offering size.
- Render unavailable names, codes, dates, quotes, market capitalization, or estimates as `—`; a quote failure for one stock must not discard the other records.
- Put a short plain-text title, data-source line, and Shanghai fetch/run timestamp (to seconds) above the column header. Use two literal Tab characters between fields.
- Preserve no records from prior runs: each refresh reflects the latest feed only.

Before writing, report the number of source records and the number retained. After writing, verify that `stock.log` exists and that every table row has 10 tab characters (five two-tab separators).

If the feed cannot be fetched or parsed, leave an existing `stock.log` unchanged and explain the failure. Do not infer or fabricate project status.
