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

        let title = "\(String(theme.prefix(10)))のものがたり"
        continuation.yield(.titleGenerated(title))
        try await Task.sleep(for: .milliseconds(400))

        let templates: [(String, String, String)] = [
            ("あるひ、\(theme)のぼうけんがはじまりました。",
             "A gentle children's book illustration of a small rabbit starting an adventure in a sunny meadow", "わくわく"),
            ("「いってみよう！」と、げんきにあるきだしました。",
             "A gentle children's book illustration of a cheerful character walking on a path through a colorful forest", "たのしい"),
            ("とちゅうで、ふしぎなともだちにであいました。",
             "A gentle children's book illustration of two cute animals meeting in a flower garden", "ふしぎ"),
            ("いっしょに、たかいやまをのぼりました。",
             "A gentle children's book illustration of friends climbing a green mountain together", "ゆうき"),
            ("くもがふわふわとちかづいてきました。",
             "A gentle children's book illustration of fluffy white clouds approaching in a blue sky", "おだやか"),
            ("てをのばすと、くもはやわらかくてあたたかかったです。",
             "A gentle children's book illustration of a rabbit reaching up to touch soft clouds", "やさしい"),
            ("そらのうえから、まちがちいさくみえました。",
             "A gentle children's book illustration of a bird's eye view of a tiny village from above the clouds", "きらきら"),
            ("にじがかかって、せかいがきらきらひかりました。",
             "A gentle children's book illustration of a rainbow over a sparkling landscape", "きらきら"),
            ("ともだちとわらいあって、とてもしあわせでした。",
             "A gentle children's book illustration of animal friends laughing together in a sunny park", "たのしい"),
            ("「またぼうけんしようね」とやくそくしました。",
             "A gentle children's book illustration of friends waving goodbye at sunset", "あたたかい"),
        ]

        for i in 0..<pageCount {
            let t = templates[i % templates.count]
            continuation.yield(.pageTextGenerated(page: i + 1, text: t.0, prompt: t.1, mood: t.2))
            try await Task.sleep(for: .milliseconds(300))
        }

        continuation.yield(.storyFinished)
    }
}
