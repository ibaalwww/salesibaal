import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Format Helper Global
struct AppFormatters {
    static func idr(_ num: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "id_ID")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: num)) ?? "Rp 0"
    }
    
    static func date(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy, HH:mm"
        return f.string(from: d)
    }
}

// MARK: - Manajer Auto-Save & Dokumen
class AutoSaveManager {
    static let shared = AutoSaveManager()
    
    private var autoBackupURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iBaalCell_AutoBackup.json")
    }
    
    func save(_ debtors: [Debtor]) {
        DispatchQueue.global(qos: .background).async {
            guard let data = try? JSONEncoder().encode(debtors) else { return }
            try? data.write(to: self.autoBackupURL, options: .atomic)
        }
    }
    
    func load() -> [Debtor]? {
        guard let data = try? Data(contentsOf: autoBackupURL) else { return nil }
        return try? JSONDecoder().decode([Debtor].self, from: data)
    }
}

func saveAllData(_ debtors: [Debtor]) {
    if let encoded = try? JSONEncoder().encode(debtors) {
        UserDefaults.standard.set(encoded, forKey: "ibaal_cell_debtors")
    }
    AutoSaveManager.shared.save(debtors)
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Model Data
enum DebtType: String, Codable, Equatable {
    case hutangKu = "Hutangku"
    case piutang = "Piutang"
}

enum StatusFilter: String {
    case aktif = "Masih Nyicil"
    case selesai = "Selesai (Lunas)"
}

struct DebtTransaction: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var amount: Int
    var note: String
    var isPayment: Bool
    
    var nominalValue: Int {
        return isPayment ? -amount : amount
    }
}

struct Debtor: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phone: String
    var type: DebtType
    var createdAt: Date
    var transactions: [DebtTransaction]
    
    var totalHutang: Int {
        transactions.reduce(0) { $0 + $1.nominalValue }
    }
    var totalPinjaman: Int {
        transactions.filter { !$0.isPayment }.reduce(0) { $0 + $1.amount }
    }
    var totalDibayar: Int {
        transactions.filter { $0.isPayment }.reduce(0) { $0 + $1.amount }
    }
    var isLunas: Bool {
        return !transactions.isEmpty && totalHutang <= 0
    }
}

// MARK: - Modifier Liquid Glass
extension View {
    func liquidGlass() -> some View {
        self
            .background(Color.black.opacity(0.45))
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.3), lineWidth: 1.0))
            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

struct InputRow: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var color: Color
    var isNumber: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
            TextField(placeholder, text: $text)
                .keyboardType(isNumber ? .numberPad : .default)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(14)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
        }
        .padding(12)
        .liquidGlass()
    }
}

// MARK: - App Entry Point
@main
struct iBaalCellApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Tampilan Utama
struct ContentView: View {
    @State private var debtors: [Debtor] = []
    @State private var showAddDebtor = false
    @State private var searchText = ""
    @State private var activeTab: DebtType = .hutangKu
    @State private var statusFilter: StatusFilter = .aktif
    
    // SISTEM KEAMANAN & SENSOR LIST A
    @AppStorage("listA_MasterPIN") private var savedPIN: String = "1234" // Default PIN
    @State private var isListAUnhidden: Bool = false // Default selalu tertutup / sensor aktif!
    @State private var showPinSheet = false
    @State private var showChangePinSheet = false
    
    @State private var showOptionsMenu = false
    @State private var showFileImporter = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    // Logika sensor: List A disensor jika belum buka sandi, List B selalu terbuka
    var isFinancialHidden: Bool {
        if activeTab == .hutangKu {
            return !isListAUnhidden
        } else {
            return false // List B selalu terbuka bebas
        }
    }
    
    var tabDebtors: [Debtor] {
        debtors.filter { $0.type == activeTab }
    }
    
    var statusFilteredDebtors: [Debtor] {
        if statusFilter == .aktif {
            return tabDebtors.filter { !$0.isLunas }
        } else {
            return tabDebtors.filter { $0.isLunas }
        }
    }
    
    var filteredDebtors: [Debtor] {
        if searchText.isEmpty { return statusFilteredDebtors }
        return statusFilteredDebtors.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var totalActiveDebt: Int {
        tabDebtors.reduce(0) { $0 + max(0, $1.totalHutang) }
    }
    
    var countAktif: Int {
        tabDebtors.filter { !$0.isLunas }.count
    }
    
    var countSelesai: Int {
        tabDebtors.filter { $0.isLunas }.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
                
                VStack(spacing: 10) {
                    customTopBar
                    tabSwitchView
                    dashboardCard
                    statusSubTabView
                    searchBarView
                    debtorListView
                }
                
                if showOptionsMenu {
                    optionsMenuOverlay
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddDebtor) {
                AddDebtorSheet(debtors: $debtors, currentTab: activeTab)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
            .sheet(isPresented: $showPinSheet) {
                PinUnlockSheet(correctPIN: savedPIN) {
                    withAnimation { isListAUnhidden = true }
                }
            }
            .sheet(isPresented: $showChangePinSheet) {
                ChangePinSheet(currentSavedPIN: $savedPIN)
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json, .plainText]) { result in
                handleImport(result: result)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear { loadData() }
        }
        .navigationViewStyle(.stack)
    }
    
    private var tabSwitchView: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation { 
                    activeTab = .hutangKu
                    // Kunci kembali saat switch ke List A biar aman
                    isListAUnhidden = false
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isListAUnhidden ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 11))
                    Text("List A (Hutangku)")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(activeTab == .hutangKu ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(activeTab == .hutangKu ? Color.red.opacity(0.35) : Color.clear)
                .cornerRadius(10)
            }
            
            Button {
                withAnimation { activeTab = .piutang }
            } label: {
                Text("List B (Piutang)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(activeTab == .piutang ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(activeTab == .piutang ? Color.cyan.opacity(0.35) : Color.clear)
                    .cornerRadius(10)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var statusSubTabView: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation { statusFilter = .aktif }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Masih Nyicil (\(countAktif))")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusFilter == .aktif ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(statusFilter == .aktif ? Color.orange : Color.white.opacity(0.08))
                .cornerRadius(10)
            }
            
            Button {
                withAnimation { statusFilter = .selesai }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Selesai / Lunas (\(countSelesai))")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusFilter == .selesai ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(statusFilter == .selesai ? Color.green : Color.white.opacity(0.08))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }
    
    private var dashboardCard: some View {
        VStack(spacing: 6) {
            HStack {
                Text(activeTab == .hutangKu ? "TOTAL SISA HUTANG SAYA" : "TOTAL SISA UANG DI LUAR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                
                // Khusus List A ada tombol mata gembok sandi
                if activeTab == .hutangKu {
                    Button {
                        if isListAUnhidden {
                            withAnimation { isListAUnhidden = false }
                        } else {
                            showPinSheet = true
                        }
                    } label: {
                        Image(systemName: isListAUnhidden ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(4)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            
            Text(isFinancialHidden ? "Rp •••••••" : AppFormatters.idr(totalActiveDebt))
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(isFinancialHidden ? .gray : (totalActiveDebt <= 0 ? .green : (activeTab == .hutangKu ? .red : .cyan)))
            
            if isFinancialHidden {
                Text("🔒 Terkunci PIN Sandi (Ketuk ikon mata)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .liquidGlass()
        .padding(.horizontal)
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Cari nama...", text: $searchText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(10)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var debtorListView: some View {
        ScrollView {
            VStack(spacing: 10) {
                if filteredDebtors.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: statusFilter == .selesai ? "checkmark.circle" : "folder.badge.person.crop")
                            .font(.system(size: 36))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(statusFilter == .selesai ? "Belum ada data di Kloter Selesai (Lunas)." : "Belum ada daftar cicilan aktif.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(filteredDebtors) { debtor in
                        NavigationLink(destination: DebtorDetailView(
                            debtor: debtor,
                            allDebtors: $debtors,
                            isListAUnhidden: $isListAUnhidden,
                            onRequirePin: { showPinSheet = true }
                        )) {
                            debtorRowCard(debtor: debtor)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.bottom, 40)
        }
    }
    
    private func debtorRowCard(debtor: Debtor) -> some View {
        let isHidden = (debtor.type == .hutangKu && !isListAUnhidden)
        
        return HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(debtor.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    if debtor.isLunas {
                        Text("LUNAS")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(6)
                    }
                }
                
                Text("Awal: " + (isHidden ? "Rp •••" : AppFormatters.idr(debtor.totalPinjaman)) + " • Dicicil: " + (isHidden ? "Rp •••" : AppFormatters.idr(debtor.totalDibayar)))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(debtor.isLunas ? "Lunas" : "Sisa:")
                    .font(.system(size: 10))
                    .foregroundColor(debtor.isLunas ? .green : .gray)
                Text(isHidden ? "Rp •••••" : AppFormatters.idr(debtor.totalHutang))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isHidden ? .gray : (debtor.totalHutang > 0 ? (debtor.type == .hutangKu ? .red : .orange) : .green))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)
                .padding(.leading, 6)
        }
        .padding(14)
        .liquidGlass()
        .padding(.horizontal)
    }
    
    private var optionsMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture {
                withAnimation { showOptionsMenu = false }
            }
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            withAnimation { showOptionsMenu = false }
                            showChangePinSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "key.fill").foregroundColor(.orange)
                                Text("Ganti PIN Sandi List A").foregroundColor(.white)
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.15))
                        
                        Button {
                            withAnimation { showOptionsMenu = false }
                            exportBackup()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up").foregroundColor(.yellow)
                                Text("Cadangkan (Backup)").foregroundColor(.white)
                            }
                        }
                        Button {
                            withAnimation { showOptionsMenu = false }
                            showFileImporter = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down").foregroundColor(.purple)
                                Text("Pulihkan (Restore)").foregroundColor(.white)
                            }
                        }
                    }
                    .padding(16)
                    .liquidGlass()
                    .padding(.leading, 14)
                    .padding(.top, 50)
                    Spacer()
                }
                Spacer()
            }
        }
        .zIndex(99)
    }
    
    private var customTopBar: some View {
        HStack {
            Button {
                withAnimation { showOptionsMenu.toggle() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            Spacer()
            Text("i B a a L   C E L L")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.white)
            Spacer()
            Button {
                showAddDebtor = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 38, height: 38)
                    .background(Color.cyan)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "ibaal_cell_debtors"),
           let decoded = try? JSONDecoder().decode([Debtor].self, from: data) {
            debtors = decoded
        } else if let autoSaved = AutoSaveManager.shared.load() {
            debtors = autoSaved
        }
    }
    
    private func exportBackup() {
        do {
            let data = try JSONEncoder().encode(debtors)
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd_HHmm"
            let fn = "Backup_iBaalCell_\(df.string(from: Date())).txt"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fn)
            try data.write(to: url)
            shareItems = [url]
            showShareSheet = true
        } catch {
            alertMessage = "Gagal backup."
            showAlert = true
        }
    }
    
    private func handleImport(result: Result<URL, Error>) {
        guard let url = try? result.get() else { return }
        let canAccess = url.startAccessingSecurityScopedResource()
        defer { if canAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let imported = try? JSONDecoder().decode([Debtor].self, from: data) else {
            alertMessage = "Gagal memulihkan data!"
            showAlert = true
            return
        }
        debtors = imported
        saveAllData(debtors)
        alertMessage = "Sukses memulihkan \(imported.count) data!"
        showAlert = true
    }
}

// MARK: - Layar Masukkan PIN Sandi
struct PinUnlockSheet: View {
    @Environment(\.presentationMode) var presentationMode
    var correctPIN: String
    var onSuccess: () -> Void
    
    @State private var inputPIN: String = ""
    @State private var isWrongPIN: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.cyan)
                        .padding(.top, 30)
                    
                    Text("Buka Sensor List A")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Masukkan 4 digit PIN Sandi kamu untuk melihat nominal hutang.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    SecureField("••••", text: $inputPIN)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(14)
                        .padding(.horizontal, 60)
                    
                    if isWrongPIN {
                        Text("PIN Salah! Coba lagi.")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    }
                    
                    Button {
                        if inputPIN == correctPIN {
                            onSuccess()
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            isWrongPIN = true
                            inputPIN = ""
                        }
                    } label: {
                        Text("Buka Sandi")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cyan)
                            .cornerRadius(14)
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// MARK: - Layar Ganti PIN Sandi
struct ChangePinSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var currentSavedPIN: String
    
    @State private var oldPIN: String = ""
    @State private var newPIN: String = ""
    @State private var errorText: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    InputRow(title: "PIN LAMA", placeholder: "PIN saat ini...", text: $oldPIN, color: .orange, isNumber: true)
                    InputRow(title: "PIN BARU", placeholder: "4 digit baru...", text: $newPIN, color: .cyan, isNumber: true)
                    
                    if !errorText.isEmpty {
                        Text(errorText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Ganti PIN List A")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Simpan") {
                        if oldPIN != currentSavedPIN {
                            errorText = "PIN Lama salah!"
                        } else if newPIN.count < 4 {
                            errorText = "PIN baru minimal 4 angka!"
                        } else {
                            currentSavedPIN = newPIN
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.cyan)
                }
            }
        }
    }
}

// MARK: - Detail Layar Profil
struct DebtorDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    var debtor: Debtor
    @Binding var allDebtors: [Debtor]
    @Binding var isListAUnhidden: Bool
    var onRequirePin: () -> Void
    
    @State private var showTrxSheet = false
    @State private var selectedTrxId: UUID? = nil
    @State private var isPaymentMode = false
    @State private var showEditProfileSheet = false
    
    var currentDebtor: Debtor {
        allDebtors.first(where: { $0.id == debtor.id }) ?? debtor
    }
    
    var isHutangKu: Bool {
        currentDebtor.type == .hutangKu
    }
    
    var isHidden: Bool {
        isHutangKu && !isListAUnhidden
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            VStack(spacing: 0) {
                headerView
                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 8)
                historyView
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showTrxSheet) {
            TransactionFormSheet(
                debtorId: currentDebtor.id,
                transactionId: selectedTrxId,
                defaultIsPayment: isPaymentMode,
                isHutangKu: isHutangKu,
                allDebtors: $allDebtors
            )
        }
        .sheet(isPresented: $showEditProfileSheet) {
            EditDebtorProfileSheet(debtorId: currentDebtor.id, allDebtors: $allDebtors)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
                Spacer()
                
                Button {
                    showEditProfileSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit Data")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Color.cyan.opacity(0.2))
                    .foregroundColor(.cyan)
                    .clipShape(Capsule())
                }
                
                Button {
                    allDebtors.removeAll { $0.id == currentDebtor.id }
                    saveAllData(allDebtors)
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "trash.fill")
                        .frame(width: 40, height: 40)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            
            Text(currentDebtor.name)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.white)
            
            if !currentDebtor.phone.isEmpty {
                Text(currentDebtor.phone)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(currentDebtor.isLunas ? "✅ STATUS: SELESAI / LUNAS" : (isHutangKu ? "SISA HUTANGKU SAAT INI" : "SISA HUTANG DIA"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(currentDebtor.isLunas ? .green : .gray)
                    
                    if isHutangKu {
                        Button {
                            if isListAUnhidden {
                                withAnimation { isListAUnhidden = false }
                            } else {
                                onRequirePin()
                            }
                        } label: {
                            Image(systemName: isListAUnhidden ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.cyan)
                        }
                    }
                }
                
                Text(isHidden ? "Rp •••••••" : AppFormatters.idr(currentDebtor.totalHutang))
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(isHidden ? .gray : (currentDebtor.totalHutang > 0 ? (isHutangKu ? .red : .orange) : .green))
                
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("HUTANG AWAL / TOTAL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        Text(isHidden ? "Rp •••••" : AppFormatters.idr(currentDebtor.totalPinjaman))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 1, height: 24)
                    VStack(spacing: 4) {
                        Text("SUDAH DICICIL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        Text(isHidden ? "Rp •••••" : AppFormatters.idr(currentDebtor.totalDibayar))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.top, 6)
            }
            
            HStack(spacing: 12) {
                Button {
                    selectedTrxId = nil
                    isPaymentMode = false
                    showTrxSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.square.fill")
                        Text(isHutangKu ? "Tambah Hutang" : "Beri Hutang")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }
                
                Button {
                    selectedTrxId = nil
                    isPaymentMode = true
                    showTrxSheet = true
                } label: {
                    HStack {
                        Image(systemName: "minus.square.fill")
                        Text(isHutangKu ? "Bayar Cicilan" : "Terima Cicilan")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(12)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal)
        }
        .padding(.vertical, 6)
    }
    
    private var historyView: some View {
        VStack(alignment: .leading) {
            Text("RIWAYAT CICILAN & HUTANG (Ketuk untuk Edit)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.cyan)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(currentDebtor.transactions.sorted(by: { $0.date > $1.date })) { trx in
                        Button {
                            selectedTrxId = trx.id
                            showTrxSheet = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(trx.note)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    if trx.note != "Hutang Awal" {
                                        Text(AppFormatters.date(trx.date))
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Text(isHidden ? "Rp •••••" : (trx.isPayment ? "-\(AppFormatters.idr(trx.amount))" : "+\(AppFormatters.idr(trx.amount))"))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(isHidden ? .gray : (trx.isPayment ? .green : .red))
                                Image(systemName: "pencil")
                                    .foregroundColor(.cyan)
                                    .padding(.leading, 6)
                            }
                            .padding(14)
                            .liquidGlass()
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Form Edit Profil
struct EditDebtorProfileSheet: View {
    @Environment(\.presentationMode) var presentationMode
    var debtorId: UUID
    @Binding var allDebtors: [Debtor]
    
    @State private var name = ""
    @State private var phone = ""
    @State private var selectedType: DebtType = .hutangKu
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        InputRow(title: "NAMA", placeholder: "Nama...", text: $name, color: .cyan)
                        InputRow(title: "NOMOR WA", placeholder: "08xxxx", text: $phone, color: .cyan, isNumber: true)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PINDAHKAN LIST")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.cyan)
                            Picker("List", selection: $selectedType) {
                                Text("List A (Hutangku)").tag(DebtType.hutangKu)
                                Text("List B (Piutang)").tag(DebtType.piutang)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                        }
                        .padding(12)
                        .liquidGlass()
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Simpan") { saveProfile() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }
            .onAppear { loadProfile() }
        }
    }
    
    func loadProfile() {
        guard let idx = allDebtors.firstIndex(where: { $0.id == debtorId }) else { return }
        name = allDebtors[idx].name
        phone = allDebtors[idx].phone
        selectedType = allDebtors[idx].type
    }
    
    func saveProfile() {
        guard !name.isEmpty, let idx = allDebtors.firstIndex(where: { $0.id == debtorId }) else { return }
        allDebtors[idx].name = name
        allDebtors[idx].phone = phone
        allDebtors[idx].type = selectedType
        saveAllData(allDebtors)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Form Tambah Pelanggan
struct AddDebtorSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var debtors: [Debtor]
    var currentTab: DebtType
    @State private var name = ""
    @State private var phone = ""
    @State private var initialDebt = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        InputRow(title: currentTab == .hutangKu ? "NAMA ORANG/TOKO" : "NAMA PELANGGAN", placeholder: "Misal: Adit", text: $name, color: .cyan)
                        InputRow(title: "NOMOR WA (Opsional)", placeholder: "08xxxx", text: $phone, color: .cyan, isNumber: true)
                        InputRow(title: "HUTANG AWAL KESELURUHAN (Rp)", placeholder: "0", text: $initialDebt, color: .orange, isNumber: true)
                    }
                    .padding()
                }
            }
            .navigationTitle(currentTab == .hutangKu ? "Tambah (List A)" : "Tambah (List B)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Simpan") { saveDebtor() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }
        }
    }
    
    func saveDebtor() {
        if name.isEmpty { return }
        var trxs: [DebtTransaction] = []
        if let v = Int(initialDebt), v > 0 {
            trxs.append(DebtTransaction(date: Date(), amount: v, note: "Hutang Awal", isPayment: false))
        }
        debtors.insert(Debtor(name: name, phone: phone, type: currentTab, createdAt: Date(), transactions: trxs), at: 0)
        saveAllData(debtors)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Form Transaksi Global
struct TransactionFormSheet: View {
    @Environment(\.presentationMode) var presentationMode
    var debtorId: UUID
    var transactionId: UUID?
    var defaultIsPayment: Bool
    var isHutangKu: Bool
    @Binding var allDebtors: [Debtor]
    
    @State private var amount = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var isPayment = false
    
    var isEdit: Bool { transactionId != nil }
    var colorTheme: Color { isPayment ? .green : .red }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        if isEdit {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("JENIS TRANSAKSI").font(.system(size: 12, weight: .bold)).foregroundColor(.cyan)
                                Picker("Jenis", selection: $isPayment) {
                                    Text("Hutang / Pinjaman").tag(false)
                                    Text("Bayar Cicilan").tag(true)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding(8)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                            }
                            .padding(12)
                            .liquidGlass()
                        }
                        
                        InputRow(title: "NOMINAL (Rp)", placeholder: "0", text: $amount, color: colorTheme, isNumber: true)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TANGGAL BAYAR / TRANSAKSI").font(.system(size: 12, weight: .bold)).foregroundColor(.cyan)
                            DatePicker("Pilih", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                        }
                        .padding(12)
                        .liquidGlass()
                        
                        InputRow(title: "CATATAN", placeholder: isPayment ? "Misal: Cicilan ke-1" : "Misal: Hutang Awal", text: $note, color: .cyan)
                        
                        if isEdit {
                            Button {
                                deleteTrx()
                            } label: {
                                Text("Hapus Transaksi Ini")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(14)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEdit ? "Edit Transaksi" : (isPayment ? "Input Cicilan" : "Input Hutang"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Simpan") { saveTrx() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorTheme)
                }
            }
            .onAppear { setup() }
        }
    }
    
    func setup() {
        if let tId = transactionId,
           let dIndex = allDebtors.firstIndex(where: { $0.id == debtorId }),
           let trx = allDebtors[dIndex].transactions.first(where: { $0.id == tId }) {
            amount = String(trx.amount)
            note = trx.note
            date = trx.date
            isPayment = trx.isPayment
        } else {
            isPayment = defaultIsPayment
        }
    }
    
    func saveTrx() {
        guard let v = Int(amount), v > 0,
              let dIndex = allDebtors.firstIndex(where: { $0.id == debtorId }) else { return }
        let fNote = note.isEmpty ? (isPayment ? "Cicilan" : "Hutang") : note
        if let tId = transactionId,
           let tIndex = allDebtors[dIndex].transactions.firstIndex(where: { $0.id == tId }) {
            allDebtors[dIndex].transactions[tIndex] = DebtTransaction(id: tId, date: date, amount: v, note: fNote, isPayment: isPayment)
        } else {
            allDebtors[dIndex].transactions.append(DebtTransaction(date: date, amount: v, note: fNote, isPayment: isPayment))
        }
        saveAllData(allDebtors)
        presentationMode.wrappedValue.dismiss()
    }
    
    func deleteTrx() {
        guard let tId = transactionId,
              let dIndex = allDebtors.firstIndex(where: { $0.id == debtorId }) else { return }
        allDebtors[dIndex].transactions.removeAll(where: { $0.id == tId })
        saveAllData(allDebtors)
        presentationMode.wrappedValue.dismiss()
    }
}
