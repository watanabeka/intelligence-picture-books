import Foundation

protocol StoryGenerating: Sendable {
    func generateStory(theme: String, pageCount: Int) -> AsyncThrowingStream<StoryGenerationEvent, Error>
}
