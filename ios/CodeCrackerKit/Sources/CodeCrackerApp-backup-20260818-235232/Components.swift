import SwiftUI

struct AppTextField: View {
    let title: String
    @Binding var text: String
    var systemImage: String
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .keyboardType(keyboard)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
    }
}

struct StatusBadge: View {
    let text: String
    var tint: Color = .primary

    var body: some View {
        Text(text)
            .font(.headline)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background(.background, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

extension View {
    func cardBackground() -> some View { modifier(CardBackground()) }
}
