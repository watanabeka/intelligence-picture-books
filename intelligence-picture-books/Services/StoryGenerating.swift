import Foundation

protocol StoryGenerating: Sendable {
    func generateStoryPlan(theme: String, pageCount: Int) -> AsyncThrowingStream<StoryGenerationEvent, Error>
}
