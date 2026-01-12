import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    let barCount = 40

    var body: some View {
        GeometryReader { geometry in
            let paddedLevels = Array(
                repeating: Float(0.0),
                count: max(0, barCount - levels.count)
            ) + levels

            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(paddedLevels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.red.opacity(0.7))
                        .frame(height: CGFloat(level) * 200)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: 60)
    }
}
