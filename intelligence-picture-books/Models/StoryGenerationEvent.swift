import Foundation

enum StoryGenerationEvent: Sendable {
    case started
    case titleGenerated(String)
    case pageTextGenerated(page: Int, text: String, prompt: String, mood: String)
    case storyFinished
    case coverImageStarted
    case coverImageFinished
    case pageImageStarted(page: Int)
    case pageImageFinished(page: Int)
    case completed
    case failed(String)
}
