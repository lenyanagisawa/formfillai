import type { VercelRequest } from '@vercel/node'

/** MVP では簡易トークン。一般公開する場合は正式な認証へ置き換える。 */
export function isAuthorized(req: VercelRequest): boolean {
  const expected = process.env.FORMFILLAI_API_TOKEN
  if (!expected) return false

  const header = req.headers.authorization
  if (typeof header !== 'string' || !header.startsWith('Bearer ')) return false

  const provided = header.slice('Bearer '.length)
  if (provided.length !== expected.length) return false

  // タイミング差で総当たりされないよう、長さを揃えたうえで定数時間比較する。
  let diff = 0
  for (let i = 0; i < expected.length; i += 1) {
    diff |= provided.charCodeAt(i) ^ expected.charCodeAt(i)
  }
  return diff === 0
}
