// The flows menu: Sign-up × Step-up, filtered by region. Same choices as web/views/menu.ejs.
import SwiftUI

private let groups = [("sign-up", "Sign-up"), ("step-up", "Step-up")]
private let regions = [("all", "All"), ("global", "Global"), ("brazil", "Brazil"), ("mexico", "Mexico")]

struct FlowsScreen: View {
    let flows: [Flow]
    let onPick: (Flow) -> Void

    @State private var group = "sign-up"
    @State private var region = "all"

    var body: some View {
        let shown = filterFlows(flows, group: group, region: region)
        List {
            Section {
                Picker("Use case", selection: $group) {
                    ForEach(groups, id: \.0) { Text($0.1).tag($0.0) }
                }
                .pickerStyle(.segmented)
                Picker("Region", selection: $region) {
                    ForEach(regions, id: \.0) { Text($0.1).tag($0.0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                ForEach(shown, id: \.id) { flow in
                    Button { onPick(flow) } label: {
                        VStack(alignment: .leading) {
                            Text(flow.id).font(.body.monospaced())
                            Text(([flow.region] + flow.capabilities).joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                if shown.isEmpty { Text("No \(group) flows for this region.") }
            }
        }
        .navigationTitle("Unico API flows")
    }
}
