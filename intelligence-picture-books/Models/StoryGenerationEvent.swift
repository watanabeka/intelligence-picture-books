import Foundation

enum StoryGenerationEvent: Sendable {
    case started
    case titleGenerated(String)
    case pageTextGenerated(page: Int, text: String, prompt: String, mood: String)
    case storyFinished
}
