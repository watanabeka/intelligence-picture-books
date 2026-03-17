import Foundation

/// 文章品質を制御するスタイルガイド。
/// 自由生成ではなく、制約付き生成のためのルールを定義する。
struct StoryStyleGuide: Sendable {

    var toneRules: [String]
    var vocabularyRules: [String]
    var narrativeRules: [String]
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
        ],
        narrativeRules: [
            "One event per page - do not cram multiple events",
            "Each page must flow naturally to the next",
            "Avoid big jumps in time or location between pages",
            "The story must have: a clear beginning, development, and gentle conclusion",
            "The main character should appear on every page",
            "Each page should describe something that can be clearly illustrated",
            "Include at least one concrete visual object per page (animal, flower, cloud, etc.)",
            "The ending should feel warm and complete, not abrupt",
        ],
        visualRules: [
            "Scene descriptions must be concrete and specific",
            "Always mention the main character in the scene",
            "Describe the setting (indoor/outdoor, time of day)",
            "Include 2-3 key visual objects per scene",
            "Avoid abstract or hard-to-illustrate concepts",
            "Each scene should be distinct from the previous one",
        ],
        sampleOpenings: [
            "あるはれたあさ、こうさぎのミミはおさんぽにでかけました。",
            "もりのおくに、ちいさなちいさないえがありました。",
            "きょうは、とってもいいおてんきです。",
        ],
        sampleTransitions: [
            "あるいていくと、ふしぎなものがみえてきました。",
            "つぎのひ、また あたらしいことが おこりました。",
            "「いっしょにいこう！」と、ともだちがいいました。",
        ],
        sampleEndings: [
            "おうちにかえると、おかあさんがまっていました。「おかえり」",
            "よるになって、おほしさまがきらきらひかりました。「おやすみなさい」",
            "みんなでわらって、とてもしあわせなきもちになりました。",
        ]
    )
}
