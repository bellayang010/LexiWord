import SwiftUI

// MARK: - SupportedLanguage

struct SupportedLanguage: Identifiable, Hashable {
    let code: String
    let localizedName: String
    let flag: String

    var id: String { code }

    static let all: [SupportedLanguage] = [
        SupportedLanguage(code: "ar",      localizedName: "Arabic",                flag: "🇸🇦"),
        SupportedLanguage(code: "zh-Hans", localizedName: "Chinese (Simplified)",  flag: "🇨🇳"),
        SupportedLanguage(code: "zh-Hant", localizedName: "Chinese (Traditional)", flag: "🇹🇼"),
        SupportedLanguage(code: "nl",      localizedName: "Dutch",                 flag: "🇳🇱"),
        SupportedLanguage(code: "en",      localizedName: "English",               flag: "🇺🇸"),
        SupportedLanguage(code: "fr",      localizedName: "French",                flag: "🇫🇷"),
        SupportedLanguage(code: "de",      localizedName: "German",                flag: "🇩🇪"),
        SupportedLanguage(code: "id",      localizedName: "Indonesian",            flag: "🇮🇩"),
        SupportedLanguage(code: "it",      localizedName: "Italian",               flag: "🇮🇹"),
        SupportedLanguage(code: "ja",      localizedName: "Japanese",              flag: "🇯🇵"),
        SupportedLanguage(code: "ko",      localizedName: "Korean",                flag: "🇰🇷"),
        SupportedLanguage(code: "pl",      localizedName: "Polish",                flag: "🇵🇱"),
        SupportedLanguage(code: "pt",      localizedName: "Portuguese",            flag: "🇵🇹"),
        SupportedLanguage(code: "ru",      localizedName: "Russian",               flag: "🇷🇺"),
        SupportedLanguage(code: "es",      localizedName: "Spanish",               flag: "🇪🇸"),
        SupportedLanguage(code: "th",      localizedName: "Thai",                  flag: "🇹🇭"),
        SupportedLanguage(code: "tr",      localizedName: "Turkish",               flag: "🇹🇷"),
        SupportedLanguage(code: "uk",      localizedName: "Ukrainian",             flag: "🇺🇦"),
        SupportedLanguage(code: "vi",      localizedName: "Vietnamese",            flag: "🇻🇳"),
    ]
}

// MARK: - LanguagePickerView

struct LanguagePickerView: View {
    let languages: [SupportedLanguage]

    @AppStorage("selectedTargetLanguage")
    private var selectedLanguageID: String = Locale.current.language.languageCode?.identifier ?? "en"

    @Environment(\.dismiss) private var dismiss

    init(languages: [SupportedLanguage] = SupportedLanguage.all) {
        self.languages = languages
    }

    var body: some View {
        NavigationStack {
            List(languages) { language in
                Button {
                    selectedLanguageID = language.code
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(language.flag)
                            .font(.title2)
                        Text(language.localizedName)
                            .foregroundStyle(.notionText)
                        Spacer()
                        if selectedLanguageID == language.code {
                            Image(systemName: "checkmark")
                                .fontWeight(.regular)
                                .foregroundStyle(.notionText)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.notionBackground)
                .listRowSeparatorTint(.notionBorder)
            }
            .listStyle(.plain)
            .background(Color.notionBackground)
            .navigationTitle(String(localized: "Translate to"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                        .foregroundStyle(.notionText)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Language Picker — 5 mock languages") {
    LanguagePickerView(languages: [
        SupportedLanguage(code: "en", localizedName: "English",  flag: "🇺🇸"),
        SupportedLanguage(code: "fr", localizedName: "French",   flag: "🇫🇷"),
        SupportedLanguage(code: "de", localizedName: "German",   flag: "🇩🇪"),
        SupportedLanguage(code: "ja", localizedName: "Japanese", flag: "🇯🇵"),
        SupportedLanguage(code: "ko", localizedName: "Korean",   flag: "🇰🇷"),
    ])
}
