import SwiftUI

struct VenueEditView: View {
    @Binding var venue: Venue
    @Environment(\.presentationMode) var presentationMode
    @State private var descriptionText: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("Venue Name", text: $venue.name)
                }
                Section(header: Text("Type")) {
                    TextField("Type", text: $venue.type)
                }
                Section(header: Text("Address")) {
                    TextField("Address", text: $venue.address)
                }
                Section(header: Text("Description")) {
                    TextField("Description", text: $descriptionText)
                }
            }
            .navigationTitle("Edit Venue")
            .navigationBarItems(trailing: Button("Done") {
                venue.description = descriptionText.isEmpty ? nil : descriptionText
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                descriptionText = venue.description ?? ""
            }
        }
    }
}

// Helper to bind optional String to TextField
extension Binding where Value == String? {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(get: { source.wrappedValue ?? defaultValue }, set: { source.wrappedValue = $0 })
    }
} 