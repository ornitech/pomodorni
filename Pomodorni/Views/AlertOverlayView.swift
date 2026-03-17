import SwiftUI

struct AlertOverlayView: View {
    let sessionType: SessionType
    let nextSessionName: String
    let alertStyle: AlertStyle
    let autoStarted: Bool
    let onStartNext: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        switch alertStyle {
        case .pill:
            pillLayout
        case .centered:
            centeredLayout
        case .corner:
            cornerLayout
        case .none:
            EmptyView()
        }
    }

    private var message: String {
        if autoStarted {
            return "\(sessionType.displayName) complete! \(nextSessionName) started."
        }
        return "\(sessionType.displayName) complete!"
    }

    // MARK: - Pill

    private var pillLayout: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
            Text(message)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Spacer()
            if !autoStarted {
                Button("Start \(nextSessionName)", action: onStartNext)
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.small)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 360)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 25))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    // MARK: - Centered

    private var centeredLayout: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)

            VStack(spacing: 6) {
                Text(message)
                    .font(.title3.weight(.semibold))
                if !autoStarted {
                    Text("Up next: \(nextSessionName)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if autoStarted {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            } else {
                HStack(spacing: 12) {
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    Button("Start \(nextSessionName)", action: onStartNext)
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.regular)
                }
            }
        }
        .padding(32)
        .frame(width: 320)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }

    // MARK: - Corner

    private var cornerLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                Text(message)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                if !autoStarted {
                    Button("Start \(nextSessionName)", action: onStartNext)
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.small)
                }
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}
