import SwiftUI

/// Settings: API keys and which model does the structured extraction.
/// Gemini always handles transcription (it accepts the audio directly).
struct SettingsView: View {
    @AppStorage("gemini_api_key") private var geminiKey = ""
    @AppStorage("anthropic_api_key") private var claudeKey = ""
    @AppStorage("extraction_provider") private var extractionProvider = ExtractionProvider.gemini.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("AIza…", text: $geminiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Gemini API Key")
                } footer: {
                    Text("Required. Gemini transcribes your recordings (aistudio.google.com/apikey). Stored only on this device.")
                }

                Section {
                    Picker("Extraction model", selection: $extractionProvider) {
                        ForEach(ExtractionProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Summarization")
                } footer: {
                    Text("Which model turns the transcript into a title, summary, category, and action items.")
                }

                if extractionProvider == ExtractionProvider.claude.rawValue {
                    Section {
                        SecureField("sk-ant-…", text: $claudeKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Claude API Key")
                    } footer: {
                        Text("Required when Claude does the extraction (console.anthropic.com). Stored only on this device.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
