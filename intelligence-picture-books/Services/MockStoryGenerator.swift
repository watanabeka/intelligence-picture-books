import Foundation

final class MockStoryGenerator: StoryGenerating, @unchecked Sendable {

    func generateStoryPlan(theme: String, pageCount: Int) -> AsyncThrowingStream<StoryGenerationEvent, Error> {
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

        continuation.yield(.progress("キャラクターを考えています..."))
        try await Task.sleep(for: .milliseconds(400))

        let title = "\(String(theme.prefix(10)))のものがたり"
        continuation.yield(.progress("タイトル「\(title)」が決まりました"))
        try await Task.sleep(for: .milliseconds(300))

        // キャラクターシート（固定）
        let characterSheet = CharacterSheet(
            mainCharacterName: "ミミ",
            species: "rabbit",
            ageFeeling: "young and cute",
            bodyColor: "white",
            earShape: "long floppy",
            accessory: "a small blue scarf",
            personality: "curious and kind"
        )

        let templates: [(narration: String, scene: String, mood: String, objects: [String])] = [
            ("あるひ、ミミは \(theme)の ぼうけんに でかけました。",
             "a small white rabbit starting an adventure in a sunny meadow",
             "わくわく", ["meadow", "path", "flowers"]),
            ("「いってみよう！」と、げんきに あるきだしました。",
             "a white rabbit walking happily on a path through a colorful forest",
             "たのしい", ["forest", "path", "butterflies"]),
            ("とちゅうで、ふしぎな ともだちに であいました。",
             "a white rabbit meeting a small bird in a flower garden",
             "ふしぎ", ["garden", "bird", "flowers"]),
            ("いっしょに、たかい やまを のぼりました。",
             "a white rabbit and a bird climbing a green mountain together",
             "ゆうき", ["mountain", "clouds", "path"]),
            ("くもが ふわふわと ちかづいてきました。",
             "a white rabbit on a hilltop with fluffy clouds approaching",
             "おだやか", ["hill", "clouds", "sky"]),
            ("てを のばすと、くもは やわらかくて あたたかかったです。",
             "a white rabbit reaching up to touch soft clouds on a hilltop",
             "やさしい", ["clouds", "hilltop", "sunlight"]),
            ("そらの うえから、まちが ちいさく みえました。",
             "a white rabbit looking down from above the clouds at a tiny village",
             "きらきら", ["clouds", "village", "sky"]),
            ("にじが かかって、せかいが きらきら ひかりました。",
             "a white rabbit watching a rainbow over a sparkling landscape",
             "きらきら", ["rainbow", "landscape", "sparkles"]),
            ("ともだちと わらいあって、とても しあわせでした。",
             "a white rabbit and a bird laughing together in a sunny park",
             "たのしい", ["park", "sun", "flowers"]),
            ("「また ぼうけんしようね」と やくそくしました。",
             "a white rabbit waving goodbye at sunset with friends",
             "あたたかい", ["sunset", "friends", "path"]),
        ]

        var pages: [PagePlan] = []
        for i in 0..<pageCount {
            let t = templates[i % templates.count]
            let page = PagePlan(
                pageNumber: i + 1,
                sceneTitle: "Scene \(i + 1)",
                narration: t.narration,
                illustrationPrompt: t.scene,
                forbiddenElements: PagePlan.defaultForbiddenElements,
                camera: "medium shot",
                location: "",
                mood: t.mood,
                keyObjects: t.objects,
                continuityNotes: i > 0 ? "continues from previous scene" : "",
                sceneMode: .solo
            )
            pages.append(page)

            continuation.yield(.progress("\(i + 1)/\(pageCount) ページの本文ができました"))
            try await Task.sleep(for: .milliseconds(200))
        }

        let coverPlan = CoverPlan(
            title: title,
            subtitle: nil,
            mainCharacterDescription: characterSheet.promptFragment,
            worldKeywords: ["meadow", "adventure"],
            coverPrompt: "a cute white rabbit with a blue scarf in a sunny meadow, ready for adventure"
        )

        let plan = StoryPlan(
            title: title,
            theme: theme,
            visualStyle: .default,
            characterSheet: characterSheet,
            pages: pages,
            coverPlan: coverPlan
        )

        continuation.yield(.planGenerated(plan))
    }
}
