import Foundation

struct JobDescription: Identifiable {
    let id = UUID()
    var title: String
    var company: String
    var location: String
    var description: String
    var requirements: [String]
    var salary: String?
    var rawContent: String
    var sourceURL: URL?
    var fetchMethod: String
}
