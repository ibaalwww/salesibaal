import SwiftUI
import UIKit
import Combine
import UniformTypeIdentifiers
import CoreText

// MARK: - Manajer Pendaftaran Font Dinamis (CoreText)
final class FontManager {
    static var resolvedFontName: String = "Mali-Bold"

    static func registerAllFonts() {
        guard let resourceURLs = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else { return }
        for url in resourceURLs {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }

        for family in UIFont.familyNames {
            for name in UIFont.fontNames(forFamilyName: family) {
                if name.localizedCaseInsensitiveContains("mali") {
                    resolvedFontName = name
                    return
                }
            }
        }
    }
}

// MARK: - Helper Font Mali-Bold
extension Font {
    static func mali(_ size: CGFloat) -> Font {
        if UIFont(name: FontManager.resolvedFontName, size: size) != nil {
            return .custom(FontManager.resolvedFontName, size: size)
        }
        return .system(size: size, weight: .bold, design: .rounded)
    }
}

extension UIFont {
    static func mali(_ size: CGFloat) -> UIFont {
        return UIFont(name: FontManager.resolvedFontName, size: size) ??
               UIFont.systemFont(ofSize: size, weight: .bold)
    }
}

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
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: d)
    }
}

// MARK: - Manajer Auto-Save & Dokumen
class AutoSaveManager {
    static let shared = AutoSaveManager()

    private var autoBackupURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("CertManager_AutoBackup.json")
    }

    func save(_ items: [SaleItem]) {
        DispatchQueue.global(qos: .background).async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(items)
                try data.write(to: self.autoBackupURL, options: .atomic)
            } catch {}
        }
    }

    func loadAutoSave() -> [SaleItem]? {
        guard FileManager.default.fileExists(atPath: autoBackupURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: autoBackupURL)
            return try JSONDecoder().decode([SaleItem].self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Manajer Modal Kloter
class BatchModalManager {
    static let shared = BatchModalManager()
    private let key = "saved_batch_modals"

    func getModal(for batch: Int) -> Int {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        return dict[String(batch)] ?? 0
    }

    func setModal(for batch: Int, modal: Int) {
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        dict[String(batch)] = modal
        UserDefaults.standard.set(dict, forKey: key)
    }
    
    func exportAll() -> [String: Int] {
        return UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }
    
    func importAll(_ dict: [String: Int]) {
        UserDefaults.standard.set(dict, forKey: key)
        UserDefaults.standard.synchronize()
    }
}

// MARK: - Manajer Fee Admin Kloter
class BatchAdminFeeManager {
    static let shared = BatchAdminFeeManager()
    private let key = "saved_batch_admin_fees"

    func getFee(for batch: Int) -> Int {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        return dict[String(batch)] ?? 0
    }

    func setFee(for batch: Int, fee: Int) {
        var dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        dict[String(batch)] = fee
        UserDefaults.standard.set(dict, forKey: key)
    }
    
    func exportAll() -> [String: Int] {
        return UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }
    
    func importAll(_ dict: [String: Int]) {
        UserDefaults.standard.set(dict, forKey: key)
        UserDefaults.standard.synchronize()
    }
}

// MARK: - Manajer ZIP Sertifikat
class CertStorageManager {
    static let shared = CertStorageManager()

    private var certsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Certificates", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func saveZip(from sourceURL: URL, for itemId: UUID) -> String? {
        let canAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if canAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: sourceURL)
            let ext = sourceURL.pathExtension.isEmpty ? "zip" : sourceURL.pathExtension
            let fileName = "\(itemId.uuidString)_cert.\(ext)"
            let destURL = certsDirectory.appendingPathComponent(fileName)
            try data.write(to: destURL)
            return fileName
        } catch {
            return nil
        }
    }

    func getFileURL(fileName: String) -> URL? {
        let url = certsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func deleteFile(fileName: String?) {
        guard let fileName = fileName else { return }
        let url = certsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Jenis Sumber Cert
enum CertSourceType: String, Codable, CaseIterable {
    case reguler = "Kloter Reguler (20 Slot)"
    case manual = "Manual / Eceran"
    case trollstore = "TrollStore (Modal Rp 0)"
}

// MARK: - Model Data Penjualan
struct SaleItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var tanggalDaftar: Date
    var namaBuyer: String
    var kontakBuyer: String
    var udid: String
    var hargaJual: Int
    var durasiHari: Int
    var catatan: String
    var batchNumber: Int
    var zipFileName: String? = nil
    var certPassword: String? = nil
    
    var telahDibayar: Int? = nil

    var sourceType: CertSourceType? = .reguler
    var customModal: Int? = 0

    var currentSourceType: CertSourceType {
        return sourceType ?? .reguler
    }

    var nominalModalPerItem: Int {
        switch currentSourceType {
        case .reguler: return 0
        case .manual: return customModal ?? 0
        case .trollstore: return 0
        }
    }

    var nominalDibayar: Int {
        return telahDibayar ?? hargaJual
    }
    
    var sisaPembayaran: Int {
        return hargaJual - nominalDibayar
    }
    
    var isLunas: Bool {
        return sisaPembayaran <= 0
    }

    var expiredGaransiDate: Date {
        Calendar.current.date(byAdding: .day, value: durasiHari, to: tanggalDaftar) ?? tanggalDaftar
    }

    var expiredCertAppleDate: Date {
        Calendar.current.date(byAdding: .day, value: 365, to: tanggalDaftar) ?? tanggalDaftar
    }

    var isTelegram: Bool {
        let clean = kontakBuyer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return clean.hasPrefix("@") || clean.contains("t.me/")
    }

    var isDiscord: Bool {
        let clean = kontakBuyer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return clean.hasPrefix("dc:") || clean.hasPrefix("discord:") || clean.contains("discord.com") || clean.contains("discord.gg") || clean.contains("#")
    }

    var hasCertZip: Bool { zipFileName != nil }

    var displayName: String {
        let trimNama = namaBuyer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimNama.isEmpty && trimNama != "-" { return trimNama }

        let trimKontak = kontakBuyer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimKontak.isEmpty { return "Customer" }
        if isTelegram || isDiscord { return trimKontak }

        let digits = trimKontak.filter { $0.isNumber }
        if digits.count >= 8 {
            return "\(digits.prefix(4))••••\(digits.suffix(4))"
        }
        return "Customer WA"
    }
}

// MARK: - Struktur Data Cadangan Universal
struct BackupPayload: Codable {
    var items: [SaleItem]
    var batchModals: [String: Int]?
    var batchAdminFees: [String: Int]?
}

enum FilterGaransi: String, CaseIterable, Identifiable {
    case semua = "Semua"
    case aktif = "Aktif"
    case habis = "Habis"
    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .semua: return "tray.full.fill"
        case .aktif: return "sparkles"
        case .habis: return "clock.badge.xmark.fill"
        }
    }
}

struct GaransiOption: Identifiable {
    let id: Int
    let name: String
}

// MARK: - Modifier Liquid Glass
extension View {
    func liquidGlass(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.42))

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.14),
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
                                Gradient.Stop(color: Color.white.opacity(0.45), location: 0.0),
                                Gradient.Stop(color: Color.white.opacity(0.08), location: 0.45),
                                Gradient.Stop(color: Color.cyan.opacity(0.32), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 5)
    }
}

// MARK: - App Entry Point
@main
struct iBaalSalesApp: App {
    init() {
        FontManager.registerAllFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Share Sheet Wrapper
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Status Garansi View
struct StatusGaransiView: View {
    let now: Date
    let exp: Date
    let durasi: Int

    var status: (text: String, color: Color) {
        if durasi == 0 { return ("⚪ Non-Garansi", .gray) }
        if now >= exp { return ("🔴 Garansi Habis", .red) }
        let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: exp)
        let d = diff.day ?? 0
        let h = diff.hour ?? 0
        let m = diff.minute ?? 0
        return ("🟢 Garansi: \(d)h \(h)j \(m)m lagi", .green)
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)
                .shadow(color: status.color.opacity(0.8), radius: 3)
            Text(status.text)
                .font(.mali(11))
                .foregroundColor(status.color)
        }
    }
}

// MARK: - Switch Gelembung Prisma Compact
struct LiquidPrismSwitch: View {
    @Binding var selected: FilterGaransi
    @Namespace private var lensAnimation

    var body: some View {
        HStack(spacing: 6) {
            ForEach(FilterGaransi.allCases) { filter in
                let isSelected = (selected == filter)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selected = filter
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(filter.rawValue)
                            .font(.mali(12))
                    }
                    .foregroundColor(isSelected ? .white : .white.opacity(0.48))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)

                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.09))

                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [.cyan, .blue, .purple, .pink, .orange, .yellow, .green, .cyan]),
                                            center: .center
                                        ),
                                        lineWidth: 1.4
                                    )
                                    .matchedGeometryEffect(id: "PRISM_LENS", in: lensAnimation)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.55))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }
}

// MARK: - Helper Pendeteksi UDID
func detectDevice(from udid: String) -> String? {
    let clean = udid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard clean.count >= 24 && clean.contains("-") else { return nil }
    let prefix = clean.components(separatedBy: "-").first ?? ""
    
    switch prefix {
    case "00008020": return "iPhone XS / XR / 11"
    case "00008030": return "iPhone 11 Series / SE2"
    case "00008101": return "iPhone 12 Series"
    case "00008110": return "iPhone 13 / 14 / SE3"
    case "00008120": return "iPhone 14 Pro / 15 Series"
    case "00008130": return "iPhone 15 Pro Series"
    case "00008140": return "iPhone 16 Series"
    default: return nil
    }
}

// MARK: - Tampilan Utama
struct ContentView: View {
    @Environment(\.openURL) private var openURL

    @State private var items: [SaleItem] = []
    @State private var showAddModal = false
    @State private var showHistoryModal = false
    @State private var showEditBatchModal = false
    @State private var showOptionsMenu = false
    @State private var itemToEdit: SaleItem? = nil
    @State private var timerNow = Date()

    @AppStorage("hideFinancials") private var hideFinancials: Bool = false
    @State private var expandedBatches: Set<Int> = []
    @State private var searchText = ""
    @State private var selectedFilter: FilterGaransi = .semua

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var showFileImporter = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    @State private var forceRefresh = UUID()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var activeBatchNumber: Int {
        let regularItems = items.filter { $0.currentSourceType == .reguler }
        return regularItems.isEmpty ? 1 : ((regularItems.count - 1) / 20 + 1)
    }

    var activeBatchItems: [SaleItem] {
        items.filter { $0.batchNumber == activeBatchNumber && $0.currentSourceType == .reguler }
    }
    var slotTerjualDiBatchAktif: Int { activeBatchItems.count }
    var sisaSlotDiBatchAktif: Int { max(0, 20 - slotTerjualDiBatchAktif) }

    var modalKloterAktif: Int { BatchModalManager.shared.getModal(for: activeBatchNumber) }
    var feeAdminKloterAktif: Int { BatchAdminFeeManager.shared.getFee(for: activeBatchNumber) }
    
    var omsetKloterAktif: Int { activeBatchItems.reduce(0) { $0 + $1.hargaJual } }
    var uangMasukKloterAktif: Int { activeBatchItems.reduce(0) { $0 + $1.nominalDibayar } }
    var piutangKloterAktif: Int { activeBatchItems.reduce(0) { $0 + $1.sisaPembayaran } }
    
    var labaBersihOwnerAktif: Int {
        (uangMasukKloterAktif - modalKloterAktif) - feeAdminKloterAktif
    }
    
    var completedBatchesCount: Int {
        let regularItems = items.filter { $0.currentSourceType == .reguler }
        return regularItems.count / 20
    }
    
    var totalOmsetSemua: Int { items.reduce(0) { $0 + $1.hargaJual } }

    var filteredItems: [SaleItem] {
        items.filter { item in
            let matchSearch: Bool
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                matchSearch = true
            } else {
                let q = searchText.lowercased()
                matchSearch = item.displayName.lowercased().contains(q) ||
                              item.kontakBuyer.lowercased().contains(q) ||
                              item.udid.lowercased().contains(q) ||
                              item.catatan.lowercased().contains(q) ||
                              item.currentSourceType.rawValue.lowercased().contains(q)
            }

            let matchFilter: Bool
            switch selectedFilter {
            case .semua: matchFilter = true
            case .aktif: matchFilter = item.durasiHari > 0 && timerNow < item.expiredGaransiDate
            case .habis: matchFilter = item.durasiHari == 0 || timerNow >= item.expiredGaransiDate
            }

            return matchSearch && matchFilter
        }
    }

    var batchesInFiltered: [Int] {
        Array(Set(filteredItems.map { $0.batchNumber })).sorted(by: >)
    }

    func isBatchExpanded(_ batch: Int) -> Bool {
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return expandedBatches.contains(batch)
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.07).ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.30))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: -120, y: -320)

            Circle()
                .fill(Color.purple.opacity(0.25))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 130, y: 320)

            VStack(spacing: 8) {
                customTopBar
                customSearchBar

                ScrollView {
                    VStack(spacing: 12) {
                        summaryDashboardView
                            .id(forceRefresh)

                        LiquidPrismSwitch(selected: $selectedFilter)

                        HStack {
                            Text("DAFTAR PEMBELI")
                                .font(.mali(12))
                                .foregroundColor(.white.opacity(0.55))
                            Spacer()
                            Text("\(filteredItems.count) Terfilter / \(items.count) Total")
                                .font(.mali(12))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal)
                        .padding(.top, 2)

                        if filteredItems.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.2))
                                Text(items.isEmpty ? "Belum ada transaksi di kloter ini.\nTekan + di pojok kanan atas." : "Tidak ada transaksi yang cocok.")
                                    .font(.mali(14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                            .padding(.bottom, 60)
                        } else {
                            ForEach(batchesInFiltered, id: \.self) { batch in
                                VStack(spacing: 6) {
                                    kloterAccordionHeader(batch: batch, count: filteredItems.filter { $0.batchNumber == batch }.count)

                                    if isBatchExpanded(batch) {
                                        VStack(spacing: 8) {
                                            ForEach(filteredItems.filter { $0.batchNumber == batch }) { item in
                                                buyerCard(item: item)
                                            }
                                        }
                                        .transition(.opacity)
                                    }
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if showOptionsMenu {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            showOptionsMenu = false
                        }
                    }

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            
                            Button {
                                withAnimation { showOptionsMenu = false }
                                showHistoryModal = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "archivebox.fill").foregroundColor(.green)
                                    Text("Arsip Kloter Selesai")
                                        .font(.mali(13))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    hideFinancials.toggle()
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: hideFinancials ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.cyan)
                                    Text(hideFinancials ? "Tampilkan Saldo" : "Sembunyikan Saldo")
                                        .font(.mali(13))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }

                            Button {
                                withAnimation { showOptionsMenu = false }
                                showEditBatchModal = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "dollarsign.circle.fill").foregroundColor(.orange)
                                    Text("Ubah Modal & Fee Kloter Reguler")
                                        .font(.mali(13))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }

                            Divider().background(Color.white.opacity(0.15))

                            Button {
                                withAnimation { showOptionsMenu = false }
                                exportBackup()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "square.and.arrow.up").foregroundColor(.yellow)
                                    Text("Cadangkan Data (Backup)")
                                        .font(.mali(13))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }

                            Button {
                                withAnimation { showOptionsMenu = false }
                                showFileImporter = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "square.and.arrow.down").foregroundColor(.purple)
                                    Text("Pulihkan Data (Restore)")
                                        .font(.mali(13))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(8)
                        .frame(width: 260)
                        .liquidGlass(cornerRadius: 16)
                        .padding(.leading, 14)
                        .padding(.top, 50)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
                .zIndex(99)
            }
        }
        .sheet(isPresented: $showAddModal) {
            SaleFormSheet(
                itemToEdit: nil,
                existingItems: items,
                onDelete: nil,
                onSave: { newItem in
                    items.insert(newItem, at: 0)
                    recalculateAndSave()
                    withAnimation { expandedBatches.insert(newItem.batchNumber) }
                }
            )
        }
        .sheet(item: $itemToEdit) { currentItem in
            SaleFormSheet(
                itemToEdit: currentItem,
                existingItems: items,
                onDelete: { deletedId in
                    if let del = items.first(where: { $0.id == deletedId }) {
                        CertStorageManager.shared.deleteFile(fileName: del.zipFileName)
                    }
                    items.removeAll { $0.id == deletedId }
                    recalculateAndSave()
                },
                onSave: { updatedItem in
                    if let idx = items.firstIndex(where: { $0.id == updatedItem.id }) {
                        items[idx] = updatedItem
                        saveDirectlyWithoutReorderingBatch()
                    }
                }
            )
        }
        .sheet(isPresented: $showEditBatchModal) {
            EditBatchModalSheet(
                batchNumber: activeBatchNumber,
                currentModal: BatchModalManager.shared.getModal(for: activeBatchNumber),
                currentAdminFee: BatchAdminFeeManager.shared.getFee(for: activeBatchNumber)
            ) { updatedModal, updatedFee in
                BatchModalManager.shared.setModal(for: activeBatchNumber, modal: updatedModal)
                BatchAdminFeeManager.shared.setFee(for: activeBatchNumber, fee: updatedFee)
                forceRefresh = UUID()
            }
        }
        .sheet(isPresented: $showHistoryModal) {
            BatchHistorySheet(
                allItems: items,
                hideFinancials: hideFinancials,
                onEditItem: { item in
                    itemToEdit = item
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet(activityItems: shareItems)
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json, .plainText]) { result in
            handleImportBackup(result: result)
        }
        .alert("Informasi", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage).font(.mali(14))
        }
        .onReceive(timer) { input in
            timerNow = input
        }
        .onAppear {
            loadData()
        }
    }

    private var customTopBar: some View {
        ZStack {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showOptionsMenu.toggle()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }

                Spacer()

                Button {
                    showAddModal = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 38, height: 38)
                        .background(Color.cyan)
                        .clipShape(Circle())
                }
            }
            
            Text("i B a a L CERT STORE")
                .font(.mali(19))
                .foregroundColor(.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var customSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.gray)

            TextField("Cari nama, UDID, TrollStore, Manual...", text: $searchText)
                .font(.mali(13))
                .foregroundColor(.white)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func kloterAccordionHeader(batch: Int, count: Int) -> some View {
        let isExpanded = isBatchExpanded(batch)
        let isManualOrTroll = (batch == 9999)
        let isCurrent = (batch == activeBatchNumber)

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                if expandedBatches.contains(batch) {
                    expandedBatches.remove(batch)
                } else {
                    expandedBatches.insert(batch)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isManualOrTroll ? .orange : (isCurrent ? .cyan : .white.opacity(0.6)))

                Text(isManualOrTroll ? "KLOTER MANUAL / TROLLSTORE" : "KLOTER #\(batch)")
                    .font(.mali(13))
                    .foregroundColor(.white)

                Text(isManualOrTroll ? "KHUSUS" : (isCurrent ? "AKTIF" : "SELESAI"))
                    .font(.mali(10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isManualOrTroll ? Color.orange.opacity(0.22) : (isCurrent ? Color.cyan.opacity(0.22) : Color.green.opacity(0.22)))
                    .foregroundColor(isManualOrTroll ? .orange : (isCurrent ? .cyan : .green))
                    .cornerRadius(5)

                Spacer()

                Text(isManualOrTroll ? "\(count) Device" : "\(count)/20 Cert")
                    .font(.mali(12))
                    .foregroundColor(isManualOrTroll ? .orange : (count >= 20 ? .green : .gray))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .liquidGlass(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var summaryDashboardView: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles").foregroundColor(.cyan)
                    Text("KLOTER AKTIF #\(activeBatchNumber)")
                        .font(.mali(13))
                        .foregroundColor(.cyan)
                }
                Spacer()

                if completedBatchesCount > 0 {
                    Button {
                        showHistoryModal = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox.fill")
                            Text("\(completedBatchesCount) Selesai ➔")
                        }
                        .font(.mali(11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                        .foregroundColor(.green)
                    }
                } else {
                    Text("Live Monitor")
                        .font(.mali(11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                        .foregroundColor(.green)
                }
            }

            VStack(spacing: 2) {
                Text(hideFinancials ? "Rp ••••••••" : (labaBersihOwnerAktif >= 0 ? "+\(AppFormatters.idr(labaBersihOwnerAktif))" : AppFormatters.idr(labaBersihOwnerAktif)))
                    .font(.mali(22))
                    .foregroundColor(hideFinancials ? .gray : (labaBersihOwnerAktif >= 0 ? .green : .red))

                if hideFinancials {
                    Text("Mode Sensor Finansial Aktif 🔒")
                        .font(.mali(11))
                        .foregroundColor(.gray)
                } else {
                    Text("Keuntungan Bersih Kloter Reguler Aktif")
                        .font(.mali(11))
                        .foregroundColor(.cyan.opacity(0.9))
                }
            }

            VStack(spacing: 5) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "cube.box.fill")
                        Text("\(slotTerjualDiBatchAktif)/20 Slot Terjual")
                            .font(.mali(12))
                    }
                    .foregroundColor(slotTerjualDiBatchAktif >= 20 ? .green : .white)
                    Spacer()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(slotTerjualDiBatchAktif >= 20 ? Color.green : Color.cyan)
                            .frame(width: min(geo.size.width * CGFloat(slotTerjualDiBatchAktif) / 20.0, geo.size.width), height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text(slotTerjualDiBatchAktif >= 20 ? "20/20 Penuh! Kloter reguler berikutnya terbuka otomatis." : "Tersisa \(sisaSlotDiBatchAktif) slot di kloter reguler ini.")
                        .font(.mali(10))
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)

            Divider().background(Color.white.opacity(0.12))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Omset Aktif").font(.mali(11)).foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : AppFormatters.idr(omsetKloterAktif))
                        .font(.mali(13))
                        .foregroundColor(hideFinancials ? .gray : .white)
                    
                    if piutangKloterAktif > 0 {
                        Text("Piutang DP: \(hideFinancials ? "••••" : AppFormatters.idr(piutangKloterAktif))")
                            .font(.mali(10))
                            .foregroundColor(.red)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Semua Omset").font(.mali(11)).foregroundColor(.gray)
                    Text(hideFinancials ? "Rp ••••••" : AppFormatters.idr(totalOmsetSemua))
                        .font(.mali(13))
                        .foregroundColor(hideFinancials ? .gray : .cyan)
                }
            }
        }
        .padding(14)
        .liquidGlass(cornerRadius: 18)
        .padding(.horizontal)
    }

    private func buyerCard(item: SaleItem) -> some View {
        let isTele = item.isTelegram
        let isDc = item.isDiscord
        
        let badgeColor: Color = isDc ? Color(red: 0.35, green: 0.40, blue: 0.95) :
                               (isTele ? Color(red: 0.20, green: 0.65, blue: 0.95) :
                                         Color(red: 0.15, green: 0.82, blue: 0.45))
        
        let iconName = isDc ? "bubble.left.and.bubble.right.fill" : (isTele ? "paperplane.fill" : "phone.bubble.left.fill")

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Button {
                    openChatLink(item.kontakBuyer)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: iconName).font(.system(size: 12, weight: .bold))
                        Text(item.displayName).font(.mali(14))
                    }
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(badgeColor.opacity(0.18))
                    .cornerRadius(8)
                }

                if item.currentSourceType == .trollstore {
                    Text("TrollStore 🚀")
                        .font(.mali(9))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(5)
                } else if item.currentSourceType == .manual {
                    Text("Manual ⚡")
                        .font(.mali(9))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(5)
                } else {
                    Text("Kloter #\(item.batchNumber)")
                        .font(.mali(10))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(5)
                }

                Spacer()

                HStack(spacing: 8) {
                    if !hideFinancials {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(AppFormatters.idr(item.hargaJual))
                                .font(.mali(13))
                                .foregroundColor(.cyan)
                            
                            if !item.isLunas {
                                Text("Kurang \(AppFormatters.idr(item.sisaPembayaran))")
                                    .font(.mali(10))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .cornerRadius(4)
                            } else if item.currentSourceType == .trollstore {
                                Text("Untung 100%")
                                    .font(.mali(9))
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    Button {
                        itemToEdit = item
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 19))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            HStack(spacing: 6) {
                if item.hasCertZip {
                    Button {
                        shareCertZip(item: item)
                    } label: {
                        Label("ZIP Cert", systemImage: "doc.zipper")
                            .font(.mali(10))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.cyan.opacity(0.18))
                            .foregroundColor(.cyan)
                            .cornerRadius(6)
                    }
                }

                Button {
                    copyNotaPembelian(item: item)
                } label: {
                    Label("Nota 📝", systemImage: "text.receipt")
                        .font(.mali(10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.18))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                }

                Button {
                    copyNotaDiscord(item: item)
                } label: {
                    Label("Nota DC 💬", systemImage: "bubble.left.and.exclamationmark.bubble.right.fill")
                        .font(.mali(10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.35, green: 0.40, blue: 0.95).opacity(0.2))
                        .foregroundColor(Color(red: 0.55, green: 0.60, blue: 1.0))
                        .cornerRadius(6)
                }

                if let pass = item.certPassword, !pass.isEmpty {
                    Button {
                        UIPasteboard.general.string = pass
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                            Text("Pass: \(hideFinancials ? "••••" : pass)")
                        }
                        .font(.mali(10))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Color.yellow.opacity(0.15))
                        .foregroundColor(.yellow)
                        .cornerRadius(6)
                    }
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("UDID:").font(.mali(11)).foregroundColor(.gray)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = item.udid
                    } label: {
                        Label("Salin", systemImage: "doc.on.doc")
                            .font(.mali(10))
                            .foregroundColor(.cyan)
                    }
                }
                Text(hideFinancials ? maskUDID(item.udid) : item.udid)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .background(Color.black.opacity(0.35))
            .cornerRadius(8)

            if !item.catatan.isEmpty && item.catatan != "-" {
                Text("📱 \(item.catatan)")
                    .font(.mali(11))
                    .foregroundColor(.gray)
            }

            Divider().background(Color.white.opacity(0.1))

            VStack(spacing: 4) {
                HStack {
                    StatusGaransiView(now: timerNow, exp: item.expiredGaransiDate, durasi: item.durasiHari)
                    Spacer()
                    Text("Garansi: \(item.durasiHari == 0 ? "Non-Garansi" : AppFormatters.date(item.expiredGaransiDate))")
                        .font(.mali(11))
                        .foregroundColor(item.durasiHari == 0 ? .gray : .orange.opacity(0.95))
                }
                HStack {
                    Text("Daftar: \(AppFormatters.date(item.tanggalDaftar))").font(.mali(11)).foregroundColor(.gray)
                    Spacer()
                    Text("Cert Apple: \(AppFormatters.date(item.expiredCertAppleDate))")
                        .font(.mali(11))
                        .foregroundColor(.cyan.opacity(0.85))
                }
            }
        }
        .padding(12)
        .liquidGlass(cornerRadius: 16)
        .padding(.horizontal)
    }

    private func copyNotaPembelian(item: SaleItem) {
        let status = item.isLunas ? "LUNAS ✅" : "BELUM LUNAS (Kurang \(AppFormatters.idr(item.sisaPembayaran))) ❌"
        let pesan = """
        🎉 Terima kasih sudah order di i B a a L CERT STORE! 🎉
        
        👤 Nama: \(item.displayName)
        📱 Tipe HP: \(item.catatan.isEmpty ? "-" : item.catatan)
        🛡 Garansi: \(item.durasiHari == 0 ? "Non-Garansi" : "\(item.durasiHari) Hari")
        💳 Status Pembayaran: \(status)
        
        📝 UDID Perangkat:
        \(item.udid)
        
        Sertifikat berhasil didaftarkan! Jika butuh bantuan atau panduan instalasi, silakan balas chat ini ya kak. 🙌
        """
        UIPasteboard.general.string = pesan
        alertMessage = "Nota pembelian berhasil disalin ke clipboard!"
        showAlert = true
    }

    private func copyNotaDiscord(item: SaleItem) {
        let status = item.isLunas ? "**LUNAS** :white_check_mark:" : "**BELUM LUNAS (Kurang \(AppFormatters.idr(item.sisaPembayaran)))** :x:"
        let pesan = """
        >>> :tada: **TERIMA KASIH TELAH ORDER DI iBaaL CERT STORE!** :tada:

        **Detail Pembelian:**
        :bust_in_silhouette: **User:** \(item.displayName)
        :iphone: **Device:** `\(item.catatan.isEmpty ? "iOS Device" : item.catatan)`
        :shield: **Garansi:** `\(item.durasiHari == 0 ? "Non-Garansi" : "\(item.durasiHari) Hari")`
        :credit_card: **Status:** \(status)
        :calendar: **Tanggal:** `\(AppFormatters.date(item.tanggalDaftar))`

        :key: **UDID Terdaftar:**
        ```
        \(item.udid)
        ```
        :rocket: *Sertifikat berhasil di-sign & aktif! Silakan kontak admin jika butuh bantuan atau file cert.*
        """
        UIPasteboard.general.string = pesan
        alertMessage = "Nota Discord berhasil disalin (Markdown Format)!"
        showAlert = true
    }

    private func maskUDID(_ u: String) -> String {
        let clean = u.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count >= 12 {
            return "\(clean.prefix(8))-••••••••••••••••"
        }
        return "••••••••••••••••"
    }

    private func shareCertZip(item: SaleItem) {
        guard let zipName = item.zipFileName,
              let originalURL = CertStorageManager.shared.getFileURL(fileName: zipName) else { return }

        let pass = (item.certPassword?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? item.certPassword!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "ibaalcert"

        let customFileName = "password - \(pass).zip"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(customFileName)

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: originalURL, to: tempURL)
            shareItems = [tempURL]
            showShareSheet = true
        } catch {
            shareItems = [originalURL]
            showShareSheet = true
        }
    }

    private func openChatLink(_ contact: String) {
        let clean = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        var urlString = ""

        if clean.hasPrefix("@") {
            urlString = "https://t.me/\(clean.replacingOccurrences(of: "@", with: ""))"
        } else if clean.lowercased().contains("t.me/") {
            urlString = clean.hasPrefix("http") ? clean : "https://\(clean)"
        } else if clean.lowercased().hasPrefix("dc:") || clean.lowercased().hasPrefix("discord:") {
            let dcUser = clean.replacingOccurrences(of: "dc:", with: "", options: .caseInsensitive)
                             .replacingOccurrences(of: "discord:", with: "", options: .caseInsensitive)
                             .trimmingCharacters(in: .whitespacesAndNewlines)
            UIPasteboard.general.string = dcUser
            alertMessage = "Username Discord '\(dcUser)' berhasil disalin!"
            showAlert = true
            return
        } else if clean.lowercased().contains("discord.com") || clean.lowercased().contains("discord.gg") {
            urlString = clean.hasPrefix("http") ? clean : "https://\(clean)"
        } else if clean.contains("#") {
            UIPasteboard.general.string = clean
            alertMessage = "Tag Discord '\(clean)' berhasil disalin!"
            showAlert = true
            return
        } else {
            let digits = clean.filter { $0.isNumber }
            urlString = digits.hasPrefix("08") ? "https://wa.me/62\(digits.dropFirst())" : "https://wa.me/\(digits)"
        }

        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    private func exportBackup() {
        do {
            let modals = BatchModalManager.shared.exportAll()
            let fees = BatchAdminFeeManager.shared.exportAll()
            
            let payload = BackupPayload(items: items, batchModals: modals, batchAdminFees: fees)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(payload)

            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd_HHmmss"
            let fileName = "Backup_CertManager_\(df.string(from: Date())).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            try data.write(to: tempURL)
            shareItems = [tempURL]
            showShareSheet = true
        } catch {
            alertMessage = "Gagal ekspor: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // PENANGANAN RESTORE / IMPORT YANG FLEKSIBEL (UNIVERSAL DECODER)
    private func handleImportBackup(result: Result<URL, Error>) {
        do {
            let fileURL = try result.get()
            let canAccess = fileURL.startAccessingSecurityScopedResource()
            defer { if canAccess { fileURL.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: fileURL)
            
            // 1. Coba decode sebagai payload lengkap terbaru
            if let payload = try? JSONDecoder().decode(BackupPayload.self, from: data) {
                items = payload.items
                if let modals = payload.batchModals {
                    BatchModalManager.shared.importAll(modals)
                }
                if let fees = payload.batchAdminFees {
                    BatchAdminFeeManager.shared.importAll(fees)
                }
                recalculateAndSave()
                alertMessage = "Sukses memulihkan \(payload.items.count) transaksi & Data Modal Kloter."
            } 
            // 2. Coba decode sebagai array item mentah (format lama)
            else if let im = try? JSONDecoder().decode([SaleItem].self, from: data) {
                items = im
                recalculateAndSave()
                alertMessage = "Sukses memulihkan \(im.count) transaksi (Format Lama)."
            } else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Format berkas tidak dikenali"])
            }
            
            forceRefresh = UUID()
            showAlert = true
        } catch {
            alertMessage = "Gagal memulihkan berkas JSON: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func saveDirectlyWithoutReorderingBatch() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "saved_sales")
        }
        AutoSaveManager.shared.save(items)
        forceRefresh = UUID()
    }

    private func recalculateAndSave() {
        let regularItemsAscending = items.filter { $0.currentSourceType == .reguler }.sorted { $0.tanggalDaftar < $1.tanggalDaftar }
        var updatedRegular: [SaleItem] = []

        for (index, item) in regularItemsAscending.enumerated() {
            var updated = item
            updated.batchNumber = (index / 20) + 1
            updatedRegular.append(updated)
        }

        let nonRegularItems = items.filter { $0.currentSourceType != .reguler }.map { item -> SaleItem in
            var updated = item
            updated.batchNumber = 9999
            return updated
        }

        let allMerged = updatedRegular + nonRegularItems
        items = allMerged.sorted { $0.tanggalDaftar > $1.tanggalDaftar }

        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "saved_sales")
        }
        AutoSaveManager.shared.save(items)
        forceRefresh = UUID()
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "saved_sales"),
           let decoded = try? JSONDecoder().decode([SaleItem].self, from: data) {
            items = decoded
            recalculateAndSave()
        } else if let autoSavedItems = AutoSaveManager.shared.loadAutoSave(), !autoSavedItems.isEmpty {
            items = autoSavedItems
            recalculateAndSave()
        }
    }
}

// MARK: - Formulir Tambah / Edit Penjualan
struct SaleFormSheet: View {
    @Environment(\.dismiss) var dismiss

    var itemToEdit: SaleItem?
    var existingItems: [SaleItem]
    var onDelete: ((UUID) -> Void)?
    var onSave: (SaleItem) -> Void

    @State private var itemId = UUID()
    @State private var namaBuyer = ""
    @State private var kontakBuyer = ""
    @State private var tanggalDaftar = Date()
    @State private var udid = ""
    
    @State private var hargaJualText = "120000"
    @State private var isLunas = true
    @State private var telahDibayarText = ""
    
    @State private var selectedSourceType: CertSourceType = .reguler
    @State private var customModalText = "0"
    
    @State private var selectedGaransi = 90
    @State private var catatan = ""
    @State private var batchNumber = 1

    @State private var zipFileName: String? = nil
    @State private var certPassword = ""
    @State private var showZipPicker = false

    @State private var showDuplicateAlert = false
    @State private var duplicateDetails = ""
    @State private var pendingItemToSave: SaleItem? = nil

    let opsiGaransi: [GaransiOption] = [
        GaransiOption(id: 30, name: "1 Bulan (Paket Basic)"),
        GaransiOption(id: 90, name: "3 Bulan (Paket Regular)"),
        GaransiOption(id: 180, name: "6 Bulan (Paket VIP)"),
        GaransiOption(id: 365, name: "1 Tahun Full"),
        GaransiOption(id: 0, name: "Tanpa Garansi")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SUMBER PENDAFTARAN CERT").font(.mali(12)).foregroundColor(.cyan)

                            Picker("Sumber", selection: $selectedSourceType) {
                                ForEach(CertSourceType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(4)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)

                            if selectedSourceType == .manual {
                                HStack {
                                    Text("Modal Manual (Rp):").font(.mali(13)).foregroundColor(.orange)
                                    Spacer()
                                    TextField("Misal: 70000", text: $customModalText)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.mali(15))
                                        .foregroundColor(.orange)
                                }
                                .padding(10)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(10)
                                .padding(.top, 4)
                            } else if selectedSourceType == .trollstore {
                                HStack {
                                    Image(systemName: "bolt.fill").foregroundColor(.green)
                                    Text("TrollStore: Modal Rp 0 (Untung 100% Bersih)")
                                        .font(.mali(12))
                                        .foregroundColor(.green)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(8)
                                .padding(.top, 2)
                            }
                        }
                        .padding(12)
                        .liquidGlass(cornerRadius: 16)
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("INFORMASI PEMBELI").font(.mali(12)).foregroundColor(.cyan)

                            TextField("Nama Buyer (Boleh kosong)", text: $namaBuyer)
                                .font(.mali(14))
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)

                            TextField("Kontak: 08xx (WA), @username (Tele), dc:user (Discord)", text: $kontakBuyer)
                                .font(.mali(14))
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                        }
                        .padding(12)
                        .liquidGlass(cornerRadius: 16)
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("HARGA JUAL & PEMBAYARAN").font(.mali(12)).foregroundColor(.cyan)

                            HStack {
                                Text("Harga Total (Rp)").font(.mali(14))
                                Spacer()
                                TextField("120000", text: $hargaJualText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.mali(16))
                                    .foregroundColor(.cyan)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                            
                            Toggle("Lunas (Bayar Penuh)", isOn: $isLunas)
                                .font(.mali(14))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                                .tint(.green)
                            
                            if !isLunas {
                                HStack {
                                    Text("Baru Dibayar (DP)").font(.mali(14)).foregroundColor(.orange)
                                    Spacer()
                                    TextField("0", text: $telahDibayarText)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .font(.mali(16))
                                        .foregroundColor(.orange)
                                }
                                .padding(10)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(10)
                            }
                        }
                        .padding(12)
                        .liquidGlass(cornerRadius: 16)
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOMOR UDID").font(.mali(12)).foregroundColor(.cyan)

                            TextEditor(text: $udid)
                                .frame(minHeight: 46)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(6)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                                .onChange(of: udid) { newValue in
                                    if catatan.trimmingCharacters(in: .whitespaces).isEmpty {
                                        if let model = detectDevice(from: newValue) {
                                            catatan = model
                                        }
                                    }
                                }

                            TextField("Catatan HP (misal: iPhone 11 128GB)", text: $catatan)
                                .font(.mali(14))
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                        }
                        .padding(12)
                        .liquidGlass(cornerRadius: 16)
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("BERKAS ZIP & KATA SANDI").font(.mali(12)).foregroundColor(.cyan)

                            if zipFileName != nil {
                                HStack {
                                    Image(systemName: "doc.zipper").foregroundColor(.cyan)
                                    Text("ZIP Sertifikat Terpasang ✅").font(.mali(13)).foregroundColor(.green)
                                    Spacer()
                                    Button("Hapus") {
                                        CertStorageManager.shared.deleteFile(fileName: zipFileName)
                                        zipFileName = nil
                                    }
                                    .font(.mali(12))
                                    .foregroundColor(.red)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                            } else {
                                Button {
                                    showZipPicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.badge.plus").foregroundColor(.cyan)
                                        Text("Pilih Berkas ZIP Cert").font(.mali(13)).foregroundColor(.cyan)
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundColor(.gray)
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(10)
                                }
                            }

                            HStack {
                                Image(systemName: "key.fill").foregroundColor(.yellow)
                                TextField("Password Cert (default: ibaalcert)", text: $certPassword)
                                    .font(.mali(13))
                                    .autocapitalization(.none)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                        }
                        .padding(12)
                        .liquidGlass(cornerRadius: 16)
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("GARANSI & TANGGAL").font(.mali(12)).foregroundColor(.cyan)

                            DatePicker("Tanggal Masuk", selection: $tanggalDaftar, displayedComponents: [.date, .hourAndMinute])
                                .font(.mali(13))
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)

                            Picker("Paket Garansi", selection: $selectedGaransi) {
                                ForEach(opsiGaransi) { item in
                                    Text(item.name).font(.mali(13)).tag(item.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                        }
                        .padding(12)
                        .liquidGlass(cornerRadius: 16)
                        .padding(.horizontal)

                        if itemToEdit != nil {
                            Button {
                                if let id = itemToEdit?.id { onDelete?(id) }
                                dismiss()
                            } label: {
                                Text("Hapus Transaksi Ini")
                                    .font(.mali(14))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle(itemToEdit == nil ? "Tambah Penjualan" : "Edit Penjualan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { dismiss() }.font(.mali(14))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Simpan") { validateAndSave() }.font(.mali(15)).foregroundColor(.cyan)
                }
            }
            .fileImporter(isPresented: $showZipPicker, allowedContentTypes: [.zip, .archive, .data]) { res in
                if let url = try? res.get() {
                    zipFileName = CertStorageManager.shared.saveZip(from: url, for: itemId)
                }
            }
            .alert("⚠ UDID Sudah Terdaftar!", isPresented: $showDuplicateAlert) {
                Button("Batal", role: .cancel) { pendingItemToSave = nil }
                Button("Tetap Simpan", role: .destructive) {
                    if let item = pendingItemToSave {
                        onSave(item)
                        dismiss()
                    }
                }
            } message: {
                Text(duplicateDetails).font(.mali(12))
            }
            .onAppear {
                if let item = itemToEdit {
                    itemId = item.id
                    namaBuyer = item.namaBuyer
                    kontakBuyer = item.kontakBuyer
                    tanggalDaftar = item.tanggalDaftar
                    udid = item.udid
                    
                    hargaJualText = String(item.hargaJual)
                    isLunas = item.isLunas
                    telahDibayarText = String(item.nominalDibayar)
                    
                    selectedSourceType = item.currentSourceType
                    customModalText = String(item.customModal ?? 0)
                    
                    selectedGaransi = item.durasiHari
                    catatan = item.catatan
                    batchNumber = item.batchNumber
                    zipFileName = item.zipFileName
                    certPassword = item.certPassword ?? ""
                }
            }
        }
    }

    private func validateAndSave() {
        let cleanUDID = udid.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalHarga = Int(hargaJualText) ?? 120000
        let finalDibayar = isLunas ? finalHarga : (Int(telahDibayarText) ?? 0)
        let parsedCustomModal = (selectedSourceType == .manual) ? (Int(customModalText) ?? 0) : 0
        
        let targetBatch = (selectedSourceType == .reguler) ? batchNumber : 9999

        let finalItem = SaleItem(
            id: itemId,
            tanggalDaftar: tanggalDaftar,
            namaBuyer: namaBuyer.trimmingCharacters(in: .whitespacesAndNewlines),
            kontakBuyer: kontakBuyer.trimmingCharacters(in: .whitespacesAndNewlines),
            udid: cleanUDID.isEmpty ? "-" : cleanUDID,
            hargaJual: finalHarga,
            durasiHari: selectedGaransi,
            catatan: catatan,
            batchNumber: targetBatch,
            zipFileName: zipFileName,
            certPassword: certPassword.trimmingCharacters(in: .whitespacesAndNewlines),
            telahDibayar: finalDibayar,
            sourceType: selectedSourceType,
            customModal: parsedCustomModal
        )

        if !cleanUDID.isEmpty && cleanUDID != "-" {
            let lowerUDID = cleanUDID.lowercased()
            if let duplikat = existingItems.first(where: {
                $0.id != finalItem.id && $0.udid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lowerUDID
            }) {
                let df = DateFormatter()
                df.dateFormat = "dd/MM/yyyy"
                duplicateDetails = "UDID ini sudah pernah didaftarkan atas nama \"\(duplikat.displayName)\" pada tanggal \(df.string(from: duplikat.tanggalDaftar))."
                pendingItemToSave = finalItem
                showDuplicateAlert = true
                return
            }
        }
        onSave(finalItem)
        dismiss()
    }
}

// MARK: - Lembar Ubah Modal & Fee Admin
struct EditBatchModalSheet: View {
    @Environment(\.dismiss) var dismiss
    var batchNumber: Int
    var currentModal: Int
    var currentAdminFee: Int
    var onSave: (Int, Int) -> Void

    @State private var modalText = ""
    @State private var adminFeeText = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MODAL KLOTER #\(batchNumber)").font(.mali(12)).foregroundColor(.cyan)
                        TextField("0", text: $modalText)
                            .keyboardType(.numberPad)
                            .font(.mali(16))
                            .foregroundColor(.cyan)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                    }
                    .padding(12)
                    .liquidGlass(cornerRadius: 16)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("POTONGAN GAJI / FEE ADMIN").font(.mali(12)).foregroundColor(.orange)
                        TextField("0", text: $adminFeeText)
                            .keyboardType(.numberPad)
                            .font(.mali(16))
                            .foregroundColor(.orange)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                    }
                    .padding(12)
                    .liquidGlass(cornerRadius: 16)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Modal & Fee #\(batchNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Batal") { dismiss() }.font(.mali(14))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Simpan") {
                        onSave(Int(modalText) ?? 0, Int(adminFeeText) ?? 0)
                        dismiss()
                    }
                    .font(.mali(15))
                    .foregroundColor(.cyan)
                }
            }
            .onAppear {
                modalText = String(currentModal)
                adminFeeText = String(currentAdminFee)
            }
        }
    }
}

struct EditableBatch: Identifiable {
    let id: Int
}

// MARK: - Arsip Kloter Selesai
struct BatchHistorySheet: View {
    @Environment(\.dismiss) var dismiss
    var allItems: [SaleItem]
    var hideFinancials: Bool
    var onEditItem: (SaleItem) -> Void

    @State private var forceRefresh = UUID()
    @State private var batchToEdit: EditableBatch? = nil

    var completedBatches: [Int] {
        let regularItems = allItems.filter { $0.currentSourceType == .reguler }
        let count = regularItems.count / 20
        var list = count > 0 ? Array((1...count).reversed()) : []
        
        if allItems.contains(where: { $0.currentSourceType != .reguler }) {
            list.insert(9999, at: 0)
        }
        return list
    }

    var totalUntung: Int {
        var total = 0
        for b in completedBatches {
            let bItems = allItems.filter { $0.batchNumber == b }
            let uangMasuk = bItems.reduce(0) { $0 + $1.nominalDibayar }
            
            if b == 9999 {
                let modalManualPerItem = bItems.reduce(0) { $0 + $1.nominalModalPerItem }
                total += (uangMasuk - modalManualPerItem)
            } else {
                let modal = BatchModalManager.shared.getModal(for: b)
                let fee = BatchAdminFeeManager.shared.getFee(for: b)
                total += ((uangMasuk - modal) - fee)
            }
        }
        return total
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("TOTAL UNTUNG BERSIH SEMUA KLOTER").font(.mali(12)).foregroundColor(.green.opacity(0.8))
                            Text(hideFinancials ? "Rp ••••••••" : "+\(AppFormatters.idr(totalUntung))")
                                .font(.mali(24))
                                .foregroundColor(hideFinancials ? .gray : .green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(14)
                        .padding(.horizontal)

                        ForEach(completedBatches, id: \.self) { b in
                            let isManualOrTroll = (b == 9999)
                            let bItems = allItems.filter { $0.batchNumber == b }
                            let omset = bItems.reduce(0) { $0 + $1.hargaJual }
                            let uangMasuk = bItems.reduce(0) { $0 + $1.nominalDibayar }
                            let piutang = bItems.reduce(0) { $0 + $1.sisaPembayaran }
                            
                            let modal = isManualOrTroll ? bItems.reduce(0) { $0 + $1.nominalModalPerItem } : BatchModalManager.shared.getModal(for: b)
                            let fee = isManualOrTroll ? 0 : BatchAdminFeeManager.shared.getFee(for: b)
                            let keuntunganBersih = isManualOrTroll ? (uangMasuk - modal) : ((uangMasuk - modal) - fee)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(isManualOrTroll ? "Kloter Manual & TrollStore" : "Kloter #\(b)").font(.mali(15))
                                    
                                    if !isManualOrTroll {
                                        Button {
                                            batchToEdit = EditableBatch(id: b)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "pencil")
                                                Text("Edit Modal")
                                            }
                                            .font(.mali(10))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.cyan.opacity(0.15))
                                            .foregroundColor(.cyan)
                                            .cornerRadius(6)
                                        }
                                    }

                                    Spacer()
                                    Text(isManualOrTroll ? "\(bItems.count) Device" : "20/20 Selesai ✅")
                                        .font(.mali(10))
                                        .foregroundColor(isManualOrTroll ? .orange : .green)
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Modal: \(hideFinancials ? "••••" : AppFormatters.idr(modal))")
                                            .font(.mali(12))
                                            .foregroundColor(.orange)
                                        
                                        if !isManualOrTroll {
                                            Text("Fee Admin: \(hideFinancials ? "••••" : AppFormatters.idr(fee))")
                                                .font(.mali(12))
                                                .foregroundColor(.yellow)
                                        }
                                            
                                        Text("Keuntungan: \(hideFinancials ? "••••" : AppFormatters.idr(keuntunganBersih))")
                                            .font(.mali(15))
                                            .foregroundColor(.green)
                                            .padding(.top, 3)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 5) {
                                        Text("Omset: \(hideFinancials ? "••••" : AppFormatters.idr(omset))")
                                            .font(.mali(13))
                                            .foregroundColor(.cyan)
                                        
                                        if piutang > 0 {
                                            Text("Piutang DP: \(hideFinancials ? "••••" : AppFormatters.idr(piutang))")
                                                .font(.mali(11))
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                VStack(spacing: 5) {
                                    HStack {
                                        Text("ANGGOTA KLOTER (Ketuk untuk Edit Cicilan/Data)")
                                            .font(.mali(10))
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                    .padding(.bottom, 2)

                                    ForEach(bItems, id: \.id) { item in
                                        Button {
                                            dismiss()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                onEditItem(item)
                                            }
                                        } label: {
                                            HStack(alignment: .center) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "pencil.circle")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.cyan)
                                                    Text(item.displayName)
                                                        .font(.mali(12))
                                                        .foregroundColor(.white.opacity(0.9))
                                                        .lineLimit(1)
                                                    
                                                    if item.currentSourceType == .trollstore {
                                                        Text("TS")
                                                            .font(.mali(8))
                                                            .foregroundColor(.green)
                                                            .padding(.horizontal, 4)
                                                            .background(Color.green.opacity(0.15))
                                                            .cornerRadius(3)
                                                    }
                                                }
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text(hideFinancials ? "••••" : AppFormatters.idr(item.hargaJual))
                                                        .font(.mali(12))
                                                        .foregroundColor(.cyan.opacity(0.85))
                                                    
                                                    if !item.isLunas {
                                                        Text("Kurang \(hideFinancials ? "••••" : AppFormatters.idr(item.sisaPembayaran)) ✏️")
                                                            .font(.mali(10))
                                                            .padding(.horizontal, 5)
                                                            .padding(.vertical, 1)
                                                            .background(Color.red.opacity(0.2))
                                                            .foregroundColor(.red)
                                                            .cornerRadius(4)
                                                    } else {
                                                        Text("Lunas ✅")
                                                            .font(.mali(10))
                                                            .foregroundColor(.green.opacity(0.8))
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 6)
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(10)
                                .background(Color.black.opacity(0.25))
                                .cornerRadius(10)
                                .padding(.top, 4)
                            }
                            .padding(12)
                            .liquidGlass(cornerRadius: 14)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 10)
                    .id(forceRefresh)
                }
            }
            .navigationTitle("Arsip Kloter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tutup") { dismiss() }.font(.mali(14)).foregroundColor(.cyan)
                }
            }
            .sheet(item: $batchToEdit) { eb in
                EditBatchModalSheet(
                    batchNumber: eb.id,
                    currentModal: BatchModalManager.shared.getModal(for: eb.id),
                    currentAdminFee: BatchAdminFeeManager.shared.getFee(for: eb.id)
                ) { updatedModal, updatedFee in
                    BatchModalManager.shared.setModal(for: eb.id, modal: updatedModal)
                    BatchAdminFeeManager.shared.setFee(for: eb.id, fee: updatedFee)
                    forceRefresh = UUID()
                }
            }
        }
    }
}
