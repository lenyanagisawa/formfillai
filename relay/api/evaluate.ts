import type { VercelRequest, VercelResponse } from '@vercel/node'
import { isAuthorized } from '../lib/auth.js'
import { statusFor } from '../lib/errors.js'
import { relayToJev } from '../lib/jev.js'
import { evaluateRequestSchema } from '../lib/schema.js'

/**
 * POST /api/evaluate
 *
 * FormFillAI → ここ → AI Gateway → typesafe-ai/jev。
 * AI Gateway の API キーを端末に置きたくない人のための、任意の中継。
 * アプリは AI Gateway に直接つなぐこともでき、その場合このサーバーは要らない。
 *
 * GET は 405 を即座に返す。アプリはこれを接続と関数の暖機に使っている。
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST')
    return res.status(405).json({ error: 'Method Not Allowed' })
  }
  if (!isAuthorized(req)) {
    return res.status(401).json({ error: 'Unauthorized' })
  }
  if (!process.env.AI_GATEWAY_API_KEY && !process.env.VERCEL_OIDC_TOKEN) {
    return res.status(500).json({ error: 'AI_GATEWAY_API_KEY is not configured' })
  }

  const parsed = evaluateRequestSchema.safeParse(req.body)
  if (!parsed.success) {
    // バリデーション詳細に入力欄の情報が混ざらないよう、パスだけ返す。
    return res.status(400).json({
      error: 'Invalid request',
      issues: parsed.error.issues.map((issue) => issue.path.join('.')),
    })
  }

  const startedAt = Date.now()
  const optionCount = Object.values(parsed.data.questions).reduce(
    (sum, question) => sum + Object.keys(question.criteria).length, 0)

  try {
    const result = await relayToJev(parsed.data)
    // リクエストの中身（入力欄の情報）は記録しない。残すのは件数と所要時間だけ。
    log('evaluate', { optionCount, latencyMs: Date.now() - startedAt })
    return res.status(200).json(result)
  } catch (error) {
    const { status, message } = statusFor(error)
    log('evaluate_failed', { optionCount, latencyMs: Date.now() - startedAt, status, message })
    return res.status(status).json({ error: message })
  }
}

function log(event: string, fields: Record<string, unknown>) {
  console.log(JSON.stringify({ event, ...fields }))
}
