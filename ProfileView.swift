import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var venueManager: VenueManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var locationManager: LocationManager
    @Binding var selectedTab: Int
    @Binding var showProfile: Bool
    @State private var showAdminPanel = false
    @State private var showEditProfile = false
    @State private var editName: String = ""
    @State private var editEmail: String = ""
    @State private var selectedVenue: Venue? = nil
    @State private var showLoginModal = false
    @State private var showAddVenue = false

    private var favorites: [Venue] {
        venueManager.venues.filter { venueManager.isFavorite($0) }
    }

    var body: some View {
        NavigationView {
            VStack {
                if userManager.currentUser == nil {
                    Button(action: { showLoginModal = true }) {
                        Text("Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                            .padding(.top, 24)
                    }
                }
                Form {
                    Section(header: Text("User Credentials")) {
                        if let user = userManager.currentUser {
                            Text("Name: \(user.name)")
                            Text("Email: \(user.email)")
                            Button("Edit Profile") {
                                editName = user.name
                                editEmail = user.email
                                showEditProfile = true
                            }
                            .foregroundColor(.blue)
                        } else {
                            Text("Name: Guest")
                            Text("Email: Guest")
                        }
                    }
                    
                    if userManager.isLoggedIn {
                        Section(header: Text("Notifications")) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Push Notifications")
                                        .font(.headline)
                                    Text(notificationManager.isPermissionGranted ? "Enabled" : "Disabled")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if notificationManager.isPermissionGranted {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Button("Enable") {
                                        Task {
                                            await notificationManager.requestPermission()
                                        }
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                            
                            if notificationManager.isPermissionGranted {
                                Text("You'll receive notifications about your favorite venues")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if userManager.currentUser?.isAdmin == true {
                        Section(header: Text("Admin")) {
                            Button("Admin Panel") {
                                showAdminPanel = true
                            }
                            Button(action: { showAddVenue = true }) {
                                HStack {
                                    Image(systemName: "plus.circle")
                                    Text("Add Venue Manually")
                                }
                            }
                        }
                    }
                    favoritesSection
                    logoutSection
                }
                .navigationTitle("Profile")
            }
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationView {
                Form {
                    Section(header: Text("Edit Profile")) {
                        TextField("Name", text: $editName)
                        TextField("Email", text: $editEmail)
                            .keyboardType(.emailAddress)
                    }
                }
                .navigationTitle("Edit Profile")
                .navigationBarItems(trailing: Button("Save") {
                    userManager.updateProfile(name: editName, email: editEmail)
                    showEditProfile = false
                })
            }
        }
        .sheet(item: $selectedVenue) { venue in
            VenueDetailView(venue: venue)
                .environmentObject(venueManager)
                .environmentObject(locationManager)
        }
        .sheet(isPresented: $showAdminPanel) {
            AdminMenuApprovalView()
                .environmentObject(venueManager)
                .environmentObject(locationManager)
        }
        .sheet(isPresented: $showAddVenue) {
            AddVenueView()
        }
        .fullScreenCover(isPresented: $showLoginModal, onDismiss: {
            selectedTab = 0
            showProfile = false
        }) {
            LoginView()
                .environmentObject(authViewModel)
                .environmentObject(userManager)
        }
    }

    @ViewBuilder
    private var favoritesSection: some View {
        if !favorites.isEmpty {
            Section(header: Text("Favorite Venues")) {
                ForEach(favorites) { venue in
                    Button(action: {
                        selectedVenue = venue
                    }) {
                        HStack {
                            Text(venue.name)
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var logoutSection: some View {
        if userManager.isLoggedIn {
            Section {
                Button(action: {
                    authViewModel.signOut()
                    showLoginModal = true
                }) {
                    HStack {
                        Image(systemName: "arrow.backward.square")
                        Text("Logout")
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

struct AdminMenuApprovalView: View {
    @EnvironmentObject var venueManager: VenueManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.presentationMode) var presentationMode
    @State private var editingMenuItem: (venue: Venue, item: MenuItem)? = nil
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showApproveAlert = false
    @State private var showRejectAlert = false
    @State private var itemToDelete: (venue: Venue, item: MenuItem)? = nil
    @State private var requestToApprove: (venue: Venue, request: MenuItemRequest)? = nil
    @State private var requestToReject: (venue: Venue, request: MenuItemRequest)? = nil
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var deletedMenuItem: (venue: Venue, item: MenuItem)? = nil
    @State private var showUndo = false
    @State private var isEditingInline: [String: Bool] = [:]
    @State private var inlineEditName: [String: String] = [:]
    @State private var inlineEditType: [String: String] = [:]
    @State private var inlineEditPrice: [String: String] = [:]
    @State private var selectedTypeFilter: String = "All"
    @State private var selectedSort: String = "Name"
    @State private var selectedItems: Set<String> = []
    @State private var showBatchDeleteAlert = false
    @State private var isLoading = false
    let types = ["All", "food", "drink"]
    let sortOptions = ["Name", "Price", "Type"]
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Sorting & Filtering
                    HStack {
                        Picker("Sort by", selection: $selectedSort) {
                            ForEach(sortOptions, id: \.self) { opt in
                                Text(opt)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        Picker("Type", selection: $selectedTypeFilter) {
                            ForEach(types, id: \.self) { t in
                                Text(t.capitalized)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding(.horizontal)
                    
                    // Admin Actions
                    Button(action: {
                        seedVenueData()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.on.square")
                            Text("Seed Venues from Google Places")
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    
                    List {
                        if venueManager.venues.allSatisfy({ $0.menuRequests.isEmpty && $0.menu.isEmpty }) {
                            VStack(spacing: 16) {
                                Image(systemName: "tray")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("No menu requests or menu items.")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            ForEach(venueManager.venues) { venue in
                                if !venue.menuRequests.isEmpty || !venue.menu.isEmpty {
                                    Section(header: Text(venue.name)) {
                                        // Pending requests
                                        ForEach(venue.menuRequests) { request in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(request.name) (") + Text(request.type.capitalized) + Text(") - $\(String(format: "%.2f", request.price))")
                                                    .font(.headline)
                                                Text("Submitted by: \(request.submittedBy)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                HStack {
                                                    Button(action: {
                                                        requestToApprove = (venue, request)
                                                        showApproveAlert = true
                                                    }) {
                                                        Text("Approve")
                                                            .foregroundColor(.green)
                                                    }
                                                    .accessibilityLabel("Approve menu request")
                                                    Button(action: {
                                                        requestToReject = (venue, request)
                                                        showRejectAlert = true
                                                    }) {
                                                        Text("Reject")
                                                            .foregroundColor(.red)
                                                    }
                                                    .accessibilityLabel("Reject menu request")
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                        // Current menu items
                                        let filteredMenu = venue.menu.filter { selectedTypeFilter == "All" || $0.type == selectedTypeFilter }
                                        let sortedMenu = filteredMenu.sorted { lhs, rhs in
                                            switch selectedSort {
                                            case "Name": return lhs.name < rhs.name
                                            case "Price": return lhs.price < rhs.price
                                            case "Type": return lhs.type < rhs.type
                                            default: return lhs.name < rhs.name
                                            }
                                        }
                                        if !sortedMenu.isEmpty {
                                            Text("Current Menu Items:")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            ForEach(sortedMenu) { item in
                                                HStack {
                                                    if let itemId = item.id {
                                                        if selectedItems.contains(itemId) {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .foregroundColor(.blue)
                                                                .onTapGesture {
                                                                    selectedItems.remove(itemId)
                                                                }
                                                                .accessibilityLabel("Deselect item")
                                                        } else {
                                                            Image(systemName: "circle")
                                                                .foregroundColor(.gray)
                                                                .onTapGesture {
                                                                    selectedItems.insert(itemId)
                                                                }
                                                                .accessibilityLabel("Select item")
                                                        }
                                                        if isEditingInline[itemId] == true {
                                                            TextField("Name", text: Binding(get: {
                                                                inlineEditName[itemId] ?? item.name
                                                            }, set: { newValue in
                                                                inlineEditName[itemId] = newValue
                                                            }))
                                                            .frame(width: 80)
                                                            Picker("Type", selection: Binding(get: {
                                                                inlineEditType[itemId] ?? item.type
                                                            }, set: { newValue in
                                                                inlineEditType[itemId] = newValue
                                                            })) {
                                                                ForEach(["food", "drink"], id: \.self) { t in
                                                                    Text(t.capitalized)
                                                                }
                                                            }
                                                            .frame(width: 70)
                                                            TextField("Price", text: Binding(get: {
                                                                inlineEditPrice[itemId] ?? String(format: "%.2f", item.price)
                                                            }, set: { newValue in
                                                                inlineEditPrice[itemId] = newValue
                                                            }))
                                                            .frame(width: 60)
                                                            .keyboardType(.decimalPad)
                                                            Button(action: {
                                                                // Save inline edit
                                                                if let name = inlineEditName[itemId], let type = inlineEditType[itemId], let priceStr = inlineEditPrice[itemId], let price = Double(priceStr) {
                                                                    let updated = MenuItem(id: item.id, name: name, type: type, price: price)
                                                                    updateMenuItem(updated, for: venue)
                                                                    isEditingInline[itemId] = false
                                                                    showToastWithMessage("Menu item updated!")
                                                                    haptic(.success)
                                                                }
                                                            }) {
                                                                Image(systemName: "checkmark")
                                                                    .foregroundColor(.green)
                                                            }
                                                            .accessibilityLabel("Save changes")
                                                            Button(action: {
                                                                isEditingInline[itemId] = false
                                                            }) {
                                                                Image(systemName: "xmark")
                                                                    .foregroundColor(.red)
                                                            }
                                                            .accessibilityLabel("Cancel editing")
                                                        } else {
                                                            VStack(alignment: .leading) {
                                                                Text("\(item.name) (") + Text(item.type.capitalized) + Text(") - $\(String(format: "%.2f", item.price))")
                                                                    .font(.body)
                                                            }
                                                            Spacer()
                                                            Button(action: {
                                                                isEditingInline[itemId] = true
                                                                inlineEditName[itemId] = item.name
                                                                inlineEditType[itemId] = item.type
                                                                inlineEditPrice[itemId] = String(format: "%.2f", item.price)
                                                            }) {
                                                                Image(systemName: "pencil")
                                                                    .foregroundColor(.blue)
                                                            }
                                                            .accessibilityLabel("Edit menu item inline")
                                                            Button(action: {
                                                                itemToDelete = (venue, item)
                                                                showDeleteAlert = true
                                                            }) {
                                                                Image(systemName: "trash")
                                                                    .foregroundColor(.red)
                                                            }
                                                            .accessibilityLabel("Delete menu item")
                                                        }
                                                    }
                                                }
                                                .padding(.vertical, 2)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Menu Requests")
                .navigationBarItems(trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                })
                if showToast {
                    VStack {
                        Spacer()
                        HStack {
                            Text(toastMessage)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(16)
                            if showUndo {
                                Button("Undo") {
                                    undoDelete()
                                }
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 8)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut, value: showToast)
                }
                if isLoading {
                    Color.black.opacity(0.2)
                        .edgesIgnoringSafeArea(.all)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(title: Text("Delete Menu Item"), message: Text("Are you sure you want to delete this menu item?"), primaryButton: .destructive(Text("Delete")) {
                    if let (venue, item) = itemToDelete {
                        deleteMenuItem(item, for: venue)
                        deletedMenuItem = (venue, item)
                        showUndo = true
                        showToastWithMessage("Menu item deleted!")
                        haptic(.warning)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showUndo = false
                        }
                    }
                }, secondaryButton: .cancel())
            }
            .alert(isPresented: $showApproveAlert) {
                Alert(title: Text("Approve Menu Request"), message: Text("Approve this menu item request?"), primaryButton: .default(Text("Approve")) {
                    if let (venue, request) = requestToApprove {
                        approveRequest(request, for: venue)
                        showToastWithMessage("Menu item approved!")
                        haptic(.success)
                    }
                }, secondaryButton: .cancel())
            }
            .alert(isPresented: $showRejectAlert) {
                Alert(title: Text("Reject Menu Request"), message: Text("Reject this menu item request?"), primaryButton: .destructive(Text("Reject")) {
                    if let (venue, request) = requestToReject {
                        rejectRequest(request, for: venue)
                        showToastWithMessage("Menu item rejected.")
                        haptic(.warning)
                    }
                }, secondaryButton: .cancel())
            }
            .alert(isPresented: $showBatchDeleteAlert) {
                Alert(title: Text("Delete Selected Items"), message: Text("Are you sure you want to delete all selected menu items?"), primaryButton: .destructive(Text("Delete")) {
                    batchDeleteSelectedItems()
                    showToastWithMessage("Selected items deleted!")
                    haptic(.warning)
                }, secondaryButton: .cancel())
            }
        }
        .overlay(
            Group {
                if !selectedItems.isEmpty {
                    VStack(spacing: 12) {
                        Button(action: {
                            showBatchDeleteAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Selected (") + Text("\(selectedItems.count)") + Text(")")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                        }
                        .accessibilityLabel("Delete selected menu items")
                        Button(action: {
                            approveSelectedItems()
                        }) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Approve Selected (") + Text("\(selectedItems.count)") + Text(")")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                        }
                        .accessibilityLabel("Approve selected menu requests")
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.9)
                    .padding(.bottom, 24)
                }
            }, alignment: .bottom
        )
    }
    
    private func approveRequest(_ request: MenuItemRequest, for venue: Venue) {
        if let venueIdx = venueManager.venues.firstIndex(where: { $0.id == venue.id }) {
            let menuItem = MenuItem(name: request.name, type: request.type, price: request.price)
            venueManager.venues[venueIdx].menu.append(menuItem)
            if let reqIdx = venueManager.venues[venueIdx].menuRequests.firstIndex(where: { $0.id == request.id }) {
                venueManager.venues[venueIdx].menuRequests.remove(at: reqIdx)
            }
        }
    }
    
    private func rejectRequest(_ request: MenuItemRequest, for venue: Venue) {
        if let venueIdx = venueManager.venues.firstIndex(where: { $0.id == venue.id }) {
            if let reqIdx = venueManager.venues[venueIdx].menuRequests.firstIndex(where: { $0.id == request.id }) {
                venueManager.venues[venueIdx].menuRequests.remove(at: reqIdx)
            }
        }
    }
    
    private func deleteMenuItem(_ item: MenuItem, for venue: Venue) {
        if let venueIdx = venueManager.venues.firstIndex(where: { $0.id == venue.id }) {
            if let itemIdx = venueManager.venues[venueIdx].menu.firstIndex(where: { $0.id == item.id }) {
                venueManager.venues[venueIdx].menu.remove(at: itemIdx)
            }
        }
    }
    
    private func updateMenuItem(_ updatedItem: MenuItem, for venue: Venue) {
        if let venueIdx = venueManager.venues.firstIndex(where: { $0.id == venue.id }) {
            if let itemIdx = venueManager.venues[venueIdx].menu.firstIndex(where: { $0.id == updatedItem.id }) {
                venueManager.venues[venueIdx].menu[itemIdx] = updatedItem
            }
        }
    }
    
    private func batchDeleteSelectedItems() {
        for venue in venueManager.venues {
            for item in venue.menu {
                if let itemId = item.id, selectedItems.contains(itemId) {
                    deleteMenuItem(item, for: venue)
                }
            }
        }
        selectedItems.removeAll()
    }
    
    private func undoDelete() {
        if let (venue, item) = deletedMenuItem {
            if let venueIdx = venueManager.venues.firstIndex(where: { $0.id == venue.id }) {
                venueManager.venues[venueIdx].menu.append(item)
            }
            showUndo = false
            showToastWithMessage("Delete undone!")
            haptic(.success)
        }
    }
    
    private func showToastWithMessage(_ message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
    
    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
#endif
    }
    
    private func approveSelectedItems() {
        for venue in venueManager.venues {
            for item in venue.menu {
                if let itemId = item.id, selectedItems.contains(itemId) {
                    // If the item is a menu request, approve it
                    if let request = venue.menuRequests.first(where: { $0.name == item.name && $0.type == item.type && $0.price == item.price }) {
                        approveRequest(request, for: venue)
                    }
                }
            }
        }
        selectedItems.removeAll()
        showToastWithMessage("Selected items approved!")
        haptic(.success)
    }

    private func seedVenueData() {
        Task {
            let seeder = DataSeeder()
            if let location = locationManager.lastLocation {
                print("Seeding at user location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                await seeder.seedVenues(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            } else {
                // Fallback location: Boulder, Colorado
                print("Seeding at fallback location: 40.014984, -105.270546 (Boulder, CO)")
                await seeder.seedVenues(latitude: 40.014984, longitude: -105.270546)
            }
        }
    }
}

struct EditMenuItemSheet: View {
    var venue: Venue
    var item: MenuItem
    var onSave: (MenuItem) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String
    @State private var type: String
    @State private var price: String
    let types = ["food", "drink"]
    init(venue: Venue, item: MenuItem, onSave: @escaping (MenuItem) -> Void) {
        self.venue = venue
        self.item = item
        self.onSave = onSave
        _name = State(initialValue: item.name)
        _type = State(initialValue: item.type)
        _price = State(initialValue: String(format: "%.2f", item.price))
    }
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Menu Item")) {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { t in
                            Text(t.capitalized)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Menu Item")
            .navigationBarItems(trailing: Button("Save") {
                if let priceValue = Double(price) {
                    let updated = MenuItem(id: item.id, name: name, type: type, price: priceValue)
                    onSave(updated)
                    presentationMode.wrappedValue.dismiss()
                }
            })
        }
    }
} 