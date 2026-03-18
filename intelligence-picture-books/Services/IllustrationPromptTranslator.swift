import Foundation

/// 日本語の PagePlan / CharacterSheet から ImageCreator 用英語プロンプトを生成するサービス。
///
/// **言語戦略の分離:**
/// - StoryPlan 生成 (narration): 日本語
/// - 画像生成プロンプト: 英語 (このサービスが担保)
/// - UI 表示: 日本語
enum IllustrationPromptTranslator {

    // MARK: - PromptQuality

    /// sanitizeJapanese 後の意味的な充足度を表す型
    enum PromptQuality {
        case good(wordCount: Int)       // 十分な英語ワードが残っている
        case tooShort(wordCount: Int)   // 英語が残っているが短すぎる (< 4 words)
        case empty                      // 英語が一切残らなかった

        /// 追加補充なしで使えるか
        var isSufficient: Bool {
            if case .good = self { return true }
            return false
        }

        /// デバッグ表示用の文字列
        var description: String {
            switch self {
            case .good(let n):     return "good (\(n) words)"
            case .tooShort(let n): return "⚠️ too short (\(n) words)"
            case .empty:           return "⚠️ empty"
            }
        }
    }

    // MARK: - SanitizeResult

    /// sanitizeJapaneseVerbose の返却型。
    /// 除去されたトークン数をデバッグ表示に使用する。
    struct SanitizeResult {
        let text: String
        let removedTokenCount: Int
        let quality: PromptQuality
    }

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
    ///
    /// 優先順位:
    /// 1. themeVocabulary で部分一致 → 対応英語フレーズ
    /// 2. テーマに英語部分が含まれる → 英語部分 + "adventure world"
    /// 3. 純粋日本語で語彙マップ外 → unknownThemeFallback() による多様なフォールバック
    static func translateTheme(_ theme: String) -> String {
        // 1. 語彙マップ
        for (key, value) in themeVocabulary {
            if theme.contains(key) { return value }
        }
        // 2. 英語部分を抽出
        let cleaned = sanitizeJapanese(theme)
        if !cleaned.isEmpty {
            let words = cleaned.split(separator: " ")
            return words.count == 1 ? "\(cleaned) adventure world" : cleaned
        }
        // 3. 完全日本語 + マップ外 → リッチなフォールバック
        return unknownThemeFallback(theme)
    }

    /// 語彙マップ外の純日本語テーマ向けフォールバック。
    /// "magical adventure world" の単一フレーズより多様・具体的なものを返す。
    private static func unknownThemeFallback(_ theme: String) -> String {
        let fallbacks = [
            "a magical journey through a whimsical colorful world",
            "an exciting adventure in a beautiful natural landscape",
            "a wonderful discovery in an enchanting storybook land",
            "a heartwarming story in a bright and cheerful setting",
            "a gentle adventure filled with curiosity and wonder",
        ]
        // テーマ文字数でバリエーションを決定（毎回同じテーマは同じ結果になる）
        let index = theme.unicodeScalars.count % fallbacks.count
        return fallbacks[index]
    }

    // MARK: - ムード翻訳

    /// 日本語の気分ワードを英語フレーズに変換する。
    static func moodToEnglish(_ mood: String) -> String {
        for (japanese, english) in moodVocabulary {
            if mood.contains(japanese) { return english }
        }
        if !hasJapanese(mood) && !mood.isEmpty { return mood }
        return "gentle and warm"
    }

    // MARK: - 日本語サニタイズ

    /// テキスト中の日本語トークンを除去し、英語部分のみを返す。
    /// 除去トークン数・品質評価を含む詳細結果を返す。
    static func sanitizeJapaneseVerbose(_ text: String) -> SanitizeResult {
        guard hasJapanese(text) else {
            let words = text.split(separator: " ").filter { !$0.isEmpty }
            return SanitizeResult(
                text: text,
                removedTokenCount: 0,
                quality: quality(for: words.count)
            )
        }
        let separators = CharacterSet.whitespaces.union(.init(charactersIn: "、。・「」『』【】〔〕（）"))
        let allTokens = text.components(separatedBy: separators).filter { !$0.isEmpty }
        let japaneseTokens = allTokens.filter { hasJapanese($0) }
        let englishTokens = allTokens.filter { !hasJapanese($0) }
        let result = englishTokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if result.isEmpty {
            print("⚠️ [Translator] 日本語テキストを英語に変換できませんでした: \(text.prefix(50))")
        }
        return SanitizeResult(
            text: result,
            removedTokenCount: japaneseTokens.count,
            quality: quality(for: englishTokens.count)
        )
    }

    /// テキスト中の日本語トークンを除去し、英語部分のみを返す（簡易版）。
    static func sanitizeJapanese(_ text: String) -> String {
        sanitizeJapaneseVerbose(text).text
    }

    // MARK: - プロンプト品質評価

    /// sanitize 後の英語テキストが意味的に十分かどうかを評価する。
    static func assessQuality(_ text: String) -> PromptQuality {
        let words = text.split(separator: " ").filter { !$0.isEmpty }
        return quality(for: words.count)
    }

    private static func quality(for wordCount: Int) -> PromptQuality {
        if wordCount == 0 { return .empty }
        if wordCount < 4  { return .tooShort(wordCount: wordCount) }
        return .good(wordCount: wordCount)
    }

    // MARK: - 最小限の安全英語プロンプト（unsupportedLanguage 確認リトライ用）

    /// `unsupportedLanguage` が発生した後の確認リトライ用プロンプト。
    /// 日本語テーマや複雑なシーン記述を完全に排除し、キャラクター描写のみに絞る。
    static func buildMinimalEnglishPrompt(characterSheet: CharacterSheet) -> String {
        var parts: [String] = []
        if !characterSheet.species.isEmpty {
            parts.append("a cute \(characterSheet.species)")
        } else {
            parts.append("a cute animal character")
        }
        if !characterSheet.bodyColor.isEmpty { parts.append("\(characterSheet.bodyColor) body") }
        if !characterSheet.accessory.isEmpty { parts.append("wearing \(characterSheet.accessory)") }
        parts.append("in a cheerful sunny meadow with flowers")
        parts.append("children's picture book illustration")
        parts.append("pastel watercolor, soft outlines, warm colors")
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
        ("気球", "hot air balloon adventure"),
        // 自然・季節
        ("海", "ocean and beach adventure"),
        ("川", "riverside adventure"),
        ("湖", "lakeside adventure"),
        ("池", "peaceful pond adventure"),
        ("森", "enchanted forest"),
        ("林", "woodland adventure"),
        ("山", "mountain adventure"),
        ("野原", "flower meadow adventure"),
        ("花", "flower garden"),
        ("木", "giant tree adventure"),
        ("春", "springtime bloom"),
        ("夏", "sunny summer"),
        ("秋", "autumn harvest"),
        ("冬", "cozy winter"),
        ("雪", "snowy winter wonderland"),
        ("雨", "rainy day adventure"),
        ("嵐", "stormy adventure"),
        ("公園", "park adventure"),
        ("砂浜", "sandy beach adventure"),
        // 魔法・ファンタジー
        ("魔法", "magical fantasy world"),
        ("ファンタジー", "fantasy adventure"),
        ("夢", "dreamland adventure"),
        ("不思議", "wondrous and mysterious world"),
        ("ふしぎ", "wondrous and mysterious world"),
        ("おとぎ", "fairy tale world"),
        ("童話", "fairy tale storybook world"),
        ("魔女", "friendly witch adventure"),
        ("お姫様", "princess adventure"),
        ("王様", "kingdom adventure"),
        ("城", "magical castle adventure"),
        ("宝箱", "treasure chest adventure"),
        // 動物・自然
        ("動物", "animal friends"),
        ("恐竜", "dinosaur world"),
        ("昆虫", "bug and insect world"),
        ("虫", "insect adventure"),
        ("鳥", "bird adventure"),
        ("魚", "underwater fish adventure"),
        ("ペット", "pet adventure"),
        ("犬", "dog adventure"),
        ("猫", "cat adventure"),
        ("うさぎ", "bunny adventure"),
        ("くま", "bear adventure"),
        // 乗り物
        ("電車", "train journey"),
        ("新幹線", "bullet train adventure"),
        ("自動車", "car adventure"),
        ("バス", "bus adventure"),
        ("船", "boat adventure"),
        ("潜水艦", "submarine adventure"),
        ("自転車", "bicycle adventure"),
        // 食・生活
        ("料理", "cooking adventure"),
        ("ケーキ", "baking and sweets"),
        ("パン", "bakery adventure"),
        ("お菓子", "sweets and candy world"),
        ("ピクニック", "picnic adventure"),
        ("お茶", "tea party adventure"),
        ("お家", "home and family"),
        ("学校", "school life"),
        ("幼稚園", "kindergarten adventure"),
        ("図書館", "library adventure"),
        ("病院", "hospital adventure"),
        ("市場", "colorful market adventure"),
        // 関係・感情
        ("友達", "friendship and kindness"),
        ("友情", "friendship and kindness"),
        ("家族", "family love"),
        ("兄弟", "sibling adventure"),
        ("おじいちゃん", "grandparent adventure"),
        ("おばあちゃん", "grandparent adventure"),
        ("冒険", "exciting adventure"),
        ("勇気", "brave adventure"),
        ("成長", "growing up adventure"),
        // 特別な日
        ("誕生日", "birthday celebration"),
        ("クリスマス", "Christmas celebration"),
        ("お正月", "New Year celebration"),
        ("ハロウィン", "Halloween adventure"),
        ("運動会", "sports day adventure"),
        // 音楽・スポーツ
        ("音楽", "music and dance"),
        ("楽器", "music adventure"),
        ("歌", "singing adventure"),
        ("ダンス", "dancing adventure"),
        ("スポーツ", "sports adventure"),
        ("サッカー", "soccer adventure"),
        ("水泳", "swimming adventure"),
        ("体操", "gymnastics adventure"),
        // 探検・旅
        ("探検", "exploration adventure"),
        ("旅", "journey adventure"),
        ("地図", "treasure map adventure"),
        ("宝", "treasure hunt"),
        ("迷路", "maze adventure"),
        ("洞窟", "cave exploration"),
        ("島", "island adventure"),
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
        ("むずかしい", "challenging but fun"),
        ("ドラマチック", "dramatic and exciting"),
        ("ロマンチック", "romantic and dreamy"),
        ("ミステリアス", "mysterious and intriguing"),
        ("ファンタスティック", "fantastical and magical"),
    ]
}
