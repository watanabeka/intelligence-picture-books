import Foundation

final class MockStoryGenerator: StoryGenerating, @unchecked Sendable {

    func generateStory(theme: String, pageCount: Int) -> AsyncThrowingStream<StoryGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.produce(theme: theme, pageCount: pageCount, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func produce(
        theme: String,
        pageCount: Int,
        continuation: AsyncThrowingStream<StoryGenerationEvent, Error>.Continuation
    ) async throws {
        continuation.yield(.started)
        try await Task.sleep(for: .milliseconds(600))

        let title = makeTitle(theme: theme)
        continuation.yield(.titleGenerated(title))
        try await Task.sleep(for: .milliseconds(400))

        let pages = makePages(theme: theme, pageCount: pageCount)
        for (i, page) in pages.enumerated() {
            continuation.yield(.pageTextGenerated(
                page: i + 1,
                text: page.text,
                prompt: page.prompt,
                mood: page.mood
            ))
            try await Task.sleep(for: .milliseconds(300))
        }

        continuation.yield(.storyFinished)
    }

    private func makeTitle(theme: String) -> String {
        let short = String(theme.prefix(10))
        return "\(short)のものがたり"
    }

    private func makePages(theme: String, pageCount: Int) -> [(text: String, prompt: String, mood: String)] {
        let moods = ["わくわく", "どきどき", "しんみり", "たのしい", "ふしぎ", "やさしい",
                     "ゆうき", "おだやか", "にぎやか", "きらきら", "あたたかい", "ほっこり"]
        let templates: [(String, String)] = [
            ("あるひ、\(theme)のぼうけんがはじまりました。", "冒険の始まり"),
            ("「いってみよう！」と、げんきにあるきだしました。", "元気に歩く主人公"),
            ("とちゅうで、ふしぎなともだちにであいました。", "不思議な友達との出会い"),
            ("いっしょに、たかいやまをのぼりました。", "山を登る仲間たち"),
            ("くもがふわふわとちかづいてきました。", "近づく雲"),
            ("てをのばすと、くもはやわらかくてあたたかかったです。", "雲に触れる瞬間"),
            ("そらのうえから、まちがちいさくみえました。", "空から見た街"),
            ("にじがかかって、せかいがきらきらひかりました。", "虹のかかる風景"),
            ("ともだちとわらいあって、とてもしあわせでした。", "笑い合う友達"),
            ("「またぼうけんしようね」とやくそくしました。", "約束する仲間"),
            ("おうちにかえると、あたたかいごはんがまっていました。", "温かい食卓"),
            ("ゆめのなかでも、ぼうけんはつづきます。おしまい。", "夢の中の冒険"),
        ]

        return (0..<pageCount).map { i in
            let t = templates[i % templates.count]
            let mood = moods[i % moods.count]
            return (text: t.0, prompt: t.1, mood: mood)
        }
    }
}
