/**
 * 上流の失敗を、アプリ側が区別できるステータスへ落とす。
 *
 * AI Gateway の無料枠はモデルごとにレート制限があり、Jev は特に厳しい。
 * 429 や課金エラーを 502 に潰すと「AI判定に失敗」としか出ず、何を直せばいいか分からなくなる。
 */
export function statusFor(error: unknown): { status: number; message: string } {
  const message = error instanceof Error ? error.message : 'unknown error'
  const statusCode = (error as { statusCode?: unknown })?.statusCode

  if (statusCode === 429 || /rate.?limit|too many requests/i.test(message)) {
    return { status: 429, message }
  }
  if (/timeout|abort/i.test(message)) return { status: 504, message }
  // 課金・クレジット関連は再試行しても直らない。
  if (statusCode === 402 || /credit card|credits|billing|payment/i.test(message)) {
    return { status: 402, message }
  }
  return { status: 502, message }
}
