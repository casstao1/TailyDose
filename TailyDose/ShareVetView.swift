import SwiftData
import SwiftUI
import UIKit

struct ShareVetView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]
    @State private var copied = false
    @State private var showingPaywall = false
    @State private var selectedPetID: UUID?

    private var selectedPets: [PetProfile] {
        guard let selectedPetID else { return pets }
        return pets.filter { $0.id == selectedPetID }
    }

    private var selectedPetLabel: String {
        if let selectedPetID, let pet = pets.first(where: { $0.id == selectedPetID }) {
            return pet.name
        }
        return "All Pets"
    }

    private var exportText: String {
        ExportService.vetSummary(for: selectedPets)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PetBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if subscriptionManager.hasActiveSubscription {
                            PlushCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeading(eyebrow: "Vet Export", title: "Share a clean medication summary")
                                    Text("Send your vet a readable snapshot of pets, meds, dosage timing, and recent logs.")
                                        .font(.subheadline)
                                        .foregroundStyle(PetTheme.muted)

                                    if !pets.isEmpty {
                                        Picker("Export Scope", selection: $selectedPetID) {
                                            Text("All Pets").tag(Optional<UUID>.none)
                                            ForEach(pets) { pet in
                                                Text(pet.name).tag(Optional(pet.id))
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }

                                    HStack(spacing: 10) {
                                        ShareLink(item: exportText) {
                                            Label("Share \(selectedPetLabel)", systemImage: "square.and.arrow.up.fill")
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
                                    SectionHeading(eyebrow: "Preview", title: "\(selectedPetLabel) export")
                                    Text(exportText)
                                        .font(.footnote.monospaced())
                                        .foregroundStyle(PetTheme.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        } else {
                            PlushCard(tint: PetTheme.petMint) {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeading(eyebrow: "Vet Export", title: "Pro feature")
                                    Text("Upgrade to share a clean medication summary with your vet.")
                                        .font(.subheadline)
                                        .foregroundStyle(PetTheme.muted)

                                    Button {
                                        showingPaywall = true
                                    } label: {
                                        Label("Unlock Vet Export", systemImage: "square.and.arrow.up.fill")
                                    }
                                    .buttonStyle(PrimaryPillButtonStyle())
                                }
                            }

                            PlushCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionHeading(eyebrow: "Preview", title: "What Pro unlocks")
                                    Text("Pet profiles, medication names, dosage, timing, and recent logs in a single shareable summary.")
                                        .font(.subheadline)
                                        .foregroundStyle(PetTheme.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Share")
        }
        .onChange(of: selectedPetID) {
            copied = false
        }
        .onDisappear {
            copied = false
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(context: .export)
        }
    }
}
