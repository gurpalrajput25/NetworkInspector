import SwiftUI
import NetworkInspectorCore
import NetworkInspectorStorage

public struct RequestListView: View {
    @ObservedObject var logStore: NetworkLogStore = .shared

    @State private var filter = NetworkLogFilter()
    @State private var selectedTransaction: NetworkTransaction?
    @State private var showingClearConfirmation = false
    @State private var isSelectionMode = false
    @State private var selectedIDs = Set<UUID>()

    public init() {}

    private var filteredTransactions: [NetworkTransaction] {
        filter.apply(to: logStore.transactions)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Filter and Search Header
            searchAndFilterBar

            // Main List
            if filteredTransactions.isEmpty {
                emptyStateView
            } else {
                List(selection: $selectedIDs) {
                    ForEach(filteredTransactions) { transaction in
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            RequestRowView(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                        .tag(transaction.id)
                    }
                    .onDelete(perform: deleteTransactions)
                }
                .inspectorInsetGroupedListStyle()
            }
        }
        .navigationTitle("Network Requests")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                trailingMenu
            }
            #else
            ToolbarItem(placement: .automatic) {
                trailingMenu
            }
            #endif
        }
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                RequestDetailView(transaction: transaction)
            }
        }
        .alert("Clear All Logs?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                logStore.clearAll()
            }
        } message: {
            Text("This will remove all captured network requests from memory and storage.")
        }
    }

    private var trailingMenu: some View {
        Menu {
            if !selectedIDs.isEmpty {
                Button(role: .destructive, action: deleteSelected) {
                    Label("Delete (\(selectedIDs.count))", systemImage: "trash")
                }
            }

            Button(role: .destructive, action: { showingClearConfirmation = true }) {
                Label("Clear All Logs", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            // Search Input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search URL, host, path, status...", text: $filter.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                if !filter.searchText.isEmpty {
                    Button {
                        filter.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color.inspectorTertiaryFill)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(StatusFilter.allCases) { status in
                        Button {
                            filter.selectedStatus = status
                        } label: {
                            Text(status.rawValue)
                                .font(.caption.weight(filter.selectedStatus == status ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(filter.selectedStatus == status ? Color.accentColor : Color.inspectorTertiaryFill)
                                .foregroundColor(filter.selectedStatus == status ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Menu {
                        Button("Any Method") { filter.selectedMethod = nil }
                        Divider()
                        ForEach(HTTPMethod.allCases, id: \.self) { method in
                            Button(method.rawValue) { filter.selectedMethod = method }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(filter.selectedMethod?.rawValue ?? "Method")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9))
                        }
                        .font(.caption.weight(filter.selectedMethod != nil ? .bold : .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(filter.selectedMethod != nil ? Color.accentColor : Color.inspectorTertiaryFill)
                        .foregroundColor(filter.selectedMethod != nil ? .white : .primary)
                        .clipShape(Capsule())
                    }

                    Toggle(isOn: $filter.onlyErrors) {
                        Text("Errors Only")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.inspectorSecondaryBackground)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Requests Found")
                .font(.headline)
            Text(logStore.transactions.isEmpty
                 ? "Network requests made by your application will appear here automatically."
                 : "Try adjusting your search query or filter chips.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        logStore.delete(at: offsets)
    }

    private func deleteSelected() {
        logStore.delete(ids: selectedIDs)
        selectedIDs.removeAll()
    }
}
