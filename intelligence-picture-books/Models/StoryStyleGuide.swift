import Foundation

/// 文章品質を制御するスタイルガイド。
/// 自由生成ではなく、制約付き生成のためのルールを定義する。
struct StoryStyleGuide: Sendable {

    var toneRules: [String]
    var vocabularyRules: [String]
    var narrativeRules: [String]
    var sentenceRules: [String]
    var visualRules: [String]
    var sampleOpenings: [String]
    var sampleTransitions: [String]
    var sampleEndings: [String]

    /// LLMプロンプトに注入するルールテキスト
    var asPromptInstructions: String {
        var sections: [String] = []

        sections.append("## Tone Rules")
        sections.append(contentsOf: toneRules.map { "- \($0)" })

        sections.append("## Vocabulary Rules")
        sections.append(contentsOf: vocabularyRules.map { "- \($0)" })

        sections.append("## Narrative Rules")
        sections.append(contentsOf: narrativeRules.map { "- \($0)" })

        sections.append("## Sentence Rules (CRITICAL — enforce strictly)")
        sections.append(contentsOf: sentenceRules.map { "- \($0)" })

        sections.append("## Visual Rules (for illustration prompts)")
        sections.append(contentsOf: visualRules.map { "- \($0)" })

        sections.append("## Example Openings (for reference, do not copy exactly)")
        sections.append(contentsOf: sampleOpenings.map { "- \($0)" })

        sections.append("## Example Transitions (for reference)")
        sections.append(contentsOf: sampleTransitions.map { "- \($0)" })

        sections.append("## Example Endings (for reference)")
        sections.append(contentsOf: sampleEndings.map { "- \($0)" })

        return sections.joined(separator: "\n")
    }

    /// デフォルトのスタイルガイド（子供向け絵本用）
    static let `default` = StoryStyleGuide(
        toneRules: [
            "Always use a warm, gentle tone suitable for children aged 3-6",
            "The narrator speaks kindly, as if reading to a child at bedtime",
            "Avoid scary, violent, or sad themes",
            "Use onomatopoeia naturally (ふわふわ, きらきら, ぽかぽか)",
        ],
        vocabularyRules: [
            "Use hiragana as much as possible",
            "Avoid difficult kanji or complex words",
            "Keep sentences short: maximum 2-3 sentences per page",
            "Use words a 4-year-old can understand",
            "Prefer concrete, visual words over abstract ones",
            "Use specific nouns the child can picture: いえ, やま, はな, くも, みち, かわ, もり",
        ],
        narrativeRules: [
            "One event per page — do not cram multiple events",
            "Each page must flow naturally to the next",
            "Avoid big jumps in time or location between pages",
            "The story must have: a clear beginning, development, and gentle conclusion",
            "The main character should appear on every page",
            "Each page should describe something that can be clearly illustrated",
            "Include at least one concrete visual object per page (animal, flower, cloud, etc.)",
            "The ending should feel warm and complete, not abrupt",
            "Story flow should follow: 目的→出会い→協力→達成",
            "When the character meets someone, clearly name WHO they meet (e.g. 'きつねの ふうちゃん')",
            "When the character finds something, describe concretely WHAT it looks like",
        ],
        sentenceRules: [
            "ALWAYS include the subject (主語) in every sentence — never omit who is doing the action",
            "Keep each sentence short — maximum 20 characters before the verb",
            "NEVER use twisted/inverted word order (ねじれた語順を禁止)",
            "Use natural Subject → Object → Verb order (SOV)",
            "Each sentence should describe exactly ONE action",
            "BAD: 'みんなで、うまれて、くもの上をのぼりました' — twisted, unclear",
            "GOOD: 'ミミは くもの うえを あるきました。' — clear subject, one action",
            "BAD: 'ともだちが あらわれた' — who is the friend?",
            "GOOD: 'きつねの ふうちゃんが やってきました。' — specific friend named",
        ],
        visualRules: [
            "Scene descriptions must be concrete and specific — always say what the character IS DOING",
            "Always mention the main character BY NAME in the scene description",
            "Describe the setting clearly (indoor/outdoor, time of day, weather)",
            "Include 2-4 key visual objects per scene — use specific words (red flowers, stone bridge, wooden house)",
            "Avoid abstract or hard-to-illustrate concepts",
            "Each scene should be visually distinct from the previous one",
            "Match the illustration prompt to the narration — if the text says '家を見つけた', the scene MUST include a house",
        ],
        sampleOpenings: [
            "こうさぎの ミミは、あさごはんを たべおわると、おさんぽに でかけました。",
            "もりの おくに、ちいさな ちいさな いえが ありました。そこに こぐまの クマタが すんでいます。",
            "きょうは とっても いい おてんきです。こねこの ミケは そとに でました。",
        ],
        sampleTransitions: [
            "みちを あるいていくと、おおきな いしの うえに、きつねの ふうちゃんが すわっていました。",
            "「いっしょに いこう！」 ふうちゃんが いいました。ミミは にっこり うなずきました。",
            "ふたりは てを つないで、やまみちを のぼりはじめました。",
        ],
        sampleEndings: [
            "おうちに かえると、おかあさんが まっていました。「おかえり、ミミ」",
            "よるに なって、おほしさまが きらきら ひかりました。「おやすみなさい」",
            "みんなで わらって、とても しあわせな きもちに なりました。",
        ]
    )
}
