import { experimental_evaluate as evaluate } from 'ai'
import type { EvaluateRequest } from './schema.js'

const MODEL = 'typesafe-ai/jev'
const DEFAULT_TIMEOUT_MS = Number(process.env.JEV_TIMEOUT_MS ?? 2500)

/**
 * 無料枠はレート制限が厳しく 429 が返る。SDK は待ってから再試行するが、
 * その待ち時間が短いタイムアウトを食い潰すので、回数は控えめにしておく。
 */
const MAX_RETRIES = Number(process.env.JEV_MAX_RETRIES ?? 1)

/** アプリが組み立てた問い合わせを、そのまま Jev に渡して回答を返す。 */
export async function relayToJev({ state, questions, timeoutMs = DEFAULT_TIMEOUT_MS }: EvaluateRequest) {
  const result = await withTimeout(
    evaluate({
      model: MODEL,
      state: state as Parameters<typeof evaluate>[0]['state'],
      questions,
      maxRetries: MAX_RETRIES,
      abortSignal: AbortSignal.timeout(timeoutMs),
    }),
    timeoutMs,
  )
  // AI Gateway に直接つないだときと同じ形で返す。アプリ側の読み取りを経路で分けないため。
  return { answers: result.answers, providerMetadata: result.providerMetadata }
}

async function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined
  try {
    return await Promise.race([
      promise,
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('Jev timeout')), ms)
      }),
    ])
  } finally {
    if (timer) clearTimeout(timer)
  }
}
