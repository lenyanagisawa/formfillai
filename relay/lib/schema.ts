import { z } from 'zod'

/**
 * 中継サーバーは問い合わせの中身を作らない。指示文も候補もアプリが組み立てて送ってくる。
 * ここで見るのは「Jev の Choice 1 問として妥当な形か」だけ。
 * 登録された値はそもそも送られてこない（アプリ側のセルフテストで検証している）。
 */
const questionSchema = z.object({
  type: z.literal('choice'),
  instructions: z.string().min(1).max(8000),
  // Jev の Choice は 255 択まで。キーは選択肢 ID、値はその説明。
  criteria: z
    .record(z.string().regex(/^[a-z0-9_]+$/).max(120), z.string().max(300).nullable())
    .refine((value) => Object.keys(value).length >= 2 && Object.keys(value).length <= 255, {
      message: 'criteria must have 2-255 options',
    }),
})

export const evaluateRequestSchema = z.object({
  state: z.record(z.unknown()),
  questions: z
    .record(z.string().max(60), questionSchema)
    .refine((value) => Object.keys(value).length === 1, { message: 'exactly one question' }),
  /** クライアントが待てる上限。これを受け取らないと、アプリが諦めた後も Jev を待ち続けてしまう。 */
  timeoutMs: z.number().int().min(1000).max(8000).optional(),
})

export type EvaluateRequest = z.infer<typeof evaluateRequestSchema>
