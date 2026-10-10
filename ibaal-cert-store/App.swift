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
struct DebtTransaction: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var amount: Int
    var note: String
    var isPayment: Bool // true = bayar hutang (-), false = tambah hutang (+)
    
    var nominalValue: Int {
        return isPayment ? -amount : amount
    }
}

struct Debtor: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var phone: String
    var createdAt: Date
    var transactions: [DebtTransaction]
    
    // Total akan menjumlahkan atau mengurangkan otomatis!
    var totalHutang: Int {
        transactions.reduce(0) { $0 + $1.nominalValue }
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
    
    // Menghitung total semua hutang orang ke kamu
    var totalUangDiLuar: Int {
        debtors.reduce(0) { $0 + $1.totalHutang }
    }
    
    var filteredDebtors: [Debtor] {
        if searchText.isEmpty { return debtors }
        return debtors.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
                
                // Dekorasi Background
                Circle().fill(Color.cyan.opacity(0.25)).frame(width: 300, height: 300).blur(radius: 100).offset(x: -100, y: -300)
                Circle().fill(Color.purple.opacity(0.2)).frame(width: 300, height: 300).blur(radius: 100).offset(x: 150, y: 300)
                
                VStack(spacing: 12) {
                    customTopBar
                    
                    // Card Dasbor Total
                    VStack(spacing: 6) {
                        Text("TOTAL UANG DI LUAR (PIUTANG)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        
                        Text(AppFormatters.idr(totalUangDiLuar))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(totalUangDiLuar > 0 ? .orange : .green)
                        
                        Text(totalUangDiLuar > 0 ? "⚠️ Segera tagih agar kas lancar" : "✅ Semua hutang pelanggan lunas")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(totalUangDiLuar > 0 ? .orange.opacity(0.8) : .green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .liquidGlass(cornerRadius: 18)
                    .padding(.horizontal)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Cari nama pelanggan...", text: $searchText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // List Orang yang Hutang
                    ScrollView {
                        VStack(spacing: 12) {
                            if filteredDebtors.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "person.3.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("Belum ada data pelanggan.")
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
                AddDebtorSheet(debtors: $debtors)
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
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 40, height: 40)
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
                Text("Total Hutang:")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                
                Text(AppFormatters.idr(debtor.totalHutang))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(debtor.totalHutang > 0 ? .orange : .green)
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
    @State private var isPaymentMode = false // false = ngutang lagi, true = bayar cicilan
    
    var currentDebtor: Debtor {
        allDebtors.first(where: { $0.id == debtor.id }) ?? debtor
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
                        Text("SISA HUTANG SAAT INI")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        Text(AppFormatters.idr(currentDebtor.totalHutang))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(currentDebtor.totalHutang > 0 ? .orange : .green)
                    }
                    .padding(.top, 10)
                    
                    // Tombol Aksi (Tambah Hutang / Bayar)
                    HStack(spacing: 12) {
                        Button {
                            isPaymentMode = false
                            showTransactionSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "minus.square.fill")
                                Text("Ngutang Lagi")
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
                                Text("Bayar/Cicil")
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
                
                // Daftar Riwayat Transaksi
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
                                // Tampilkan dari yang paling baru
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
            AddTransactionSheet(debtorId: currentDebtor.id, isPayment: isPaymentMode, allDebtors: $allDebtors)
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
    
    @State private var name = ""
    @State private var phone = ""
    @State private var initialDebt = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NAMA PELANGGAN").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.cyan)
                        TextField("Misal: Budi", text: $name)
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
            .navigationTitle("Tambah Pelanggan")
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
        
        let newDebtor = Debtor(name: cleanName, phone: phone, createdAt: Date(), transactions: transactions)
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
    @Binding var allDebtors: [Debtor]
    
    @State private var amount = ""
    @State private var note = ""
    
    var title: String { isPayment ? "Terima Pembayaran" : "Tambah Hutang" }
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
                        TextField(isPayment ? "Misal: Cicilan ke-1" : "Misal: Pulsa Telkomsel 50k", text: $note)
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
