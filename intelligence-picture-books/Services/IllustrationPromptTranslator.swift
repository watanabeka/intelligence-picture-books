import Foundation

/// 日本語の PagePlan / CharacterSheet から ImageCreator 用英語プロンプトを生成するサービス。
///
/// **言語戦略の分離:**
/// - StoryPlan 生成 (narration): 日本語
/// - 画像生成プロンプト: 英語 (このサービスが担保)
/// - UI 表示: 日本語
///
/// **役割:**
/// - LLM が sceneDescription を英語で生成するよう指示されていても、稀に日本語が混入することがある
/// - テーマ (ユーザー入力) は日本語 → 英語変換が必要
/// - 気分 (mood) は日本語 1 語 → 英語フレーズ変換が必要
/// - プロンプト中の日本語文字を検出・除去する
enum IllustrationPromptTranslator {

    // MARK: - 日本語検出

    /// テキスト中にひらがな・カタカナ・漢字が含まれるか判定する
    static func hasJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x309F).contains(scalar.value) ||  // ひらがな
            (0x30A0...0x30FF).contains(scalar.value) ||  // カタカナ
            (0x4E00...0x9FFF).contains(scalar.value)     // 漢字
        }
    }

    // MARK: - テーマ翻訳（日本語テーマ → 英語キーワード）

    /// ユーザーが入力した日本語テーマを英語の世界観キーワードに変換する。
    /// マップに一致がなければ日本語文字を除去して英語部分のみ返す。
    /// それも空の場合は汎用フレーズを返す。
    static func translateTheme(_ theme: String) -> String {
        for (key, value) in themeVocabulary {
            if theme.contains(key) { return value }
        }
        let cleaned = sanitizeJapanese(theme)
        return cleaned.isEmpty ? "magical adventure world" : cleaned
    }

    // MARK: - ムード翻訳

    /// 日本語の気分ワードを英語フレーズに変換する。
    static func moodToEnglish(_ mood: String) -> String {
        for (japanese, english) in moodVocabulary {
            if mood.contains(japanese) { return english }
        }
        // 日本語が混入していなければそのまま返す
        if !hasJapanese(mood) && !mood.isEmpty { return mood }
        return "gentle and warm"
    }

    // MARK: - 日本語サニタイズ

    /// テキスト中の日本語トークンを除去し、英語部分のみを返す。
    /// LLM が sceneDescription に誤って日本語を混入させた場合の安全網。
    static func sanitizeJapanese(_ text: String) -> String {
        guard hasJapanese(text) else { return text }
        let separators = CharacterSet.whitespaces.union(.init(charactersIn: "、。・「」『』【】〔〕（）"))
        let tokens = text.components(separatedBy: separators)
        let english = tokens.filter { !hasJapanese($0) && !$0.isEmpty }
        let result = english.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        if result.isEmpty {
            print("⚠️ [Translator] 日本語テキストを英語に変換できませんでした: \(text.prefix(50))")
        }
        return result
    }

    // MARK: - 最小限の安全英語プロンプト（unsupportedLanguage 確認リトライ用）

    /// `unsupportedLanguage` が発生した後の確認リトライ用プロンプト。
    /// 日本語テーマや複雑なシーン記述を完全に排除し、キャラクター描写のみに絞る。
    /// これでも失敗した場合はデバイス言語の問題として確定する。
    static func buildMinimalEnglishPrompt(characterSheet: CharacterSheet) -> String {
        var parts: [String] = []

        // キャラクター（英語フィールドのみ）
        if !characterSheet.species.isEmpty {
            parts.append("a cute \(characterSheet.species)")
        } else {
            parts.append("a cute animal character")
        }
        if !characterSheet.bodyColor.isEmpty { parts.append("\(characterSheet.bodyColor) body") }
        if !characterSheet.accessory.isEmpty { parts.append("wearing \(characterSheet.accessory)") }

        // シーン（シンプル固定）
        parts.append("in a cheerful sunny meadow with flowers")

        // スタイル固定
        parts.append("children's picture book illustration")
        parts.append("pastel watercolor, soft outlines, warm colors")

        // 文字禁止
        parts.append("no text, no letters, no numbers, no watermark, no logo, no signage")

        return parts.joined(separator: ", ")
    }

    // MARK: - 語彙マップ

    private static let themeVocabulary: [(key: String, value: String)] = [
        // 宇宙・空
        ("宇宙", "outer space adventure"),
        ("星", "starry night sky"),
        ("月", "moonlit night"),
        ("太陽", "sunny day"),
        ("空", "sky adventure"),
        ("雲", "clouds and sky"),
        ("虹", "rainbow world"),
        ("飛行機", "airplane adventure"),
        ("ロケット", "rocket space adventure"),
        // 自然・季節
        ("海", "ocean and beach adventure"),
        ("川", "riverside adventure"),
        ("湖", "lakeside adventure"),
        ("森", "enchanted forest"),
        ("山", "mountain adventure"),
        ("花", "flower garden"),
        ("春", "springtime bloom"),
        ("夏", "sunny summer"),
        ("秋", "autumn harvest"),
        ("冬", "cozy winter"),
        ("雪", "snowy winter wonderland"),
        ("雨", "rainy day adventure"),
        ("公園", "park adventure"),
        // 魔法・ファンタジー
        ("魔法", "magical fantasy world"),
        ("ファンタジー", "fantasy adventure"),
        ("夢", "dreamland adventure"),
        ("不思議", "wondrous and mysterious world"),
        ("ふしぎ", "wondrous and mysterious world"),
        // 動物・自然
        ("動物", "animal friends"),
        ("恐竜", "dinosaur world"),
        ("昆虫", "bug and insect world"),
        ("鳥", "bird adventure"),
        // 乗り物
        ("電車", "train journey"),
        ("自動車", "car adventure"),
        ("船", "boat adventure"),
        // 食・生活
        ("料理", "cooking adventure"),
        ("ケーキ", "baking and sweets"),
        ("お菓子", "sweets and candy world"),
        ("お家", "home and family"),
        ("学校", "school life"),
        // 関係・感情
        ("友達", "friendship and kindness"),
        ("友情", "friendship and kindness"),
        ("家族", "family love"),
        ("冒険", "exciting adventure"),
        // 特別な日
        ("誕生日", "birthday celebration"),
        ("クリスマス", "Christmas celebration"),
        ("お正月", "New Year celebration"),
        // 音楽・スポーツ
        ("音楽", "music and dance"),
        ("スポーツ", "sports adventure"),
        ("サッカー", "soccer adventure"),
        ("水泳", "swimming adventure"),
        // 探検・旅
        ("探検", "exploration adventure"),
        ("旅", "journey adventure"),
        ("地図", "treasure map adventure"),
        ("宝", "treasure hunt"),
    ]

    private static let moodVocabulary: [(japanese: String, english: String)] = [
        ("わくわく", "exciting and adventurous"),
        ("ワクワク", "exciting and adventurous"),
        ("たのしい", "cheerful and happy"),
        ("楽しい", "cheerful and happy"),
        ("にぎやか", "lively and bustling"),
        ("どきどき", "thrilling and suspenseful"),
        ("ドキドキ", "thrilling and suspenseful"),
        ("ゆうき", "brave and courageous"),
        ("勇気", "brave and courageous"),
        ("しんみり", "calm and contemplative"),
        ("おだやか", "peaceful and serene"),
        ("穏やか", "peaceful and serene"),
        ("ふしぎ", "mysterious and wondrous"),
        ("不思議", "mysterious and wondrous"),
        ("きらきら", "sparkling and magical"),
        ("キラキラ", "sparkling and magical"),
        ("やさしい", "gentle and tender"),
        ("優しい", "gentle and tender"),
        ("あたたかい", "warm and cozy"),
        ("温かい", "warm and cozy"),
        ("ほっこり", "heartwarming"),
        ("かなしい", "bittersweet and touching"),
        ("悲しい", "bittersweet and touching"),
        ("うれしい", "joyful and delightful"),
        ("嬉しい", "joyful and delightful"),
        ("のんびり", "peaceful and relaxed"),
        ("ゆったり", "peaceful and relaxed"),
        ("ゆっくり", "slow and peaceful"),
        ("ふわふわ", "fluffy and dreamy"),
        ("フワフワ", "fluffy and dreamy"),
        ("にっこり", "smiling and cheerful"),
        ("元気", "energetic and lively"),
        ("げんき", "energetic and lively"),
        ("かわいい", "cute and charming"),
        ("可愛い", "cute and charming"),
        ("すてき", "wonderful and lovely"),
        ("素敵", "wonderful and lovely"),
        ("こわい", "spooky but safe"),
        ("怖い", "spooky but safe"),
        ("さびしい", "lonely but hopeful"),
        ("寂しい", "lonely but hopeful"),
    ]
}
