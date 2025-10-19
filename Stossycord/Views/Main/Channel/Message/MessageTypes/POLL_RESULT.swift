import SwiftUI
import Foundation

struct PollResultSystemMessageView: View {
	let content: PollResultContent

	var body: some View {
		SystemMessageView(messageText)
	}

	private var messageText: Text {
		var text = Text("@\(content.authorDisplayName)").bold()
			+ Text("'s poll ")
			+ Text(content.questionText).bold()
			+ Text(" has closed! ")

		if let winner = content.winner {
			text = text
				+ Text("The winner was ")

			if let emoji = winner.emojiDisplay {
				text = text + Text("\(emoji) ")
			}

			text = text
				+ Text(winner.displayText).italic()
				+ Text(" (\(winner.percentageString)). ")
		} else {
			text = text + Text("There was no winner :O. ")
		}

		if let timestamp = content.formattedTimestamp {
			text = text + Text("(\(timestamp))")
		}

		return text
	}
}

struct PollResultContent {
	struct Winner {
		let displayText: String
		let emojiDisplay: String?
		let votes: Int
		let totalVotes: Int

		var percentageString: String {
			PollResultContent.percentageString(forVotes: votes, totalVotes: totalVotes)
		}
	}

	let authorDisplayName: String
	let questionText: String
	let totalVotes: Int
	let winner: Winner?
	let timestamp: Date?

	var formattedTimestamp: String? {
		guard let timestamp else { return nil }
		return PollResultContent.timestampFormatter.string(from: timestamp)
	}

	init?(message: Message) {
		guard message.type == 46 else { return nil }

		authorDisplayName = message.author.currentname

		let embed = message.embeds?.first { $0.type?.lowercased() == "poll_result" }
		let fields = embed?.fields ?? []

		var fieldMap: [String: String] = [:]
		for field in fields {
			guard let key = field.name?.lowercased(), let value = field.value else { continue }
			fieldMap[key] = value.trimmingCharacters(in: .whitespacesAndNewlines)
		}

		let rawQuestion = fieldMap["poll_question_text"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		questionText = rawQuestion.isEmpty ? "Untitled poll" : rawQuestion

		let totalVotesValue = Int(fieldMap["total_votes"] ?? "") ?? 0
		totalVotes = totalVotesValue
		let winnerVotes = Int(fieldMap["victor_answer_votes"] ?? "") ?? 0

		if PollResultContent.containsWinnerInformation(in: fieldMap) {
			let answerId = Int(fieldMap["victor_answer_id"] ?? "")
			let rawAnswerText = fieldMap["victor_answer_text"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			let answerText: String
			if !rawAnswerText.isEmpty {
				answerText = rawAnswerText
			} else if let answerId {
				answerText = "Option \(answerId)"
			} else {
				answerText = "Winning option"
			}

			let emojiDisplay = PollResultContent.emojiDisplay(from: fieldMap)

			winner = Winner(
				displayText: answerText,
				emojiDisplay: emojiDisplay,
				votes: winnerVotes,
				totalVotes: totalVotesValue
			)
		} else {
			winner = nil
		}

		if let timestampString = message.timestamp {
			timestamp = PollResultContent.parseTimestamp(timestampString)
		} else {
			timestamp = nil
		}
	}

	private static func containsWinnerInformation(in fieldMap: [String: String]) -> Bool {
		let keys = [
			"victor_answer_id",
			"victor_answer_text",
			"victor_answer_emoji_id",
			"victor_answer_emoji_name",
			"victor_answer_emoji_animated"
		]

		return keys.contains { key in
			guard let value = fieldMap[key]?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
			return !value.isEmpty
		}
	}

	private static func emojiDisplay(from fieldMap: [String: String]) -> String? {
		let rawName = fieldMap["victor_answer_emoji_name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		let rawId = fieldMap["victor_answer_emoji_id"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		let isAnimated = bool(from: fieldMap["victor_answer_emoji_animated"])

		if !rawName.isEmpty && !rawId.isEmpty {
			let prefix = isAnimated == true ? "<a:" : "<:"
			return "\(prefix)\(rawName):\(rawId)>"
		}

		if !rawName.isEmpty {
			return rawName
		}

		return nil
	}

	private static func bool(from rawValue: String?) -> Bool? {
		guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
			return nil
		}

		switch rawValue.lowercased() {
		case "true", "1", "yes":
			return true
		case "false", "0", "no":
			return false
		default:
			return nil
		}
	}

	private static func percentageString(forVotes votes: Int, totalVotes: Int) -> String {
		guard totalVotes > 0 else { return "0%" }
		let value = (Double(votes) / Double(totalVotes)) * 100
		let formatted = percentFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
		return "\(formatted)%"
	}

	private static func parseTimestamp(_ string: String) -> Date? {
		if let date = isoFormatterWithFractionalSeconds.date(from: string) {
			return date
		}
		return isoFormatter.date(from: string)
	}

	private static let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return formatter
	}()

	private static let isoFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime]
		return formatter
	}()

	private static let timestampFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .short
		formatter.timeStyle = .short
		formatter.locale = .autoupdatingCurrent
		return formatter
	}()

	private static let percentFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.minimumFractionDigits = 0
		formatter.maximumFractionDigits = 1
		return formatter
	}()
}