#!/usr/bin/env bash
# Refresh a two-Tab-delimited list of Jisilu projects at the 同意注册 stage.
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
const https = require('https');
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
const twoTabs = '\t\t';
const quote = (stockId) => new Promise((resolve) => {
  const market = /^6/.test(String(stockId)) ? '1' : '0';
  const request = https.get(`https://push2.eastmoney.com/api/qt/stock/get?secid=${market}.${encodeURIComponent(stockId)}&fields=f43,f116`, { timeout: 15000 }, (response) => {
    let body = '';
    response.setEncoding('utf8');
    response.on('data', (chunk) => { body += chunk; });
    response.on('end', () => {
      try {
        const data = JSON.parse(body).data;
        const price = Number(data?.f43) / 100;
        const marketCap = Number(data?.f116);
        resolve(Number.isFinite(price) && price > 0 && Number.isFinite(marketCap) && marketCap > 0 ? { price, marketCap } : null);
      } catch { resolve(null); }
    });
  });
  request.on('timeout', () => request.destroy());
  request.on('error', () => resolve(null));
});
const registered = payload.data.filter((item) => progress(item) === '同意注册');
(async () => {
const quotes = await Promise.all(registered.map((item) => quote(item.stock_id)));
const rows = registered.map((item, index) => {
  const amount = Number(item.amount);
  const quoteData = quotes[index];
  const price = quoteData ? quoteData.price.toFixed(2) : dash;
  const perShareAllotment = quoteData && Number.isFinite(amount) && amount > 0
    ? (amount * 1e8 * quoteData.price / quoteData.marketCap).toFixed(2)
    : dash;
  const cushion = quoteData && Number.isFinite(amount) && amount > 0
    ? `${(amount * 1e8 / quoteData.marketCap * 0.57 * 100).toFixed(2)}%`
    : dash;
  return [
    `${clean(item.stock_nm)}（${clean(item.stock_id)}）`, clean(item.amount), price, perShareAllotment, cushion, registrationDate(item.progress_full),
  ].join(twoTabs);
});
const fetchedAt = new Intl.DateTimeFormat('sv-SE', {
  timeZone: 'Asia/Shanghai',
  year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit', second: '2-digit',
  hour12: false,
}).format(new Date()).replace(' ', ' ');
const text = ['集思录待发转债：同意注册项目', '数据源：集思录待发转债接口；行情及总市值：东方财富公开行情接口。', `抓取时间：${fetchedAt}（Asia/Shanghai）；字段以两个 Tab 分隔；每股配债额及安全垫均为估算值。`, '', ['正股', '规模(亿元)', '当前价(元)', '估算每股配债额(元)', '估算配债安全垫', '同意注册日'].join(twoTabs), ...rows, ''].join('\n');
fs.writeFileSync(outputPath, text, 'utf8');
for (const row of rows) if ((row.match(/\t/g) || []).length !== 10) { console.error('输出校验失败：数据行不是五个两 Tab 分隔字段。'); process.exit(1); }
console.log(JSON.stringify({ source: payload.data.length, retained: rows.length }));
})().catch((error) => { console.error(`生成输出失败：${error.message}`); process.exit(1); });
NODE
)"

if [[ ! -s "$new_file" ]]; then
  echo "未生成有效输出；未修改 ${output_path}" >&2
  exit 1
fi

mv "$new_file" "$output_path"
echo "已更新 ${output_path}：${result}"
