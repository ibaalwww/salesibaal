import SwiftUI
import UIKit

// MARK: - Format Helper
struct AppFormatters {
    static func idr(_ num: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.locale = Locale(identifier: "id_ID"); f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: num)) ?? "Rp 0"
    }
    static func date(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd MMM yyyy, HH:mm"
        return f.string(from: d)
    }
}

// MARK: - Manajer Auto-Save & Share
class AutoSaveManager {
    static let shared = AutoSaveManager()
    private var autoBackupURL: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("iBaalCell_AutoBackup.json") }
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
    if let encoded = try? JSONEncoder().encode(debtors) { UserDefaults.standard.set(encoded, forKey: "ibaal_cell_debtors") }
    AutoSaveManager.shared.save(debtors)
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Model Data
enum DebtType: String, Codable, Equatable { case hutangKu = "Hutangku"; case piutang = "Piutang" }

struct DebtTransaction: Identifiable, Codable, Hashable {
    var id = UUID(); var date: Date; var amount: Int; var note: String; var isPayment: Bool
    var nominalValue: Int { isPayment ? -amount : amount }
}

struct Debtor: Identifiable, Codable, Hashable {
    var id = UUID(); var name: String; var phone: String; var type: DebtType; var createdAt: Date; var transactions: [DebtTransaction]
    var totalHutang: Int { transactions.reduce(0) { $0 + $1.nominalValue } }
    var totalPinjaman: Int { transactions.filter { !$0.isPayment }.reduce(0) { $0 + $1.amount } }
    var totalDibayar: Int { transactions.filter { $0.isPayment }.reduce(0) { $0 + $1.amount } }
}

// MARK: - Modifier Liquid Glass Super Ringan
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

// MARK: - Komponen UI Ringan (Anti Timeout)
struct InputRow: View {
    var title: String; var placeholder: String; @Binding var text: String; var color: Color; var isNumber: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(color)
            TextField(placeholder, text: $text)
                .keyboardType(isNumber ? .numberPad : .default).font(.system(size: 16, weight: .bold, design: .rounded))
                .padding(14).background(Color.white.opacity(0.08)).cornerRadius(12)
        }.padding(12).liquidGlass()
    }
}

// MARK: - App Entry Point
@main
struct iBaalCellApp: App {
    var body: some Scene { WindowGroup { ContentView().preferredColorScheme(.dark) } }
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
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
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
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
                Circle().fill(activeTab == .piutang ? Color.cyan.opacity(0.2) : Color.red.opacity(0.2)).frame(width: 300, height: 300).blur(radius: 100).offset(x: -100, y: -300)
                
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
            .sheet(isPresented: $showShareSheet) { ShareSheet(activityItems: shareItems) }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json, .plainText]) { handleImport(result: $0) }
            .alert(isPresented: $showAlert) { Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK"))) }
            .onAppear { loadData() }
        }.navigationViewStyle(.stack)
    }
    
    private var tabSwitchView: some View {
        HStack(spacing: 0) {
            Button { withAnimation { activeTab = .hutangKu } } label: { Text("List A (Hutangku)").font(.system(size: 13, weight: .bold)).foregroundColor(activeTab == .hutangKu ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 10).background(activeTab == .hutangKu ? Color.white.opacity(0.15) : Color.clear).cornerRadius(10) }
            Button { withAnimation { activeTab = .piutang } } label: { Text("List B (Piutang)").font(.system(size: 13, weight: .bold)).foregroundColor(activeTab == .piutang ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 10).background(activeTab == .piutang ? Color.white.opacity(0.15) : Color.clear).cornerRadius(10) }
        }.padding(4).background(Color.white.opacity(0.1)).cornerRadius(12).padding(.horizontal)
    }
    
    private var dashboardCard: some View {
        VStack(spacing: 6) {
            Text(activeTab == .hutangKu ? "SISA HUTANG SAYA" : "SISA UANG DI LUAR").font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
            Text(hideFinancials ? "Rp •••••••" : AppFormatters.idr(totalActiveDebt)).font(.system(size: 28, weight: .heavy)).foregroundColor(hideFinancials ? .gray : (totalActiveDebt <= 0 ? .green : (activeTab == .hutangKu ? .red : .cyan)))
        }.frame(maxWidth: .infinity).padding(16).liquidGlass().padding(.horizontal)
    }
    
    private var searchBarView: some View {
        HStack { Image(systemName: "magnifyingglass").foregroundColor(.gray); TextField("Cari nama...", text: $searchText).font(.system(size: 15, weight: .medium)).foregroundColor(.white) }
            .padding(12).background(Color.white.opacity(0.08)).cornerRadius(12).padding(.horizontal)
    }
    
    private var debtorListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(filteredDebtors) { debtor in
                    NavigationLink(destination: DebtorDetailView(debtor: debtor, allDebtors: $debtors, hideFinancials: $hideFinancials)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(debtor.name).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                Text(debtor.phone.isEmpty ? "Tidak ada nomor" : debtor.phone).font(.system(size: 12)).foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                Text("Sisa:").font(.system(size: 10)).foregroundColor(.gray)
                                Text(hideFinancials ? "Rp •••••" : AppFormatters.idr(debtor.totalHutang)).font(.system(size: 16, weight: .bold)).foregroundColor(hideFinancials ? .gray : (debtor.totalHutang > 0 ? (debtor.type == .hutangKu ? .red : .orange) : .green))
                            }
                        }.padding(14).liquidGlass().padding(.horizontal)
                    }
                }
            }.padding(.vertical, 8).padding(.bottom, 40)
        }
    }
    
    private var optionsMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { withAnimation { showOptionsMenu = false } }
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Button { withAnimation { hideFinancials.toggle(); showOptionsMenu = false } } label: { HStack { Image(systemName: hideFinancials ? "eye.slash.fill" : "eye.fill").foregroundColor(.cyan); Text(hideFinancials ? "Tampilkan Saldo" : "Sembunyikan Saldo").foregroundColor(.white) } }
                        Divider().background(Color.white.opacity(0.15))
                        Button { withAnimation { showOptionsMenu = false }; exportBackup() } label: { HStack { Image(systemName: "square.and.arrow.up").foregroundColor(.yellow); Text("Cadangkan (Backup)").foregroundColor(.white) } }
                        Button { withAnimation { showOptionsMenu = false }; showFileImporter = true } label: { HStack { Image(systemName: "square.and.arrow.down").foregroundColor(.purple); Text("Pulihkan (Restore)").foregroundColor(.white) } }
                    }.padding(16).liquidGlass().padding(.leading, 14).padding(.top, 50); Spacer()
                }; Spacer()
            }
        }.zIndex(99)
    }
    
    private var customTopBar: some View {
        HStack {
            Button { withAnimation { showOptionsMenu.toggle() } } label: { Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundColor(.white).frame(width: 38, height: 38).background(Color.white.opacity(0.12)).clipShape(Circle()) }
            Spacer(); Text("i B a a L   C E L L").font(.system(size: 18, weight: .heavy)).foregroundColor(.white); Spacer()
            Button { showAddDebtor = true } label: { Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundColor(.black).frame(width: 38, height: 38).background(Color.cyan).clipShape(Circle()) }
        }.padding(.horizontal).padding(.top, 10).padding(.bottom, 5)
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "ibaal_cell_debtors"), let decoded = try? JSONDecoder().decode([Debtor].self, from: data) { debtors = decoded }
        else if let autoSaved = AutoSaveManager.shared.load() { debtors = autoSaved }
    }
    
    // Trik jenius ubah format ke .txt agar tombol "Save to Files" SELALU muncul
    private func exportBackup() {
        do {
            let data = try JSONEncoder().encode(debtors)
            let fn = "Backup_iBaalCell_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short).replacingOccurrences(of: "/", with: "")).txt"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fn)
            try data.write(to: url); shareItems = [url]; showShareSheet = true
        } catch { alertMessage = "Gagal backup."; showAlert = true }
    }
    
    private func handleImport(result: Result<URL, Error>) {
        guard let url = try? result.get(), let data = try? Data(contentsOf: url), let imported = try? JSONDecoder().decode([Debtor].self, from: data) else { alertMessage = "Gagal memulihkan data!"; showAlert = true; return }
        debtors = imported; saveAllData(debtors); alertMessage = "Sukses memulihkan!"; showAlert = true
    }
}

// MARK: - Detail Layar
struct DebtorDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    var debtor: Debtor
    @Binding var allDebtors: [Debtor]
    @Binding var hideFinancials: Bool
    
    @State private var showTrxSheet = false
    @State private var selectedTrxId: UUID? = nil
    @State private var isPaymentMode = false
    
    var currentDebtor: Debtor { allDebtors.first(where: { $0.id == debtor.id }) ?? debtor }
    var isHutangKu: Bool { currentDebtor.type == .hutangKu }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            VStack(spacing: 0) {
                headerView
                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 10)
                historyView
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showTrxSheet) { TransactionFormSheet(debtorId: currentDebtor.id, transactionId: selectedTrxId, defaultIsPayment: isPaymentMode, isHutangKu: isHutangKu, allDebtors: $allDebtors) }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Button { presentationMode.wrappedValue.dismiss() } label: { Image(systemName: "chevron.left").frame(width: 40, height: 40).background(Color.white.opacity(0.1)).clipShape(Circle()).foregroundColor(.white) }
                Spacer()
                Button { allDebtors.removeAll { $0.id == currentDebtor.id }; saveAllData(allDebtors); presentationMode.wrappedValue.dismiss() } label: { Image(systemName: "trash.fill").frame(width: 40, height: 40).background(Color.red.opacity(0.15)).clipShape(Circle()).foregroundColor(.red) }
            }.padding(.horizontal)
            
            Text(currentDebtor.name).font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
            
            VStack(spacing: 4) {
                Text(isHutangKu ? "SISA HUTANGKU SAAT INI" : "SISA HUTANG DIA").font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                Text(hideFinancials ? "Rp •••••••" : AppFormatters.idr(currentDebtor.totalHutang)).font(.system(size: 36, weight: .heavy)).foregroundColor(hideFinancials ? .gray : (currentDebtor.totalHutang > 0 ? (isHutangKu ? .red : .orange) : .green))
                
                HStack(spacing: 20) {
                    VStack(spacing: 4) { Text("KESELURUHAN").font(.system(size: 10, weight: .bold)).foregroundColor(.gray); Text(hideFinancials ? "Rp •••••" : AppFormatters.idr(currentDebtor.totalPinjaman)).font(.system(size: 14, weight: .bold)).foregroundColor(.white) }
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 1, height: 24)
                    VStack(spacing: 4) { Text("DICICIL").font(.system(size: 10, weight: .bold)).foregroundColor(.gray); Text(hideFinancials ? "Rp •••••" : AppFormatters.idr(currentDebtor.totalDibayar)).font(.system(size: 14, weight: .bold)).foregroundColor(.green) }
                }.padding(.vertical, 10).padding(.horizontal, 16).background(Color.white.opacity(0.05)).cornerRadius(12).padding(.top, 8)
            }.padding(.top, 10)
            
            HStack(spacing: 12) {
                Button { selectedTrxId = nil; isPaymentMode = false; showTrxSheet = true } label: { HStack { Image(systemName: "plus.square.fill"); Text(isHutangKu ? "Ngutang Lagi" : "Beri Hutang") }.font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.red.opacity(0.2)).foregroundColor(.red).cornerRadius(12) }
                Button { selectedTrxId = nil; isPaymentMode = true; showTrxSheet = true } label: { HStack { Image(systemName: "minus.square.fill"); Text(isHutangKu ? "Bayar Cicilan" : "Terima Cicilan") }.font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.green.opacity(0.2)).foregroundColor(.green).cornerRadius(12) }
            }.padding(.top, 10).padding(.horizontal)
        }.padding(.vertical, 10)
    }
    
    private var historyView: some View {
        VStack(alignment: .leading) {
            Text("RIWAYAT TRANSAKSI (Ketuk untuk Edit)").font(.system(size: 12, weight: .bold)).foregroundColor(.cyan).padding(.horizontal)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(currentDebtor.transactions.sorted(by: { $0.date > $1.date })) { trx in
                        Button { selectedTrxId = trx.id; showTrxSheet = true } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(trx.note).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                                    if trx.note != "Hutang Awal" { Text(AppFormatters.date(trx.date)).font(.system(size: 11)).foregroundColor(.gray) }
                                }
                                Spacer()
                                Text(hideFinancials ? (trx.isPayment ? "- Rp •••••" : "+ Rp •••••") : (trx.isPayment ? "-\(AppFormatters.idr(trx.amount))" : "+\(AppFormatters.idr(trx.amount))"))
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(hideFinancials ? .gray : (trx.isPayment ? .green : .red))
                                Image(systemName: "pencil").foregroundColor(.white.opacity(0.3)).padding(.leading, 6)
                            }.padding(14).liquidGlass().padding(.horizontal)
                        }.buttonStyle(.plain)
                    }
                }.padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Form Tambah Pelanggan
struct AddDebtorSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var debtors: [Debtor]
    var currentTab: DebtType
    @State private var name = ""; @State private var phone = ""; @State private var initialDebt = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        InputRow(title: currentTab == .hutangKu ? "NAMA ORANG/TOKO" : "NAMA PELANGGAN", placeholder: "Misal: Budi", text: $name, color: .cyan)
                        InputRow(title: "NOMOR WA (Opsional)", placeholder: "08xxxx", text: $phone, color: .cyan, isNumber: true)
                        InputRow(title: "HUTANG AWAL (Rp)", placeholder: "0", text: $initialDebt, color: .orange, isNumber: true)
                    }.padding()
                }
            }
            .navigationTitle(currentTab == .hutangKu ? "Tambah (List A)" : "Tambah (List B)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Batal") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Simpan") { saveDebtor() }.font(.system(size: 16, weight: .bold)).foregroundColor(.cyan) }
            }
        }
    }
    func saveDebtor() {
        if name.isEmpty { return }
        var trxs: [DebtTransaction] = []
        if let v = Int(initialDebt), v > 0 { trxs.append(DebtTransaction(date: Date(), amount: v, note: "Hutang Awal", isPayment: false)) }
        debtors.insert(Debtor(name: name, phone: phone, type: currentTab, createdAt: Date(), transactions: trxs), at: 0)
        saveAllData(debtors); presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Form Transaksi Global (Add & Edit) Gabungan Anti-Error
struct TransactionFormSheet: View {
    @Environment(\.presentationMode) var presentationMode
    var debtorId: UUID
    var transactionId: UUID?
    var defaultIsPayment: Bool
    var isHutangKu: Bool
    @Binding var allDebtors: [Debtor]
    
    @State private var amount = ""; @State private var note = ""; @State private var date = Date(); @State private var isPayment = false
    
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
                                Text("JENIS").font(.system(size: 12, weight: .bold)).foregroundColor(.cyan)
                                Picker("Jenis", selection: $isPayment) { Text("Nambah").tag(false); Text("Bayar").tag(true) }.pickerStyle(SegmentedPickerStyle()).padding(8).background(Color.white.opacity(0.08)).cornerRadius(12)
                            }.padding(12).liquidGlass()
                        }
                        
                        InputRow(title: "NOMINAL (Rp)", placeholder: "0", text: $amount, color: colorTheme, isNumber: true)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TANGGAL").font(.system(size: 12, weight: .bold)).foregroundColor(.cyan)
                            DatePicker("Pilih", selection: $date, displayedComponents: [.date, .hourAndMinute]).padding(10).background(Color.white.opacity(0.08)).cornerRadius(12)
                        }.padding(12).liquidGlass()
                        
                        InputRow(title: "CATATAN", placeholder: isPayment ? "Misal: Transfer BCA" : "Misal: Pulsa", text: $note, color: .cyan)
                        
                        if isEdit {
                            Button { deleteTrx() } label: { Text("Hapus Transaksi").font(.system(size: 15, weight: .bold)).foregroundColor(.red).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.red.opacity(0.15)).cornerRadius(14) }
                        }
                    }.padding()
                }
            }
            .navigationTitle(isEdit ? "Edit Transaksi" : (isPayment ? "Input Cicilan" : "Input Hutang Baru")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Batal") { presentationMode.wrappedValue.dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Simpan") { saveTrx() }.font(.system(size: 16, weight: .bold)).foregroundColor(colorTheme) }
            }.onAppear { setup() }
        }
    }
    
    func setup() {
        if let tId = transactionId, let dIndex = allDebtors.firstIndex(where: { $0.id == debtorId }), let trx = allDebtors[dIndex].transactions.first(where: { $0.id == tId }) {
            amount = String(trx.amount); note = trx.note; date = trx.date; isPayment = trx.isPayment
        } else { isPayment = defaultIsPayment }
    }
    
    func saveTrx() {
        guard let v = Int(amount), v > 0, let dIndex = allDebtors.firstIndex(where: { $0.id == debtorId }) else { return }
        let fNote = note.isEmpty ? (isPayment ? "Cicilan" : "Hutang") : note
        if let tId = transactionId, let tIndex = allDebtors[dIndex].transactions.firstIndex(where: { $0.id == tId }) {
            allDebtors[dIndex].transactions[tIndex] = DebtTransaction(id: tId, date: date, amount: v, note: fNote, isPayment: isPayment)
        } else {
            allDebtors[dIndex].transactions.append(DebtTransaction(date: date, amount: v, note: fNote, isPayment: isPayment))
        }
        saveAllData(allDebtors); presentationMode.wrappedValue.dismiss()
    }
    
    func deleteTrx() {
        guard let tId = transactionId, let dIndex = allDebtors.firstIndex(where: { $0.id == debtorId }) else { return }
        allDebtors[dIndex].transactions.removeAll(where: { $0.id == tId })
        saveAllData(allDebtors); presentationMode.wrappedValue.dismiss()
    }
}
