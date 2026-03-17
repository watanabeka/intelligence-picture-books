import Foundation

enum StoryGenerationEvent: Sendable {
    case started
    case progress(String)
    case planGenerated(StoryPlan)
}
