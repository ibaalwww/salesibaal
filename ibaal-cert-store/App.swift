import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Format Helper Global
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
}

// MARK: - Model Data
enum DebtType: String, Codable, Equatable {
    case hutangKu = "Hutangku"    // List A: Aku yang ngutang ke orang
    case piutang = "Piutang"      // List B: Orang yang ngutang ke aku
}

struct DebtTransaction: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var amount: Int
    var note: String
    var isPayment: Bool // true = bayar/ngurangin, false = nambah
    
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
    
    // Sisa Hutang Saat Ini
    var totalHutang: Int {
        transactions.reduce(0) { $0 + $1.nominalValue }
    }
    
    // --- FITUR BARU: Total Jumlah Asli ---
    // Total Pinjaman (Jumlah asli sebelum dicicil)
    var totalPinjaman: Int {
        transactions.filter { !$0.isPayment }.reduce(0) { $0 + $1.amount }
    }
    
    // Total Pembayaran (Jumlah yang udah disetor)
    var totalDibayar: Int {
        transactions.filter { $0.isPayment }.reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Modifier Liquid Glass Ala iBaal
extension View {
    func liquidGlass(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                Gradient.Stop(color: Color.white.opacity(0.4), location: 0.0),
                                Gradient.Stop(color: Color.white.opacity(0.1), location: 0.45),
                                Gradient.Stop(color: Color.cyan.opacity(0.3), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
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

// MARK: - Tampilan Utama (Dashboard)
struct ContentView: View {
    @State private var debtors: [Debtor] = []
    @State private var showAddDebtor = false
    @State private var searchText = ""
    @State private var activeTab: DebtType = .hutangKu // Default ke List A (Hutangku)
    
    var activeDebtors: [Debtor] {
        debtors.filter { $0.type == activeTab }
    }
    
    var filteredDebtors: [Debtor] {
        if searchText.isEmpty { return activeDebtors }
        return activeDebtors.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var totalActiveDebt: Int {
        activeDebtors.reduce(0) { $0 + $1.totalHutang }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
                
                // Dekorasi Background
                Circle()
                    .fill(activeTab == .piutang ? Color.cyan.opacity(0.25) : Color.red.opacity(0.25))
                    .frame(width: 300, height: 300).blur(radius: 100).offset(x: -100, y: -300)
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 300, height: 300).blur(radius: 100).offset(x: 150, y: 300)
                
                VStack(spacing: 12) {
                    customTopBar
                    
                    // Switch Tab List A & List B
                    HStack(spacing: 0) {
                        tabButton(title: "List A (Hutangku)", type: .hutangKu)
                        tabButton(title: "List B (Piutang)", type: .piutang)
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Card Dasbor Total
                    VStack(spacing: 6) {
                        Text(activeTab == .hutangKu ? "TOTAL HUTANG SAYA" : "TOTAL UANG DI LUAR (PIUTANG)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        Text(AppFormatters.idr(totalActiveDebt))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(activeTab == .hutangKu ? .red : .cyan)
                        
                        Text(activeTab == .hutangKu ? (totalActiveDebt > 0 ? "⚠️ Segera lunasi hutangmu!" : "✅ Bebas hutang") : (totalActiveDebt > 0 ? "⚠️ Segera tagih agar kas lancar" : "✅ Semua hutang pelanggan lunas"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(totalActiveDebt > 0 ? .orange.opacity(0.8) : .green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .liquidGlass(cornerRadius: 18)
                    .padding(.horizontal)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Cari nama...", text: $searchText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // List Orang
                    ScrollView {
                        VStack(spacing: 12) {
                            if filteredDebtors.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: activeTab == .hutangKu ? "wallet.pass.fill" : "person.3.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("Belum ada data di daftar ini.")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 50)
                            } else {
                                ForEach(filteredDebtors) { debtor in
                                    NavigationLink(destination: DebtorDetailView(debtor: debtor, allDebtors: $debtors)) {
                                        debtorCard(debtor)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddDebtor) {
                AddDebtorSheet(debtors: $debtors, currentTab: activeTab)
            }
            .onAppear { loadData() }
        }
        .navigationViewStyle(.stack)
    }
    
    private var customTopBar: some View {
        ZStack {
            HStack {
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
            Text("i B a a L   C E L L")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 5)
    }
    
    private func tabButton(title: String, type: DebtType) -> some View {
        let isSelected = activeTab == type
        return Button {
            withAnimation(.spring()) {
                activeTab = type
                searchText = ""
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
                .cornerRadius(10)
        }
    }
    
    private func debtorCard(_ debtor: Debtor) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(debtor.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 10))
                    Text(debtor.phone.isEmpty ? "Tidak ada nomor" : debtor.phone)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(debtor.type == .hutangKu ? "Sisa Kewajiban:" : "Sisa Hutang:")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                
                Text(AppFormatters.idr(debtor.totalHutang))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(debtor.totalHutang > 0 ? (debtor.type == .hutangKu ? .red : .orange) : .green)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
                .padding(.leading, 8)
        }
        .padding(14)
        .liquidGlass(cornerRadius: 16)
        .padding(.horizontal)
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "ibaal_cell_debtors"),
           let decoded = try? JSONDecoder().decode([Debtor].self, from: data) {
            debtors = decoded
        }
    }
}

// MARK: - Tampilan Detail (Profil Pelanggan & Riwayat)
struct DebtorDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    var debtor: Debtor
    @Binding var allDebtors: [Debtor]
    
    @State private var showTransactionSheet = false
    @State private var isPaymentMode = false
    
    var currentDebtor: Debtor {
        allDebtors.first(where: { $0.id == debtor.id }) ?? debtor
    }
    
    var isHutangKu: Bool {
        currentDebtor.type == .hutangKu
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Profil
                VStack(spacing: 8) {
                    HStack {
                        Button { presentationMode.wrappedValue.dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Button { deleteDebtor() } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .frame(width: 40, height: 40)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    
                    Text(currentDebtor.name)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(currentDebtor.phone)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 4) {
                        Text(isHutangKu ? "SISA HUTANGKU SAAT INI" : "SISA HUTANG DIA SAAT INI")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        Text(AppFormatters.idr(currentDebtor.totalHutang))
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(currentDebtor.totalHutang > 0 ? (isHutangKu ? .red : .orange) : .green)
                        
                        // --- FITUR BARU: RINCIAN JUMLAH ASLI ---
                        HStack(spacing: 20) {
                            VStack(spacing: 4) {
                                Text(isHutangKu ? "TOTAL PINJAMANKU" : "TOTAL PINJAMAN DIA")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.gray)
                                Text(AppFormatters.idr(currentDebtor.totalPinjaman))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 1, height: 24)
                            
                            VStack(spacing: 4) {
                                Text("SUDAH DIBAYAR")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.gray)
                                Text(AppFormatters.idr(currentDebtor.totalDibayar))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.top, 8)
                        // ---------------------------------------
                    }
                    .padding(.top, 10)
                    
                    // Tombol Aksi (Tergantung List A atau List B)
                    HStack(spacing: 12) {
                        Button {
                            isPaymentMode = false
                            showTransactionSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "minus.square.fill")
                                Text(isHutangKu ? "Ngutang Lagi" : "Beri Hutang")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            isPaymentMode = true
                            showTransactionSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.square.fill")
                                Text(isHutangKu ? "Bayar Hutang" : "Terima Bayaran")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                
                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 10)
                
                // Daftar Riwayat
                VStack(alignment: .leading) {
                    Text("RIWAYAT TRANSAKSI")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 10) {
                            if currentDebtor.transactions.isEmpty {
                                Text("Belum ada riwayat transaksi.")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.gray)
                                    .padding(.top, 30)
                            } else {
                                ForEach(currentDebtor.transactions.sorted(by: { $0.date > $1.date })) { trx in
                                    transactionRow(trx)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showTransactionSheet) {
            AddTransactionSheet(debtorId: currentDebtor.id, isPayment: isPaymentMode, isHutangKu: isHutangKu, allDebtors: $allDebtors)
        }
    }
    
    private func transactionRow(_ trx: DebtTransaction) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(trx.note)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(AppFormatters.date(trx.date))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
            }
            Spacer()
            Text(trx.isPayment ? "-\(AppFormatters.idr(trx.amount))" : "+\(AppFormatters.idr(trx.amount))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(trx.isPayment ? .green : .red)
        }
        .padding(14)
        .liquidGlass(cornerRadius: 12)
        .padding(.horizontal)
    }
    
    private func deleteDebtor() {
        allDebtors.removeAll { $0.id == currentDebtor.id }
        saveData()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(allDebtors) {
            UserDefaults.standard.set(encoded, forKey: "ibaal_cell_debtors")
        }
    }
}

// MARK: - Form Tambah Pelanggan Baru
struct AddDebtorSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var debtors: [Debtor]
    var currentTab: DebtType
    
    @State private var name = ""
    @State private var phone = ""
    @State private var initialDebt = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(currentTab == .hutangKu ? "NAMA ORANG/TOKO" : "NAMA PELANGGAN").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan)
                        TextField(currentTab == .hutangKu ? "Misal: Distributor Pulsa" : "Misal: Budi", text: $name)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .padding(12)
                    .liquidGlass(cornerRadius: 16)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOMOR WA (Opsional)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan)
                        TextField("08xxxx", text: $phone)
                            .keyboardType(.phonePad)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .padding(12)
                    .liquidGlass(cornerRadius: 16)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("HUTANG AWAL (Rp)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.orange)
                        TextField("0", text: $initialDebt)
                            .keyboardType(.numberPad)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .padding(12)
                    .liquidGlass(cornerRadius: 16)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(currentTab == .hutangKu ? "Tambah Daftar (List A)" : "Tambah Daftar (List B)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Simpan") { saveDebtor() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private func saveDebtor() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        var transactions: [DebtTransaction] = []
        if let debtValue = Int(initialDebt), debtValue > 0 {
            transactions.append(DebtTransaction(date: Date(), amount: debtValue, note: "Hutang Awal", isPayment: false))
        }
        
        // Simpan orang baru dengan Tipe (List A atau B) sesuai tab yang sedang aktif
        let newDebtor = Debtor(name: cleanName, phone: phone, type: currentTab, createdAt: Date(), transactions: transactions)
        debtors.insert(newDebtor, at: 0)
        
        if let encoded = try? JSONEncoder().encode(debtors) {
            UserDefaults.standard.set(encoded, forKey: "ibaal_cell_debtors")
        }
        dismiss()
    }
}

// MARK: - Form Tambah/Bayar Hutang
struct AddTransactionSheet: View {
    @Environment(\.dismiss) var dismiss
    var debtorId: UUID
    var isPayment: Bool
    var isHutangKu: Bool
    @Binding var allDebtors: [Debtor]
    
    @State private var amount = ""
    @State private var note = ""
    
    var title: String {
        if isHutangKu {
            return isPayment ? "Bayar Hutang" : "Ngutang Lagi"
        } else {
            return isPayment ? "Terima Pembayaran" : "Beri Hutang"
        }
    }
    
    var colorTheme: Color { isPayment ? .green : .red }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOMINAL (Rp)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(colorTheme)
                        TextField("0", text: $amount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(colorTheme)
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }
                    .padding(12)
                    .liquidGlass(cornerRadius: 16)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CATATAN").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan)
                        TextField(isPayment ? "Misal: Transfer BCA" : "Misal: Ngambil rokok / saldo", text: $note)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }
                    .padding(12)
                    .liquidGlass(cornerRadius: 16)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Simpan") { saveTransaction() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorTheme)
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Int(amount), amountValue > 0 else { return }
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote = cleanNote.isEmpty ? (isPayment ? "Pembayaran/Cicilan" : "Tambah Hutang") : cleanNote
        
        let newTrx = DebtTransaction(date: Date(), amount: amountValue, note: finalNote, isPayment: isPayment)
        
        if let index = allDebtors.firstIndex(where: { $0.id == debtorId }) {
            allDebtors[index].transactions.append(newTrx)
            
            if let encoded = try? JSONEncoder().encode(allDebtors) {
                UserDefaults.standard.set(encoded, forKey: "ibaal_cell_debtors")
            }
        }
        dismiss()
    }
}
