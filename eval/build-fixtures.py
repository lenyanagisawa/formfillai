#!/usr/bin/env python3
"""評価ケース（cases.json）と、Jev へ送る問い合わせ（requests.json）を生成する。

問い合わせは Swift 側の本物のコード（VirtualCandidateBuilder と JevPrompt）で組み立てる。
候補の生成規則や指示文の写しを、ここには持たない。プロフィールは eval/profile.json のダミー値。
"""
import json
import pathlib
import subprocess

HERE = pathlib.Path(__file__).parent


def case(title, expected, placeholder=None, nearby=None, sibling=None, role="AXTextField",
         app="Google Chrome", bundle="com.google.Chrome", window="取引先情報入力",
         domain="example.com", page="お申し込みフォーム"):
    field = {
        "role": role, "subrole": None, "title": title, "placeholder": placeholder,
        "description": None, "help": None,
        "nearbyTexts": nearby or ([title] if title else []),
    }
    if sibling:
        field["siblingIndex"], field["siblingCount"] = sibling
    return {
        "expected": expected,
        "context": {
            "application": {"name": app, "bundleId": bundle},
            "window": {"title": window},
            "page": {"domain": domain, "title": page} if domain else None,
            "field": field,
        },
    }


CASES = [
    # 会社名
    case("会社名", "company.raw"), case("貴社名", "company.raw"), case("法人名", "company.raw"),
    case("企業名", "company.raw"), case("商号", "company.raw"), case("お勤め先", "company.raw"),
    case("会社名", "company.no_legal_entity", placeholder="株式会社等は除く"),
    case("会社名（株式会社不要）", "company.no_legal_entity"),
    case("法人種別を除く会社名", "company.no_legal_entity"),
    case("会社名", "company.no_legal_entity", nearby=["会社名", "株式会社・合同会社などの表記は不要です"]),
    case("Company", "company_en.raw", page="Contact us", window="Contact"),
    # 会社名フリガナ
    case("会社名フリガナ", "company_kana.raw"), case("会社名カナ", "company_kana.raw"),
    case("貴社名ふりがな", "company_kana.raw"),
    case("会社名フリガナ", "company_kana.no_legal_entity", placeholder="株式会社等の表記は除く"),
    case("商号カナ", "company_kana.no_legal_entity", placeholder="法人格不要"),
    # 氏名
    case("氏名", "name.raw"), case("お名前", "name.raw"), case("ご担当者名", "name.raw"),
    case("代表者名", "name.raw"),
    case("氏名", "name.no_space", placeholder="スペースなしで入力"),
    case("お名前", "name.no_space", nearby=["お名前", "姓と名の間にスペースを入れないでください"]),
    case("氏名", "name.full_width", nearby=["氏名", "姓と名の間は全角スペースで区切ってください"]),
    case("お名前（全角）", "name.full_width", placeholder="山田　太郎"),
    case("Full name", "name_roman.raw", page="Sign up", window="Sign up"),
    # 氏名カナ
    case("氏名カナ", "name_kana.raw"), case("フリガナ", "name_kana.raw", nearby=["お名前", "フリガナ"]),
    case("お名前（カナ）", "name_kana.raw"),
    case("氏名カナ", "name_kana.no_space", placeholder="スペースを入れずに入力"),
    case("フリガナ", "name_kana.full_width", nearby=["フリガナ", "全角カタカナ、姓名の間は全角スペース"]),
    # 郵便番号
    case("郵便番号", "zip.raw"), case("〒", "zip.raw", nearby=["〒", "会社所在地"]),
    case("郵便番号（ハイフンなし）", "zip.no_hyphen"),
    case("郵便番号", "zip.no_hyphen", placeholder="ハイフンなし7桁"),
    case("郵便番号", "zip.full_width", nearby=["郵便番号", "全角数字で入力してください"]),
    case("郵便番号", "zip.zip_first3", sibling=(1, 2), nearby=["郵便番号", "-"]),
    case("郵便番号", "zip.zip_last4", sibling=(2, 2), nearby=["郵便番号", "-"]),
    case("郵便番号（前3桁）", "zip.zip_first3"), case("郵便番号（後4桁）", "zip.zip_last4"),
    # 電話番号
    case("電話番号", "tel.raw"), case("会社電話番号", "tel.raw"), case("代表電話", "tel.raw"),
    case("携帯電話番号", "mobile.raw"),
    case("電話番号", "tel.no_hyphen", placeholder="ハイフンなし"),
    case("電話番号", "tel.full_width", nearby=["電話番号", "全角で入力してください"]),
    case("電話番号", "tel.tel_part1", sibling=(1, 3), nearby=["電話番号", "-", "-"]),
    case("電話番号", "tel.tel_part2", sibling=(2, 3), nearby=["電話番号", "-", "-"]),
    case("電話番号", "tel.tel_part3", sibling=(3, 3), nearby=["電話番号", "-", "-"]),
    # メール
    case("メールアドレス", "email.raw"), case("会社のメールアドレス", "email.raw"),
    case("メールアドレス（確認用）", "email.raw"),
    case("メールアドレス", "email_private.raw", page="ご注文手続き", domain="shop.example.com",
         window="ご注文手続き", nearby=["お届け先", "メールアドレス"]),
    # 住所
    case("住所", "address.raw"), case("所在地", "address.raw", nearby=["所在地", "本社所在地"]),
    case("都道府県", "address.pref"), case("市区町村", "address.city"),
    case("番地以降", "address.after_city", nearby=["都道府県", "市区町村", "番地以降"]),
    case("市区町村以降の住所", "address.after_city"),
    case("建物名・部屋番号", "building.raw"), case("ビル名", "building.raw"),
    case("住所", "address.full_width", nearby=["住所", "すべて全角で入力してください"]),
    case("ご自宅の住所", "home_address.raw"), case("自宅郵便番号", "home_zip.raw"),
    # 役職・Web・番号
    case("役職", "title.raw"), case("肩書き", "title.raw"),
    case("会社URL", "site.raw"), case("ホームページ", "site.raw"),
    case("法人番号", "corp_number.raw"), case("法人番号（13桁）", "corp_number.raw"),
    case("適格請求書発行事業者登録番号", "invoice.raw"), case("インボイス番号", "invoice.raw"),
    # 該当なし
    case("お問い合わせ内容", "__none__", role="AXTextArea", page="お問い合わせ"),
    case("クーポンコード", "__none__", page="カート"), case("ご希望の配送日", "__none__"),
    # 分割入力: 姓名・メール・日付
    case("姓", "name.family"), case("名", "name.given"),
    case("お名前", "name.family", sibling=(1, 2), placeholder="姓"),
    case("お名前", "name.given", sibling=(2, 2), placeholder="名"),
    case("セイ", "name_kana.family"), case("メイ", "name_kana.given"),
    case("フリガナ", "name_kana.family", sibling=(1, 2), placeholder="セイ"),
    case("First name", "name_roman.roman_given", page="Sign up", window="Sign up"),
    case("Last name", "name_roman.roman_family", page="Sign up", window="Sign up"),
    case("メールアドレス", "email.email_local", sibling=(1, 2), nearby=["メールアドレス", "@"]),
    case("メールアドレス", "email.email_domain", sibling=(2, 2), nearby=["メールアドレス", "@"]),
    case("URL", "site.no_scheme", nearby=["URL", "https://"]),
    case("生年月日", "birth.raw"),
    case("生年月日", "birth.year", sibling=(1, 3), nearby=["生年月日", "年", "月", "日"]),
    case("生年月日", "birth.month", sibling=(2, 3), nearby=["生年月日", "年", "月", "日"]),
    case("生年月日", "birth.day", sibling=(3, 3), nearby=["生年月日", "年", "月", "日"]),
    case("生年月日", "birth.date_compact", placeholder="19900131", nearby=["生年月日", "半角数字8桁"]),
    case("設立年月日", "__none__"),
    # 支払い（クレジットカード）
    case("クレジットカード番号", "card.raw", page="お支払い"), case("カード番号", "card.raw", page="お支払い"),
    case("Card number", "card.raw", page="Checkout", window="Checkout"),
    case("カード番号", "card.no_space", placeholder="ハイフン・スペースなし", page="お支払い"),
    case("カード番号", "card.card_part1", sibling=(1, 4), page="お支払い", nearby=["カード番号", "-", "-", "-"]),
    case("カード番号", "card.card_part3", sibling=(3, 4), page="お支払い", nearby=["カード番号", "-", "-", "-"]),
    case("カード名義", "card_name.raw", page="お支払い"), case("カード名義人", "card_name.raw", page="お支払い"),
    case("Name on card", "card_name.raw", page="Checkout", window="Checkout"),
    case("有効期限", "card_exp.raw", placeholder="MM/YY", page="お支払い"),
    case("有効期限", "card_exp.exp_long", placeholder="MM/YYYY", page="お支払い"),
    case("有効期限", "card_exp.exp_month", sibling=(1, 2), page="お支払い", nearby=["有効期限", "月", "年"]),
    case("有効期限", "card_exp.exp_year2", sibling=(2, 2), placeholder="YY", page="お支払い", nearby=["有効期限", "月", "年"]),
    # 2 つ目以降のセット: 手がかりが無ければ 1 つ目、名前が出ていればそのセット
    case("カード番号", "card2.raw", page="お支払い", nearby=["法人カードでお支払い", "カード番号"]),
    case("有効期限", "card2_exp.raw", page="法人カード情報の登録", placeholder="MM/YY"),
    case("お届け先住所", "ship.raw", page="ご注文手続き"), case("配送先住所", "ship.raw", page="ご注文手続き"),
    case("倉庫の住所", "ship2.raw", page="納品先の登録"),
    case("納品先住所", "ship2.raw", page="納品先の登録", nearby=["納品先（倉庫）", "住所"]),
    case("セキュリティコード", "card_cvc.raw", page="お支払い"), case("CVC", "card_cvc.raw", page="Checkout", window="Checkout"),
    case("検索", "__none__", page="検索結果", window="検索"),
    case("宛先", "__none__", app="メール", bundle="com.apple.mail", window="新規メッセージ", domain=None, page=None),
]

for index, entry in enumerate(CASES, start=1):
    entry["id"] = f"case-{index:03d}"

cases_path = HERE / "cases.json"
cases_path.write_text(json.dumps(CASES, ensure_ascii=False, indent=2) + "\n")

dumped = subprocess.run(
    ["swift", "run", "FormFillAISelfTest", "--dump-eval", str(HERE / "profile.json"), str(cases_path)],
    cwd=HERE.parent / "macos", check=True, capture_output=True, text=True,
).stdout
requests = json.loads(dumped[dumped.index("["):])
(HERE / "requests.json").write_text(json.dumps(requests, ensure_ascii=False) + "\n")

options = len(requests[0]["body"]["questions"]["field"]["criteria"])
print(f"cases: {len(CASES)} / options per request: {options}")
