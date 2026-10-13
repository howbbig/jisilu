#!/usr/bin/env bash
# Refresh a five-Tab-delimited list of Jisilu projects at the 同意注册 stage.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ $# -gt 0 ]]; then
  output_path="$1"
else
  cd "$(dirname "$script_dir")"
  output_path="./stock.log"
fi
work_dir="$(dirname "$output_path")"
raw_file="$(mktemp)"
new_file="$(mktemp "${work_dir}/.stock.log.XXXXXX")"

cleanup() { rm -f "$raw_file" "$new_file"; }
trap cleanup EXIT

if ! curl -L --fail --silent --show-error --max-time 30 'https://www.jisilu.cn/webapi/cb/pre/' > "$raw_file"; then
  echo "无法获取集思录待发转债数据；未修改 ${output_path}" >&2
  exit 1
fi

result="$(node - "$raw_file" "$new_file" <<'NODE'
const fs = require('fs');
const [rawPath, outputPath] = process.argv.slice(2);
let payload;
try { payload = JSON.parse(fs.readFileSync(rawPath, 'utf8')); }
catch (error) { console.error(`无法解析集思录响应：${error.message}`); process.exit(1); }
if (!Array.isArray(payload.data)) { console.error('集思录响应缺少 data 数组。'); process.exit(1); }
const dash = '—';
const clean = (value) => String(value ?? dash).replace(/<br\s*\/?>/gi, ' ').replace(/[\r\n\t]+/g, ' ').replace(/\|/g, '｜').trim() || dash;
const registrationDate = (timeline) => {
  const matches = [...String(timeline ?? '').matchAll(/(\d{4}-\d{2}-\d{2})\s+同意注册/g)];
  return matches.length ? matches.at(-1)[1] : dash;
};
const progress = (item) => clean(item.progress_nm);
const fiveTabs = '\t\t\t\t\t';
const rows = payload.data.filter((item) => progress(item) === '同意注册').map((item) => [
  `${clean(item.stock_nm)}（${clean(item.stock_id)}）`, clean(item.amount), progress(item), registrationDate(item.progress_full),
].join(fiveTabs));
const today = new Date().toISOString().slice(0, 10);
const text = ['集思录待发转债：同意注册项目', '数据源：https://www.jisilu.cn/webapi/cb/pre/', `抓取日期：${today}；字段以五个 Tab 分隔。`, '', ['正股', '规模(亿元)', '当前进度', '同意注册日'].join(fiveTabs), ...rows, ''].join('\n');
fs.writeFileSync(outputPath, text, 'utf8');
for (const row of rows) if ((row.match(/\t/g) || []).length !== 15) { console.error('输出校验失败：数据行不是三个五 Tab 分隔字段。'); process.exit(1); }
console.log(JSON.stringify({ source: payload.data.length, retained: rows.length }));
NODE
)"

if [[ ! -s "$new_file" ]]; then
  echo "未生成有效输出；未修改 ${output_path}" >&2
  exit 1
fi

mv "$new_file" "$output_path"
echo "已更新 ${output_path}：${result}"
