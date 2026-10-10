import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - App Theme
struct AppTheme {
    static let glassBg = LinearGradient(
        gradient: Gradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.02), Color.clear]),
        startPoint: .top, endPoint: .center
    )
    static let glassBorder = LinearGradient(
        gradient: Gradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0.1), Color.cyan.opacity(0.3)]),
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Format Helper Global (Semua Logika Rumit Dipindah Kesini Biar Swift Nggak Error 65)
struct AppFormatters {
    static func idr(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "id_ID")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: num)) ?? "Rp 0"
    }
    
    static func date(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy, HH:mm"
        return f.string(from: d)
    }
    
    // Helper Teks Dasbor
    static func dashboardTitle(tab: DebtType) -> String {
        return tab == .hutangKu ? "TOTAL SISA HUTANG SAYA" : "TOTAL SISA PIUTANG (UANG DI LUAR)"
    }
    
    // Helper Status
    static func statusText(tab: DebtType, debt: Int) -> String {
        if tab == .hutangKu { return debt > 0 ? "⚠️ Segera lunasi hutangmu!" : "✅ Bebas hutang" }
        return debt > 0 ? "⚠️ Segera tagih agar kas lancar" : "✅ Semua hutang pelanggan lunas"
    }
    
    // Helper Warna Hutang (Anti-Ternary Bersarang)
    static func debtColor(debt: Int, tab: DebtType, isHidden: Bool) -> Color {
        if isHidden { return .gray }
        if debt <= 0 { return .green }
        return tab == .hutangKu ? .red : .orange
    }
    
    // Helper Teks Nominal Disembunyikan
    static func maskedAmount(_ amount: Int, isHidden: Bool) -> String {
        return isHidden ? "Rp •••••" : idr(amount)
    }
    
    // Helper Teks Transaksi Disembunyikan
    static func maskedTrxAmount(amount: Int, isPayment: Bool, isHidden: Bool) -> String {
        if isHidden {
            return isPayment ? "- Rp •••••" : "+ Rp •••••"
        } else {
            return isPayment ? "-\(idr(amount))" : "+\(idr(amount))"
        }
    }
    
    // Helper Warna Transaksi
    static func trxColor(isPayment: Bool, isHidden: Bool) -> Color {
        if isHidden { return .gray }
        return isPayment ? .green : .red
    }
}

// MARK: - Manajer Auto-Save
class AutoSaveManager {
    static let shared = AutoSaveManager()
    private var autoBackupURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("iBaalCell_AutoBackup.json")
    }
    func save(_ debtors: [Debtor]) {
        DispatchQueue.global(qos: .background).async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(debtors)
                try data.write(to: self.autoBackupURL, options: .atomic)
            } catch {}
        }
    }
    func loadAutoSave() -> [Debtor]? {
        guard FileManager.default.fileExists(atPath: autoBackupURL.path) else { return nil }
        do {
            return try JSONDecoder().decode([Debtor].self, from: try Data(contentsOf: autoBackupURL))
        } catch { return nil }
    }
}

func saveAllData(_ debtors: [Debtor]) {
    if let encoded = try? JSONEncoder().encode(debtors) {
        UserDefaults.standard.set(encoded, forKey: "ibaal_cell_debtors")
    }
    AutoSaveManager.shared.save(debtors)
}

// MARK: - File Exporter (Fitur Backup ke File/iCloud)
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileContents: data)
    }
}

// MARK: - Model Data
enum DebtType: String, Codable, Equatable {
    case hutangKu = "Hutangku"
    case piutang = "Piutang"
}

struct DebtTransaction: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var amount: Int
    var note: String
    var isPayment: Bool
    var nominalValue: Int { return isPayment ? -amount : amount }
}

struct Debtor: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phone: String
    var type: DebtType
    var createdAt: Date
    var transactions: [DebtTransaction]
    
    var totalHutang: Int { transactions.reduce(0) { $0 + $1.nominalValue } }
    var totalPinjaman: Int { transactions.filter { !$0.isPayment }.reduce(0) { $0 + $1.amount } }
    var totalDibayar: Int { transactions.filter { $0.isPayment }.reduce(0) { $0 + $1.amount } }
}

// MARK: - Modifier Liquid Glass
extension View {
    func liquidGlass(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.black.opacity(0.45))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(AppTheme.glassBg)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(AppTheme.glassBorder, lineWidth: 1.0))
            .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
    }
}

// MARK: - App Entry Point
@main
struct iBaalCellApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().preferredColorScheme(.dark)
        }
    }
}

// MARK: - Tampilan Utama
struct ContentView: View {
    @State private var debtors: [Debtor] = []
    @State private var showAddDebtor = false
    @State private var searchText = ""
    @State private var activeTab: DebtType = .hutangKu
    
    @AppStorage("hideFinancials") private var hideFinancials: Bool = false
    @State private var showOptionsMenu = false
    
    @State private var showFileImporter = false
    @State private var showFileExporter = false
    @State private var backupDocument = JSONDocument()
    @State private var backupFileName = "Backup_iBaalCell.json"
    
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var activeDebtors: [Debtor] { debtors.filter { $0.type == activeTab } }
    var filteredDebtors: [Debtor] {
        if searchText.isEmpty { return activeDebtors }
        return activeDebtors.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    var totalActiveDebt: Int { activeDebtors.reduce(0) { $0 + $1.totalHutang } }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundTheme
                
                VStack(spacing: 12) {
                    customTopBar
                    tabSwitchView
                    dashboardCard
                    searchBarView
                    debtorListView
                }
                
                if showOptionsMenu { optionsMenuOverlay }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddDebtor) { AddDebtorSheet(debtors: $debtors, currentTab: activeTab) }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json, .plainText]) { handleImportBackup(result: $0) }
            .fileExporter(isPresented: $showFileExporter, document: backupDocument, contentType: .json, defaultFilename: backupFileName) { handleExport(result: $0) }
            .alert("Informasi", isPresented: $showAlert) { Button("OK", role: .cancel) {} } message: { Text(alertMessage) }
            .onAppear { loadData() }
        }
        .navigationViewStyle(.stack)
    }
    
    private var backgroundTheme: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            Circle().fill(activeTab == .piutang ? Color.cyan.opacity(0.25) : Color.red.opacity(0.25)).frame(width: 300, height: 300).blur(radius: 100).offset(x: -100, y: -300)
            Circle().fill(Color.purple.opacity(0.2)).frame(width: 300, height: 300).blur(radius: 100).offset(x: 150, y: 300)
        }
    }
    
    private var tabSwitchView: some View {
        HStack(spacing: 0) {
            tabButton(title: "List A (Hutangku)", type: .hutangKu)
            tabButton(title: "List B (Piutang)", type: .piutang)
        }
        .padding(4).background(Color.white.opacity(0.1)).cornerRadius(12).padding(.horizontal)
    }
    
    private var dashboardCard: some View {
        VStack(spacing: 6) {
            Text(AppFormatters.dashboardTitle(tab: activeTab))
                .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.gray)
            Text(AppFormatters.maskedAmount(totalActiveDebt, isHidden: hideFinancials))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(AppFormatters.debtColor(debt: totalActiveDebt, tab: activeTab, isHidden: hideFinancials))
            Text(AppFormatters.statusText(tab: activeTab, debt: totalActiveDebt))
                .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(totalActiveDebt > 0 ? .orange.opacity(0.8) : .green)
        }
        .frame(maxWidth: .infinity).padding(16).liquidGlass(cornerRadius: 18).padding(.horizontal)
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Cari nama...", text: $searchText).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundColor(.white)
        }
        .padding(12).background(Color.white.opacity(0.08)).cornerRadius(12).padding(.horizontal)
    }
    
    private var debtorListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if filteredDebtors.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: activeTab == .hutangKu ? "wallet.pass.fill" : "person.3.fill").font(.system(size: 40)).foregroundColor(.gray.opacity(0.5))
                        Text("Belum ada data di daftar ini.").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.gray)
                    }
                    .padding(.top, 50)
                } else {
                    ForEach(filteredDebtors) { debtor in
                        NavigationLink(destination: DebtorDetailView(debtor: debtor, allDebtors: $debtors, hideFinancials: $hideFinancials)) {
                            debtorCard(debtor)
                        }
                    }
                }
            }
            .padding(.vertical, 8).padding(.bottom, 40)
        }
    }
    
    private var optionsMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { showOptionsMenu = false }
            }
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withAnimation(.easeInOut) { hideFinancials.toggle(); showOptionsMenu = false }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: hideFinancials ? "eye.slash.fill" : "eye.fill").foregroundColor(.cyan)
                                Text(hideFinancials ? "Tampilkan Saldo" : "Sembunyikan Saldo").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                        }
                        Divider().background(Color.white.opacity(0.15))
                        Button {
                            withAnimation { showOptionsMenu = false }; exportBackup()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up").foregroundColor(.yellow)
                                Text("Cadangkan Data (Backup)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                        }
                        Button {
                            withAnimation { showOptionsMenu = false }; showFileImporter = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.down").foregroundColor(.purple)
                                Text("Pulihkan Data (Restore)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                        }
                    }
                    .padding(8).frame(width: 260).liquidGlass(cornerRadius: 16).padding(.leading, 14).padding(.top, 50)
                    Spacer()
                }
                Spacer()
            }
        }
        .transition(.opacity).zIndex(99)
    }
    
    private var customTopBar: some View {
        ZStack {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { showOptionsMenu.toggle() }
                } label: { Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundColor(.white).frame(width: 38, height: 38).background(Color.white.opacity(0.12)).clipShape(Circle()) }
                Spacer()
                Button { showAddDebtor = true } label: { Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundColor(.black).frame(width: 38, height: 38).background(Color.cyan).clipShape(Circle()) }
            }
            Text("i B a a L   C E L L").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.white)
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 5)
    }
    
    private func tabButton(title: String, type: DebtType) -> some View {
        let isSelected = activeTab == type
        return Button {
            withAnimation(.spring()) { activeTab = type; searchText = "" }
        } label: {
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(isSelected ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 10).background(isSelected ? Color.white.opacity(0.15) : Color.clear).cornerRadius(10)
        }
    }
    
    private func debtorCard(_ debtor: Debtor) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(debtor.name).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(.white)
                HStack { Image(systemName: "phone.fill").font(.system(size: 10)); Text(debtor.phone.isEmpty ? "Tidak ada nomor" : debtor.phone).font(.system(size: 12, weight: .medium, design: .rounded)) }.foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(debtor.type == .hutangKu ? "Sisa Kewajiban:" : "Sisa Hutang:").font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(.gray)
                Text(AppFormatters.maskedAmount(debtor.totalHutang, isHidden: hideFinancials))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppFormatters.debtColor(debt: debtor.totalHutang, tab: debtor.type, isHidden: hideFinancials))
            }
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundColor(.cyan).padding(.leading, 8)
        }
        .padding(14).liquidGlass(cornerRadius: 16).padding(.horizontal)
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "ibaal_cell_debtors"), let decoded = try? JSONDecoder().decode([Debtor].self, from: data) {
            debtors = decoded
        } else if let autoSaved = AutoSaveManager.shared.loadAutoSave(), !autoSaved.isEmpty {
            debtors = autoSaved
        }
    }
    
    private func exportBackup() {
        do {
            let data = try JSONEncoder().encode(debtors)
            let df = DateFormatter(); df.dateFormat = "yyyyMMdd_HHmm"
            backupFileName = "Backup_iBaalCell_\(df.string(from: Date())).json"
            backupDocument = JSONDocument(data: data)
            showFileExporter = true
        } catch { alertMessage = "Gagal menyiapkan data backup."; showAlert = true }
    }
    
    private func handleImportBackup(result: Result<URL, Error>) {
        do {
            let fileURL = try result.get()
            let canAccess = fileURL.startAccessingSecurityScopedResource()
            defer { if canAccess { fileURL.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: fileURL)
            debtors = try JSONDecoder().decode([Debtor].self, from: data)
            saveAllData(debtors)
            alertMessage = "Sukses memulihkan data!"; showAlert = true
        } catch { alertMessage = "Gagal memulihkan berkas JSON."; showAlert = true }
    }
    
    private func handleExport(result: Result<URL, Error>) {
        switch result {
        case .success(let url): alertMessage = "Sukses! Data dicadangkan:\n\(url.lastPathComponent)"; showAlert = true
        case .failure(let error): alertMessage = "Gagal mencadangkan: \(error.localizedDescription)"; showAlert = true
        }
    }
}

// MARK: - Detail Sheet Types
enum DetailSheetType: Identifiable {
    case add(isPayment: Bool)
    case edit(transactionId: UUID)
    var id: String {
        switch self {
        case .add(let p): return "add_\(p)"
        case .edit(let tid): return "edit_\(tid.uuidString)"
        }
    }
}

// MARK: - Tampilan Detail Profil
struct DebtorDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    var debtor: Debtor
    @Binding var allDebtors: [Debtor]
    @Binding var hideFinancials: Bool
    
    @State private var activeSheet: DetailSheetType? = nil
    
    var currentDebtor: Debtor { allDebtors.first(where: { $0.id == debtor.id }) ?? debtor }
    var isHutangKu: Bool { currentDebtor.type == .hutangKu }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            VStack(spacing: 0) {
                headerDetailView
                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 10)
                historyListView
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .add(let isPayment):
                AddTransactionSheet(debtorId: currentDebtor.id, isPayment: isPayment, isHutangKu: isHutangKu, allDebtors: $allDebtors)
            case .edit(let trxId):
                EditTransactionSheet(debtorId: currentDebtor.id, transactionId: trxId, allDebtors: $allDebtors)
            }
        }
    }
    
    private var headerDetailView: some View {
        VStack(spacing: 8) {
            HStack {
                Button { presentationMode.wrappedValue.dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).foregroundColor(.white).frame(width: 40, height: 40).background(Color.white.opacity(0.1)).clipShape(Circle()) }
                Spacer()
                Button { allDebtors.removeAll { $0.id == currentDebtor.id }; saveAllData(allDebtors); presentationMode.wrappedValue.dismiss() } label: { Image(systemName: "trash.fill").font(.system(size: 16)).foregroundColor(.red).frame(width: 40, height: 40).background(Color.red.opacity(0.15)).clipShape(Circle()) }
            }
            .padding(.horizontal)
            
            Text(currentDebtor.name).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(.white)
            Text(currentDebtor.phone).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.gray)
            
            VStack(spacing: 4) {
                Text(isHutangKu ? "SISA HUTANGKU SAAT INI" : "SISA HUTANG DIA SAAT INI").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.gray)
                
                Text(AppFormatters.maskedAmount(currentDebtor.totalHutang, isHidden: hideFinancials))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(AppFormatters.debtColor(debt: currentDebtor.totalHutang, tab: currentDebtor.type, isHidden: hideFinancials))
                
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("TOTAL KESELURUHAN").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.gray)
                        Text(AppFormatters.maskedAmount(currentDebtor.totalPinjaman, isHidden: hideFinancials)).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(hideFinancials ? .gray : .white)
                    }
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 1, height: 24)
                    VStack(spacing: 4) {
                        Text("SUDAH DICICIL").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.gray)
                        Text(AppFormatters.maskedAmount(currentDebtor.totalDibayar, isHidden: hideFinancials)).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(hideFinancials ? .gray : .green)
                    }
                }
                .padding(.vertical, 10).padding(.horizontal, 16).background(Color.white.opacity(0.05)).cornerRadius(12).padding(.top, 8)
            }
            .padding(.top, 10)
            
            HStack(spacing: 12) {
                Button { activeSheet = .add(isPayment: false) } label: {
                    HStack { Image(systemName: "plus.square.fill"); Text(isHutangKu ? "Ngutang Lagi" : "Beri Hutang") }
                    .font(.system(size: 14, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.red.opacity(0.2)).foregroundColor(.red).cornerRadius(12)
                }
                Button { activeSheet = .add(isPayment: true) } label: {
                    HStack { Image(systemName: "minus.square.fill"); Text(isHutangKu ? "Bayar Cicilan" : "Terima Cicilan") }
                    .font(.system(size: 14, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.green.opacity(0.2)).foregroundColor(.green).cornerRadius(12)
                }
            }
            .padding(.top, 10).padding(.horizontal)
        }
        .padding(.vertical, 10)
    }
    
    private var historyListView: some View {
        VStack(alignment: .leading) {
            Text("RIWAYAT TRANSAKSI (Ketuk untuk Edit)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan).padding(.horizontal)
            ScrollView {
                VStack(spacing: 10) {
                    if currentDebtor.transactions.isEmpty {
                        Text("Belum ada riwayat transaksi.").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.gray).padding(.top, 30)
                    } else {
                        ForEach(currentDebtor.transactions.sorted(by: { $0.date > $1.date })) { trx in
                            transactionRow(trx)
                        }
                    }
                }
                .padding(.vertical, 10).padding(.bottom, 40)
            }
        }
    }
    
    private func transactionRow(_ trx: DebtTransaction) -> some View {
        Button { activeSheet = .edit(transactionId: trx.id) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(trx.note).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.white)
                    if trx.note != "Hutang Awal" { Text(AppFormatters.date(trx.date)).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.gray) }
                }
                Spacer()
                Text(AppFormatters.maskedTrxAmount(amount: trx.amount, isPayment: trx.isPayment, isHidden: hideFinancials))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppFormatters.trxColor(isPayment: trx.isPayment, isHidden: hideFinancials))
                Image(systemName: "pencil").font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.3)).padding(.leading, 6)
            }
            .padding(14).liquidGlass(cornerRadius: 12).padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Form Tambah Pelanggan
struct AddDebtorSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var debtors: [Debtor]
    var currentTab: DebtType
    @State private var name = ""
    @State private var phone = ""
    @State private var initialDebt = ""
    
    var navTitle: String { return currentTab == .hutangKu ? "Tambah (List A)" : "Tambah (List B)" }
    var nameTitle: String { return currentTab == .hutangKu ? "NAMA ORANG/TOKO" : "NAMA PELANGGAN" }
    var namePlaceholder: String { return currentTab == .hutangKu ? "Misal: Distributor" : "Misal: Budi" }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    inputField(title: nameTitle, placeholder: namePlaceholder, text: $name, color: .cyan)
                    inputField(title: "NOMOR WA (Opsional)", placeholder: "08xxxx", text: $phone, color: .cyan, isNumber: true)
                    inputField(title: "HUTANG KESELURUHAN (Rp)", placeholder: "0", text: $initialDebt, color: .orange, isNumber: true, isLarge: true)
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(navTitle).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Simpan") { saveDebtor() }.font(.system(size: 16, weight: .bold)).foregroundColor(.cyan) }
            }
        }
    }
    
    private func inputField(title: String, placeholder: String, text: Binding<String>, color: Color, isNumber: Bool = false, isLarge: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(color)
            TextField(placeholder, text: text)
                .keyboardType(isNumber ? .numberPad : .default)
                .font(.system(size: isLarge ? 18 : 16, weight: isLarge ? .bold : .medium, design: .rounded))
                .foregroundColor(isLarge ? color : .white)
                .padding(12).background(Color.white.opacity(0.08)).cornerRadius(10)
        }
        .padding(12).liquidGlass(cornerRadius: 16)
    }
    
    private func saveDebtor() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        var transactions: [DebtTransaction] = []
        if let debtValue = Int(initialDebt), debtValue > 0 { transactions.append(DebtTransaction(date: Date(), amount: debtValue, note: "Hutang Awal", isPayment: false)) }
        debtors.insert(Debtor(name: cleanName, phone: phone, type: currentTab, createdAt: Date(), transactions: transactions), at: 0)
        saveAllData(debtors)
        dismiss()
    }
}

// MARK: - Form Transaksi (Tambah/Cicil)
struct AddTransactionSheet: View {
    @Environment(\.dismiss) var dismiss
    var debtorId: UUID
    var isPayment: Bool
    var isHutangKu: Bool
    @Binding var allDebtors: [Debtor]
    @State private var amount = ""
    @State private var note = ""
    @State private var date = Date()
    
    var title: String { isHutangKu ? (isPayment ? "Bayar Cicilan" : "Ngutang Lagi") : (isPayment ? "Terima Cicilan" : "Beri Hutang") }
    var colorTheme: Color { isPayment ? .green : .red }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOMINAL (Rp)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(colorTheme)
                            TextField("0", text: $amount).keyboardType(.numberPad).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(colorTheme).padding(14).background(Color.white.opacity(0.08)).cornerRadius(12)
                        }
                        .padding(12).liquidGlass(cornerRadius: 16)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TANGGAL").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan)
                            DatePicker("Pilih", selection: $date, displayedComponents: [.date, .hourAndMinute]).font(.system(size: 14, weight: .medium, design: .rounded)).padding(10).background(Color.white.opacity(0.08)).cornerRadius(12)
                        }
                        .padding(12).liquidGlass(cornerRadius: 16)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CATATAN").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan)
                            TextField(isPayment ? "Misal: Transfer BCA" : "Misal: Hutang Baru", text: $note).font(.system(size: 16, weight: .medium, design: .rounded)).padding(14).background(Color.white.opacity(0.08)).cornerRadius(12)
                        }
                        .padding(12).liquidGlass(cornerRadius: 16)
                    }
                    .padding()
                }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Simpan") { saveTransaction() }.font(.system(size: 16, weight: .bold)).foregroundColor(colorTheme) }
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Int(amount), amountValue > 0 else { return }
        let finalNote = note.isEmpty ? (isPayment ? "Pembayaran" : "Tambah Hutang") : note
        if let index = allDebtors.firstIndex(where: { $0.id == debtorId }) {
            allDebtors[index].transactions.append(DebtTransaction(date: date, amount: amountValue, note: finalNote, isPayment: isPayment))
            saveAllData(allDebtors)
        }
        dismiss()
    }
}

// MARK: - Form Edit Transaksi
struct EditTransactionSheet: View {
    @Environment(\.dismiss) var dismiss
    var debtorId: UUID
    var transactionId: UUID
    @Binding var allDebtors: [Debtor]
    @State private var amount = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var isPayment = false
    
    var colorTheme: Color { isPayment ? .green : .red }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("JENIS TRANSAKSI").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan)
                            Picker("Jenis", selection: $isPayment) { Text("Nambah Hutang").tag(false); Text("Bayar Cicilan").tag(true) }.pickerStyle(.segmented).padding(8).background(Color.white.opacity(0.08)).cornerRadius(12)
                        }
                        .padding(12).liquidGlass(cornerRadius: 16)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOMINAL (Rp)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(colorTheme)
                            TextField("0", text: $amount).keyboardType(.numberPad).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(colorTheme).padding(14).background(Color.white.opacity(0.08)).cornerRadius(12)
                        }
                        .padding(12).liquidGlass(cornerRadius: 16)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TANGGAL").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan)
                            DatePicker("Pilih", selection: $date, displayedComponents: [.date, .hourAndMinute]).font(.system(size: 14, weight: .medium, design: .rounded)).padding(10).background(Color.white.opacity(0.08)).cornerRadius(12)
                        }
                        .padding(12).liquidGlass(cornerRadius: 16)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CATATAN").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan)
                            TextField("Catatan...", text: $note).font(.system(size: 16, weight: .medium, design: .rounded)).padding(14).background(Color.white.opacity(0.08)).cornerRadius(12)
                        }
                        .padding(12).liquidGlass(cornerRadius: 16)
                        
                        Button { deleteTransaction() } label: {
                            Text("Hapus Transaksi Ini").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.red).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.red.opacity(0.15)).cornerRadius(14)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Transaksi").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Simpan") { saveTransaction() }.font(.system(size: 16, weight: .bold)).foregroundColor(.cyan) }
            }
            .onAppear { loadData() }
        }
    }
    
    private func loadData() {
        if let dIndex = allDebtors.firstIndex(where: { $0.id == debtorId }), let trx = allDebtors[dIndex].transactions.first(where: { $0.id == transactionId }) {
            amount = String(trx.amount); note = trx.note; date = trx.date; isPayment = trx.isPayment
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Int(amount), amountValue > 0 else { return }
        if let dIndex = allDebtors.firstIndex(where: { $0.id == debtorId }), let tIndex = allDebtors[dIndex].transactions.firstIndex(where: { $0.id == transactionId }) {
            allDebtors[dIndex].transactions[tIndex].amount = amountValue
            allDebtors[dIndex].transactions[tIndex].note = note.isEmpty ? "-" : note
            allDebtors[dIndex].transactions[tIndex].date = date
            allDebtors[dIndex].transactions[tIndex].isPayment = isPayment
            saveAllData(allDebtors)
        }
        dismiss()
    }
    
    private func deleteTransaction() {
        if let dIndex = allDebtors.firstIndex(where: { $0.id == debtorId }) {
            allDebtors[dIndex].transactions.removeAll(where: { $0.id == transactionId }); saveAllData(allDebtors)
        }
        dismiss()
    }
}
