import SwiftUI

struct AppleMockupView: View {
    // State untuk Custom Panel (Bisa diubah sebelum SS)
    @AppStorage("mock_balance") private var balanceUSD: String = "450.50"
    @AppStorage("mock_admin_name") private var adminName: String = "iBaaL Enterprise Partner"
    
    // State Form Order
    @State private var selectedPlan: PlanOption = .threeMonths
    @State private var customPriceUSD: String = "1.46"
    @State private var buyerUDID: String = ""
    @State private var buyerName: String = ""
    @State private var certPassword: String = "ibaalcert"
    
    // State Animasi & Progress
    @State private var isProcessing: Bool = false
    @State private var progressStep: Int = 0
    @State private var statusMessage: String = "Ready to dispatch..."
    @State private var isCompleted: Bool = false
    
    // State Modal Setting / Edit Saldo & Profil
    @State private var showSettingsModal: Bool = false
    @State private var tempBalance: String = ""
    @State private var tempAdminName: String = ""

    enum PlanOption: String, CaseIterable, Identifiable {
        case threeMonths = "SALE Plan 3 Month"
        case fiveMonths = "SALE Plan 5 Month"
        case twelveMonths = "SALE Plan 12 Month"
        var id: String { self.rawValue }
        
        var defaultUSD: String {
            switch self {
            case .threeMonths: return "1.46"
            case .fiveMonths: return "2.20"
            case .twelveMonths: return "4.50"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // MARK: - 1. HEADER / SALDO & ADMIN PANEL (Bisa Di-tap untuk Edit)
                        Button(action: {
                            tempBalance = balanceUSD
                            tempAdminName = adminName
                            showSettingsModal = true
                        }) {
                            HStack(spacing: 15) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 55, height: 55)
                                    Image(systemName: "person.fill.badge.shield.checkmark")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(adminName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("API Status: 🟢 Connected (Apple API)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text("Balance: $\(balanceUSD)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        
                        // MARK: - 2. FORM SIMULASI PEMBELIAN
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Apple Developer Order Panel")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            // Pilih Plan
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Service Type / Plan").font(.caption).foregroundColor(.secondary)
                                Picker("Plan", selection: $selectedPlan) {
                                    ForEach(PlanOption.allCases) { plan in
                                        Text(plan.rawValue).tag(plan)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: selectedPlan) { newValue in
                                    customPriceUSD = newValue.defaultUSD
                                }
                            }
                            
                            // Custom Harga USD (Bisa di-edit sebelum SS)
                            HStack(spacing: 15) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Purchase Price (USD)").font(.caption).foregroundColor(.secondary)
                                    HStack {
                                        Text("$").foregroundColor(.secondary)
                                        TextField("1.46", text: $customPriceUSD)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Estimated Delivery").font(.caption).foregroundColor(.secondary)
                                    Text("Instant delivery ⚡️")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.vertical, 6)
                                }
                            }
                            
                            // Input Buyer & UDID
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Buyer Name / Nickname").font(.caption).foregroundColor(.secondary)
                                TextField("Contoh: Rkii / Buyer Toko", text: $buyerName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Device UDID (40 Characters)").font(.caption).foregroundColor(.secondary)
                                TextField("Masukkan 40 digit UDID...", text: $buyerUDID)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Certificate Password").font(.caption).foregroundColor(.secondary)
                                TextField("ibaalcert", text: $certPassword)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            // Tombol Submit Order
                            Button(action: {
                                startSimulatedOrder()
                            }) {
                                HStack {
                                    Spacer()
                                    if isProcessing {
                                        ProgressView()
                                            .tint(.white)
                                            .padding(.trailing, 8)
                                        Text("Processing with Apple...")
                                    } else {
                                        Image(systemName: "cloud.fill")
                                        Text("Submit Order to Server")
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(buyerUDID.count < 10 ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .cornerRadius(12)
                            }
                            .disabled(isProcessing || buyerUDID.count < 10)
                            .padding(.top, 5)
                            
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        
                        // MARK: - 3. PROGRESS / HASIL OUTPUT REAL-TIME
                        if isProcessing || isCompleted {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Live Transaction Logs")
                                        .font(.headline)
                                    Spacer()
                                    Circle()
                                        .fill(isCompleted ? Color.green : Color.orange)
                                        .frame(width: 10, height: 10)
                                    Text(isCompleted ? "Success" : "In Progress")
                                        .font(.caption)
                                        .foregroundColor(isCompleted ? .green : .orange)
                                }
                                
                                Divider()
                                
                                Text(statusMessage)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                if isCompleted {
                                    VStack(spacing: 10) {
                                        HStack {
                                            Label("Warranty: 90 Days Active", systemImage: "checkmark.shield.fill")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                            Spacer()
                                            Text("Cost: $\(customPriceUSD)")
                                                .font(.caption)
                                                .bold()
                                        }
                                        
                                        // Tombol Download Sertifikat Fiktif
                                        Button(action: {
                                            // Aksi simulasi download zip
                                        }) {
                                            Label("Download .p12 & .mobileprovision", systemImage: "arrow.down.doc.fill")
                                                .frame(maxWidth: .infinity)
                                                .padding(10)
                                                .background(Color.green)
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                                .font(.subheadline)
                                                .bold()
                                        }
                                    }
                                    .padding(.top, 6)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                        
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Apple Reseller Console")
            // MARK: - MODAL EDIT SALDO & NAMA ADMIN
            .sheet(isPresented: $showSettingsModal) {
                NavigationStack {
                    Form {
                        Section(header: Text("Custom Panel Display (Untuk Screenshot)")) {
                            TextField("Saldo USD (Contoh: 450.50)", text: $tempBalance)
                                .keyboardType(.decimalPad)
                            TextField("Nama / Brand Admin", text: $tempAdminName)
                        }
                    }
                    .navigationTitle("Customize Mockup")
                    .navigationBarItems(
                        leading: Button("Batal") { showSettingsModal = false },
                        trailing: Button("Simpan") {
                            balanceUSD = tempBalance
                            adminName = tempAdminName
                            showSettingsModal = false
                        }.bold()
                    )
                }
            }
        }
    }
    
    // MARK: - LOGIKA ANIMASI REAL-TIME
    func startSimulatedOrder() {
        isProcessing = true
        isCompleted = false
        progressStep = 1
        statusMessage = "[0.2s] Connecting to Apple Provisioning Portal..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            statusMessage = "[1.2s] Validating UDID: \(buyerUDID.prefix(10))..."
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                statusMessage = "[2.5s] Generating CSR & Signing with Enterprise Key..."
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    statusMessage = "[3.5s] ✅ Success! Certificate compiled & ready for \(buyerName.isEmpty ? "Customer" : buyerName)."
                    isProcessing = false
                    isCompleted = true
                }
            }
        }
    }
}
