import SwiftUI
import FirebaseFirestore

struct AddVenueView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var type = "Bar"
    @State private var address = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var showSuccess = false
    let types = ["Bar", "Night Club", "Restaurant"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Venue Details")) {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { t in
                            Text(t)
                        }
                    }
                    TextField("Address", text: $address)
                    TextField("Latitude", text: $latitude)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $longitude)
                        .keyboardType(.decimalPad)
                }
                if let error = errorMessage {
                    Text(error).foregroundColor(.red)
                }
                if showSuccess {
                    Text("Venue added successfully!").foregroundColor(.green)
                }
                Button(action: addVenue) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Add Venue")
                    }
                }
                .disabled(isSubmitting || name.isEmpty || address.isEmpty || latitude.isEmpty || longitude.isEmpty)
            }
            .navigationTitle("Add Venue")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func addVenue() {
        guard let lat = Double(latitude), let lng = Double(longitude) else {
            errorMessage = "Latitude and longitude must be valid numbers."
            return
        }
        isSubmitting = true
        errorMessage = nil
        showSuccess = false
        let db = Firestore.firestore()
        let venue: [String: Any] = [
            "name": name,
            "type": type,
            "address": address,
            "latitude": lat,
            "longitude": lng,
            "description": "",
            "menu": [],
            "menuRequests": []
        ]
        db.collection("venues").addDocument(data: venue) { err in
            isSubmitting = false
            if let err = err {
                errorMessage = "Error adding venue: \(err.localizedDescription)"
            } else {
                showSuccess = true
                // Optionally clear fields
                name = ""
                address = ""
                latitude = ""
                longitude = ""
            }
        }
    }
} 