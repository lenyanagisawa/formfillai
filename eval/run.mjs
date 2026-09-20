#!/usr/bin/env node
// 精度評価。eval/requests.json（アプリと同じコードで組み立てた問い合わせ）を Jev に投げて採点する。
//
//   # AI Gateway に直接
//   AI_GATEWAY_API_KEY=... node eval/run.mjs
//
//   # 自前の中継サーバー経由
//   FORMFILLAI_PROVIDER=relay FORMFILLAI_ENDPOINT=https://<host>/api/evaluate FORMFILLAI_TOKEN=... node eval/run.mjs
//
// 絞り込み: FORMFILLAI_CASES=case-047,case-090   同時実行数: FORMFILLAI_CONCURRENCY=1

import { readFile, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const NONE = 'none_of_the_above'
const QUESTION = 'field'

const provider = process.env.FORMFILLAI_PROVIDER ?? 'gateway'
const concurrency = Number(process.env.FORMFILLAI_CONCURRENCY ?? 1)
const thresholds = (process.env.FORMFILLAI_THRESHOLDS ?? '0.75,0.85,0.95').split(',').map(Number)
const only = (process.env.FORMFILLAI_CASES ?? '').split(',').filter(Boolean)

const route = resolveRoute()
const all = JSON.parse(await readFile(join(here, 'requests.json'), 'utf8'))
const cases = only.length ? all.filter((entry) => only.includes(entry.id)) : all
console.log(`▶ ${cases.length} ケース → ${route.label}\n`)

function resolveRoute() {
  if (provider === 'relay') {
    const url = process.env.FORMFILLAI_ENDPOINT
    if (!url) exitWith('FORMFILLAI_ENDPOINT が設定されていません')
    return {
      label: url,
      url,
      headers: { Authorization: `Bearer ${process.env.FORMFILLAI_TOKEN ?? ''}` },
      extend: (body) => ({ ...body, timeoutMs: 8000 }),
    }
  }
  // Vercel の OIDC トークン（`vercel env pull` で得られる）でも認証できる。
  const key = process.env.AI_GATEWAY_API_KEY
  const oidc = process.env.VERCEL_OIDC_TOKEN
  if (!key && !oidc) exitWith('AI_GATEWAY_API_KEY が設定されていません')
  return {
    label: 'Vercel AI Gateway（直接）',
    url: 'https://ai-gateway.vercel.sh/v4/ai/evaluation-model',
    headers: {
      Authorization: `Bearer ${key ?? oidc}`,
      'ai-gateway-protocol-version': '0.0.1',
      'ai-gateway-auth-method': key ? 'api-key' : 'oidc',
      'ai-evaluation-model-specification-version': '4',
      'ai-model-id': 'typesafe-ai/jev',
    },
    extend: (body) => body,
  }
}

function exitWith(message) {
  console.error(message)
  process.exit(1)
}

async function runCase(testCase) {
  const startedAt = Date.now()
  const base = { id: testCase.id, title: testCase.title, expected: testCase.expected }
  try {
    const response = await fetch(route.url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...route.headers },
      body: JSON.stringify(route.extend(testCase.body)),
      signal: AbortSignal.timeout(10000),
    })
    const latencyMs = Date.now() - startedAt
    if (!response.ok) {
      return { ...base, latencyMs, error: `HTTP ${response.status}: ${(await response.text()).slice(0, 120)}` }
    }
    const answer = (await response.json()).answers?.[QUESTION]
    const probabilities = answer?.probabilities ?? {}
    const ranking = Object.entries(probabilities).sort((a, b) => b[1] - a[1]).map(([key]) => key)
    if (ranking[0] !== answer.choice) ranking.unshift(answer.choice)
    return { ...base, latencyMs, selected: answer.choice, probability: probabilities[answer.choice] ?? 0, ranking }
  } catch (error) {
    return { ...base, latencyMs: Date.now() - startedAt, error: String(error) }
  }
}

const results = []
let next = 0
await Promise.all(
  Array.from({ length: concurrency }, async () => {
    while (next < cases.length) {
      results.push(await runCase(cases[next++]))
      process.stdout.write('.')
    }
  }),
)
results.sort((a, b) => a.id.localeCompare(b.id))
console.log('\n')

const answered = results.filter((entry) => !entry.error)
const failed = results.filter((entry) => entry.error)
const pct = (value, total) => (total ? `${((value / total) * 100).toFixed(1)}%` : '—')

const top1 = answered.filter((entry) => entry.selected === entry.expected).length
const top3 = answered.filter((entry) => entry.ranking.slice(0, 3).includes(entry.expected)).length
const latencies = answered.map((entry) => entry.latencyMs).sort((a, b) => a - b)
const average = latencies.length ? Math.round(latencies.reduce((sum, value) => sum + value, 0) / latencies.length) : 0
const p95 = latencies[Math.max(0, Math.ceil(latencies.length * 0.95) - 1)] ?? 0

// 「常に自動入力」モード: 該当なしを飛ばして、最も確率の高い実候補を入れる。
const fillable = answered.filter((entry) => entry.expected !== NONE)
const alwaysCorrect = fillable.filter((entry) => entry.ranking.find((id) => id !== NONE) === entry.expected).length

console.log('■ 全体')
console.log(`  成功: ${answered.length} / ${results.length}（失敗 ${failed.length}）`)
console.log(`  常に自動入力で1発正解: ${pct(alwaysCorrect, fillable.length)}  (${alwaysCorrect}/${fillable.length})`)
console.log(`  Top-1: ${pct(top1, answered.length)}  Top-3: ${pct(top3, answered.length)}`)
console.log(`  Latency: avg ${average} ms / p95 ${p95} ms`)

console.log('\n■ しきい値方式にした場合（設定で「常に自動入力」をオフにしたとき）')
const thresholdRows = thresholds.map((threshold) => {
  const auto = answered.filter((entry) => entry.selected !== NONE && entry.probability >= threshold)
  const correct = auto.filter((entry) => entry.selected === entry.expected).length
  console.log(`  ${threshold.toFixed(2)}: 自動入力 ${auto.length} 件 / Precision ${pct(correct, auto.length)} / 候補UI率 ${pct(answered.length - auto.length, answered.length)}`)
  return { threshold, autoPasteCount: auto.length, correct }
})

const misses = answered.filter((entry) => entry.selected !== entry.expected)
if (misses.length) {
  console.log('\n■ 不一致')
  for (const miss of misses) {
    console.log(`  [${miss.id}] 「${miss.title}」 期待 ${miss.expected} / 実際 ${miss.selected} (${(miss.probability * 100).toFixed(0)}%)`)
  }
}
if (failed.length) {
  console.log('\n■ エラー')
  for (const entry of failed) console.log(`  [${entry.id}] ${entry.error}`)
}

await writeFile(
  join(here, 'results.json'),
  JSON.stringify({
    ranAt: new Date().toISOString(), route: route.label, caseCount: results.length,
    summary: {
      answered: answered.length, failed: failed.length,
      alwaysAutoPasteAccuracy: fillable.length ? alwaysCorrect / fillable.length : null,
      top1Accuracy: answered.length ? top1 / answered.length : null,
      top3Accuracy: answered.length ? top3 / answered.length : null,
      averageLatencyMs: average, p95LatencyMs: p95, thresholds: thresholdRows,
    },
    results,
  }, null, 2) + '\n',
)
console.log('\n→ eval/results.json')
