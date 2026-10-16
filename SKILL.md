---
name: jisilu-registered-convertibles
description: Fetch the current Jisilu pending-convertible-bond feed and write only projects at the "同意注册" stage to a five-tab-delimited stock.log file. Use when asked to refresh this registered-convertible watchlist; do not use for historical issuance research.
---

# Jisilu Registered Convertibles

Fetch `https://www.jisilu.cn/webapi/cb/pre/` as JSON. This is a current watchlist, not a complete historical dataset.

Write `stock.log` in this skill's root directory. Overwrite only that file, unless the user specifies another destination. Do not create Markdown output.

For routine refreshes, run `scripts/refresh_stock_log.sh [output-path]`. With no argument it changes to the skill root and writes to `./stock.log`; an explicit output path overrides that default. The script fetches, filters, writes atomically, records its Shanghai run time, and validates the five-Tab field separators.

Include only records whose current progress is exactly `同意注册`. For each record, write these fields in this order, separated by **five literal Tab characters**:

`正股名称（正股代码）\t\t\t\t\t发行规模（亿元）\t\t\t\t\t当前进度\t\t\t\t\t同意注册日`

- Extract the registration date from the `progress_full` timeline entry ending in `同意注册`.
- Render unavailable names, codes, or dates as `—`.
- Put a short plain-text title, data-source line, and Shanghai fetch/run timestamp (to seconds) above the column header. Use five literal Tab characters between fields.
- Preserve no records from prior runs: each refresh reflects the latest feed only.

Before writing, report the number of source records and the number retained. After writing, verify that `stock.log` exists and that every table row has 15 tab characters (three five-tab separators).

If the feed cannot be fetched or parsed, leave an existing `stock.log` unchanged and explain the failure. Do not infer or fabricate project status.
