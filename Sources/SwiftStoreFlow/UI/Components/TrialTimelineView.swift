import SwiftUI

/// High-converting transparent free-trial timeline component (Today -> Reminder -> Billing).
public struct TrialTimelineView: View {
    private let milestones: [TrialTimelineMilestone]

    public init(milestones: [TrialTimelineMilestone] = TrialTimelineMilestone.defaultSevenDayTrial) {
        self.milestones = milestones
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(index == 0 ? Color.accentColor : Color.accentColor.opacity(0.18))
                                .frame(width: 32, height: 32)
                            Image(systemName: milestone.symbolName)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(index == 0 ? .white : Color.accentColor)
                        }
                        if index < milestones.count - 1 {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.28))
                                .frame(width: 2, height: 36)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(milestone.dayLabel.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                        Text(milestone.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(milestone.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, index < milestones.count - 1 ? 16 : 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
