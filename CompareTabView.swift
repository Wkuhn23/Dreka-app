import SwiftUI

struct CompareBottomSheetView: View {
    @EnvironmentObject var venueManager: VenueManager
    @State private var selectedVenues: [Venue] = []
    @State private var showComparison = false
    
    var body: some View {
        VStack {
            Text("Select two venues to compare")
                .font(.headline)
            Button(action: {
                showComparison = true
            }) {
                Text("Compare")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedVenues.count == 2 ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(selectedVenues.count != 2)
            .padding(.bottom)
            List(venueManager.venues) { venue in
                Button(action: {
                    if let idx = selectedVenues.firstIndex(where: { $0.id == venue.id }) {
                        selectedVenues.remove(at: idx)
                    } else if selectedVenues.count < 2 {
                        selectedVenues.append(venue)
                    }
                }) {
                    HStack {
                        Text(venue.name)
                        Spacer()
                        if selectedVenues.contains(where: { $0.id == venue.id }) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                        }
                    }
                }
                .disabled(selectedVenues.count == 2 && !selectedVenues.contains(where: { $0.id == venue.id }))
            }
        }
        .sheet(isPresented: $showComparison) {
            if selectedVenues.count == 2 {
                VenueComparisonView(venue1: selectedVenues[0], venue2: selectedVenues[1])
            }
        }
    }
}

struct VenueComparisonView: View {
    var venue1: Venue
    var venue2: Venue
    @Environment(\.presentationMode) var presentationMode
    
    var allMenuItems: [String] {
        let items1 = Set(venue1.menu.map { $0.name })
        let items2 = Set(venue2.menu.map { $0.name })
        return Array(items1.union(items2)).sorted()
    }
    
    func priceString(for item: String, in venue: Venue) -> String {
        if let menuItem = venue.menu.first(where: { $0.name == item }) {
            return String(format: "$%.2f", menuItem.price)
        } else {
            return "—"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("")
                    Spacer()
                    Text(venue1.name).bold()
                    Spacer()
                    Text(venue2.name).bold()
                }
                Divider()
                ForEach(allMenuItems, id: \.self) { itemName in
                    HStack {
                        Text(itemName)
                        Spacer()
                        Text(priceString(for: itemName, in: venue1))
                        Spacer()
                        Text(priceString(for: itemName, in: venue2))
                    }
                }
                Spacer()
            }
            .padding()
            .navigationBarTitle("Comparison", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
} 