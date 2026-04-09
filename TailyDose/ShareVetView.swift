import SwiftData
import SwiftUI
import UIKit

struct ShareVetView: View {
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]
    @State private var copied = false

    private var exportText: String {
        ExportService.vetSummary(for: pets)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PetBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PlushCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeading(eyebrow: "Vet Export", title: "Share a clean medication summary")
                                Text("Send your vet a readable snapshot of pets, meds, dosage timing, and recent logs.")
                                    .font(.subheadline)
                                    .foregroundStyle(PetTheme.muted)

                                HStack(spacing: 10) {
                                    ShareLink(item: exportText) {
                                        Label("Share With Vet", systemImage: "square.and.arrow.up.fill")
                                    }
                                    .buttonStyle(PrimaryPillButtonStyle())

                                    Button {
                                        UIPasteboard.general.string = exportText
                                        copied = true
                                    } label: {
                                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                    }
                                    .buttonStyle(SecondaryPillButtonStyle())
                                }
                            }
                        }

                        PlushCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeading(eyebrow: "Preview", title: "Export content")
                                Text(exportText)
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(PetTheme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Share")
        }
        .onDisappear {
            copied = false
        }
    }
}
