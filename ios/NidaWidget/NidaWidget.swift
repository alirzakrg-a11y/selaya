import WidgetKit
import SwiftUI

// MARK: - Theme

private let gold = Color(red: 0.88, green: 0.71, blue: 0.34)
private let nidaBgColor = Color(red: 0.03, green: 0.05, blue: 0.10)
private let dimColor = Color.white.opacity(0.6)
private let appGroup = "group.com.nida.nida"

extension View {
    /// Home-widget container background (iOS 17 API + pre-17 fallback).
    @ViewBuilder func nidaContainer() -> some View {
        if #available(iOS 17.0, *) {
            self.padding(14).containerBackground(for: .widget) { nidaBgColor }
        } else {
            self.padding(14).background(nidaBgColor)
        }
    }
}

// ============================================================ HADİS

private struct Hadith { let text: String; let ref: String }

private let hadiths: [Hadith] = [
    Hadith(text: "Ameller ancak niyetlere göredir.", ref: "Buhârî & Müslim"),
    Hadith(text: "Sizden biri, kendisi için istediğini kardeşi için de istemedikçe iman etmiş olmaz.", ref: "Buhârî & Müslim"),
    Hadith(text: "Kişinin kendisini ilgilendirmeyen şeyleri terk etmesi, Müslümanlığının güzelliğindendir.", ref: "Tirmizî"),
    Hadith(text: "Müslüman, dilinden ve elinden diğer Müslümanların güvende olduğu kimsedir.", ref: "Buhârî"),
    Hadith(text: "Temizlik imanın yarısıdır.", ref: "Müslim"),
    Hadith(text: "Nerede olursan ol Allah'tan kork; kötülüğün ardından iyilik yap ki onu silsin.", ref: "Tirmizî"),
    Hadith(text: "Kim Allah'a ve ahiret gününe iman ediyorsa ya hayır söylesin ya da sussun.", ref: "Buhârî"),
    Hadith(text: "Müminlerin iman bakımından en olgunu, ahlâkı en güzel olanıdır.", ref: "Tirmizî"),
    Hadith(text: "Kim bir mümini bir sıkıntıdan kurtarırsa, Allah da onu kıyamet sıkıntılarından kurtarır.", ref: "Müslim"),
    Hadith(text: "Allah'a amellerin en sevimlisi, az da olsa devamlı olanıdır.", ref: "Buhârî"),
    Hadith(text: "Her âdemoğlu hata eder; hata edenlerin en hayırlısı tövbe edenlerdir.", ref: "Tirmizî"),
    Hadith(text: "Rabbini zikreden ile zikretmeyenin durumu, diri ile ölünün durumu gibidir.", ref: "Buhârî"),
]

struct HadithEntry: TimelineEntry { let date: Date; let text: String; let ref: String }

struct HadithProvider: TimelineProvider {
    func placeholder(in context: Context) -> HadithEntry {
        HadithEntry(date: Date(), text: hadiths[0].text, ref: hadiths[0].ref)
    }
    func getSnapshot(in context: Context, completion: @escaping (HadithEntry) -> Void) {
        let h = hadiths[dayIndex() % hadiths.count]
        completion(HadithEntry(date: Date(), text: h.text, ref: h.ref))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HadithEntry>) -> Void) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        var entries: [HadithEntry] = []
        for i in 0..<5 {
            let date = cal.date(byAdding: .day, value: i, to: start)!
            let h = hadiths[(dayIndex(date) ) % hadiths.count]
            entries.append(HadithEntry(date: date, text: h.text, ref: h.ref))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct HadithEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: HadithEntry
    var body: some View {
        switch family {
        case .accessoryInline: Text(entry.text)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("GÜNÜN HADİSİ").font(.system(size: 10, weight: .bold))
                Text(entry.text).font(.system(size: 12)).lineLimit(3)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text("Günün Hadisi").font(.system(size: 12, weight: .bold)).foregroundColor(gold)
                Text(entry.text).font(.system(size: family == .systemSmall ? 12 : 15, weight: .medium))
                    .foregroundColor(.white).lineLimit(5).minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                HStack {
                    Text(entry.ref).font(.system(size: 10)).foregroundColor(dimColor).lineLimit(1)
                    Spacer()
                    Text("NIDA").font(.system(size: 12, weight: .heavy)).foregroundColor(gold)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct HadithWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NidaWidget", provider: HadithProvider()) { entry in
            HadithEntryView(entry: entry).nidaContainer()
        }
        .configurationDisplayName("NIDA — Günün Hadisi")
        .description("Her gün bir hadis-i şerif")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// ============================================================ AYET

struct Ayah { let ar: String; let mn: String; let rf: String }

private let ayahs: [Ayah] = [
    Ayah(ar: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ", mn: "Rahmân ve Rahîm olan Allah'ın adıyla.", rf: "Fâtiha 1"),
    Ayah(ar: "إِنَّ مَعَ الْعُسْرِ يُسْرًا", mn: "Muhakkak ki, zorlukla beraber bir kolaylık vardır.", rf: "İnşirah 6"),
    Ayah(ar: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ", mn: "Bilesiniz ki kalpler ancak Allah'ı anmakla huzur bulur.", rf: "Ra'd 28"),
    Ayah(ar: "فَاذْكُرُونِي أَذْكُرْكُمْ", mn: "Öyleyse yalnız beni anın ki ben de sizi anayım.", rf: "Bakara 152"),
    Ayah(ar: "وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ", mn: "Kim Allah'a tevekkül ederse, O ona yeter.", rf: "Talâk 3"),
    Ayah(ar: "ادْعُونِي أَسْتَجِبْ لَكُمْ", mn: "Bana dua edin, size karşılık vereyim.", rf: "Mü'min 60"),
    Ayah(ar: "قُلْ هُوَ اللَّهُ أَحَدٌ", mn: "De ki: O, Allah'tır, bir tektir.", rf: "İhlâs 1"),
    Ayah(ar: "وَلَلْآخِرَةُ خَيْرٌ لَّكَ مِنَ الْأُولَىٰ", mn: "Elbette ahiret senin için dünyadan daha hayırlıdır.", rf: "Duhâ 4"),
]

struct AyahEntry: TimelineEntry { let date: Date; let ayah: Ayah }

struct AyahProvider: TimelineProvider {
    func placeholder(in context: Context) -> AyahEntry { AyahEntry(date: Date(), ayah: ayahs[0]) }
    func getSnapshot(in context: Context, completion: @escaping (AyahEntry) -> Void) {
        completion(AyahEntry(date: Date(), ayah: ayahs[rotIndex() % ayahs.count]))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AyahEntry>) -> Void) {
        completion(rotatingTimeline(ayahs) { AyahEntry(date: $0, ayah: $1) })
    }
}

struct AyahEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: AyahEntry
    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.ayah.mn).font(.system(size: 12)).lineLimit(2)
                Text(entry.ayah.rf).font(.system(size: 10, weight: .bold))
            }
        case .accessoryInline: Text(entry.ayah.rf)
        default:
            VStack(alignment: .leading, spacing: 5) {
                Text("GÜNÜN AYETİ").font(.system(size: 11, weight: .bold)).foregroundColor(gold)
                Text(entry.ayah.ar).font(.system(size: family == .systemSmall ? 16 : 19))
                    .foregroundColor(.white).lineLimit(2).minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .trailing).environment(\.layoutDirection, .rightToLeft)
                Text(entry.ayah.mn).font(.system(size: family == .systemSmall ? 11 : 13))
                    .foregroundColor(.white.opacity(0.85)).lineLimit(3)
                Spacer(minLength: 2)
                Text(entry.ayah.rf).font(.system(size: 10, weight: .bold)).foregroundColor(gold)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct AyahWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NidaAyahWidget", provider: AyahProvider()) { entry in
            AyahEntryView(entry: entry).nidaContainer()
        }
        .configurationDisplayName("NIDA — Günün Ayeti")
        .description("Kur'an-ı Kerim'den bir ayet")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// ============================================================ ESMAÜL HÜSNA

struct Esma { let ar: String; let tr: String; let mn: String }

private let esmaList: [Esma] = [
    Esma(ar: "الرَّحْمَٰن", tr: "Ar-Rahman", mn: "Dünyada bütün mahlûkatına merhamet eden."),
    Esma(ar: "الرَّحِيم", tr: "Ar-Rahim", mn: "Ahirette müminlere merhamet eden."),
    Esma(ar: "الْمَلِك", tr: "Al-Malik", mn: "Mülkün ve her şeyin sahibi."),
    Esma(ar: "الْقُدُّوس", tr: "Al-Quddus", mn: "Her türlü eksiklikten münezzeh olan."),
    Esma(ar: "السَّلَام", tr: "As-Salam", mn: "Kullarını selâmete çıkaran, esenlik veren."),
    Esma(ar: "الْمُؤْمِن", tr: "Al-Mu'min", mn: "Güven veren, emin kılan."),
    Esma(ar: "الْعَزِيز", tr: "Al-Aziz", mn: "İzzet sahibi, mağlup edilemeyen."),
    Esma(ar: "الْغَفَّار", tr: "Al-Ghaffar", mn: "Günahları örten, çok bağışlayan."),
    Esma(ar: "الْوَهَّاب", tr: "Al-Wahhab", mn: "Karşılıksız çokça veren."),
    Esma(ar: "الرَّزَّاق", tr: "Ar-Razzaq", mn: "Bütün canlıların rızkını veren."),
    Esma(ar: "الْحَكِيم", tr: "Al-Hakim", mn: "Her işi hikmetli, mutlak hüküm sahibi."),
    Esma(ar: "الْوَدُود", tr: "Al-Wadud", mn: "Kullarını çok seven, sevilmeye lâyık olan."),
]

struct EsmaEntry: TimelineEntry { let date: Date; let esma: Esma }

struct EsmaProvider: TimelineProvider {
    func placeholder(in context: Context) -> EsmaEntry { EsmaEntry(date: Date(), esma: esmaList[0]) }
    func getSnapshot(in context: Context, completion: @escaping (EsmaEntry) -> Void) {
        completion(EsmaEntry(date: Date(), esma: esmaList[rotIndex() % esmaList.count]))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<EsmaEntry>) -> Void) {
        completion(rotatingTimeline(esmaList) { EsmaEntry(date: $0, esma: $1) })
    }
}

struct EsmaEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: EsmaEntry
    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.esma.tr).font(.system(size: 13, weight: .bold))
                Text(entry.esma.mn).font(.system(size: 11)).lineLimit(2)
            }
        case .accessoryInline: Text(entry.esma.tr)
        default:
            VStack(alignment: .center, spacing: 4) {
                Text("ESMAÜL HÜSNA").font(.system(size: 10, weight: .bold)).foregroundColor(gold)
                Text(entry.esma.ar).font(.system(size: 28)).foregroundColor(gold).lineLimit(1).minimumScaleFactor(0.6)
                Text(entry.esma.tr).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Text(entry.esma.mn).font(.system(size: 11)).foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center).lineLimit(family == .systemSmall ? 2 : 3)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct EsmaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NidaEsmaWidget", provider: EsmaProvider()) { entry in
            EsmaEntryView(entry: entry).nidaContainer()
        }
        .configurationDisplayName("NIDA — Esmaül Hüsna")
        .description("Allah'ın güzel isimleri")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// ============================================================ HİCRİ TARİH

struct HijriEntry: TimelineEntry { let date: Date; let hijri: String; let greg: String }

private func hijriString(_ date: Date) -> String {
    var cal = Calendar(identifier: .islamicUmmAlQura)
    cal.locale = Locale(identifier: "tr")
    let df = DateFormatter()
    df.calendar = cal
    df.locale = Locale(identifier: "tr")
    df.dateFormat = "d MMMM yyyy"
    return df.string(from: date)
}
private func gregString(_ date: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "tr")
    df.dateFormat = "d MMMM yyyy, EEEE"
    return df.string(from: date)
}

/// Prefer the date the app pushed to the App Group (its `hijri` package + the
/// user's manual offset) so the widget matches the app exactly; fall back to the
/// native Umm al-Qura calendar only until the app has written once.
private func hijriEntry() -> HijriEntry {
    let ud = UserDefaults(suiteName: appGroup)
    let hijri = ud?.string(forKey: "hijri_date") ?? hijriString(Date())
    let greg = ud?.string(forKey: "hijri_greg") ?? gregString(Date())
    return HijriEntry(date: Date(), hijri: hijri, greg: greg)
}

struct HijriProvider: TimelineProvider {
    func placeholder(in context: Context) -> HijriEntry { hijriEntry() }
    func getSnapshot(in context: Context, completion: @escaping (HijriEntry) -> Void) {
        completion(hijriEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HijriEntry>) -> Void) {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        completion(Timeline(entries: [hijriEntry()], policy: .after(tomorrow)))
    }
}

struct HijriEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: HijriEntry
    var body: some View {
        switch family {
        case .accessoryInline: Text(entry.hijri)
        case .accessoryCircular:
            VStack(spacing: 0) { Text("☪").font(.system(size: 14)); Text(entry.hijri.components(separatedBy: " ").first ?? "").font(.system(size: 16, weight: .bold)) }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("HİCRİ").font(.system(size: 10, weight: .bold))
                Text(entry.hijri).font(.system(size: 14, weight: .bold))
                Text(entry.greg).font(.system(size: 10)).lineLimit(1)
            }
        case .systemMedium:
            // Wide + short layout (the user's "yatay tam, dikey kısa").
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HİCRİ TAKVİM").font(.system(size: 10, weight: .bold)).foregroundColor(gold)
                    Text(entry.hijri).font(.system(size: 22, weight: .bold)).foregroundColor(.white).minimumScaleFactor(0.7)
                }
                Spacer()
                Text(entry.greg).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.trailing)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            VStack(spacing: 4) {
                Text("HİCRİ TAKVİM").font(.system(size: 10, weight: .bold)).foregroundColor(gold)
                Text(entry.hijri).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    .multilineTextAlignment(.center).minimumScaleFactor(0.7)
                Text(entry.greg).font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct HijriWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NidaHijriWidget", provider: HijriProvider()) { entry in
            HijriEntryView(entry: entry).nidaContainer()
        }
        .configurationDisplayName("NIDA — Hicri Tarih")
        .description("Bugünün hicri ve miladi tarihi")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

// ============================================================ NAMAZ VAKİTLERİ (App Group)

struct PrayerTime { let name: String; let time: String }

struct PrayerEntry: TimelineEntry {
    let date: Date
    let city: String
    let times: [PrayerTime]
}

private func loadPrayerTimes() -> (city: String, times: [PrayerTime]) {
    guard let ud = UserDefaults(suiteName: appGroup),
          let json = ud.string(forKey: "prayer_times"),
          let data = json.data(using: .utf8),
          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return ("", []) }
    let city = ud.string(forKey: "prayer_city") ?? ""
    let times = arr.compactMap { o -> PrayerTime? in
        guard let n = o["n"] as? String, let t = o["t"] as? String else { return nil }
        return PrayerTime(name: n, time: t)
    }
    return (city, times)
}

/// Index of the next upcoming prayer (in the day's six), or 0 if all passed.
private func nextPrayerIndex(_ times: [PrayerTime], now: Date) -> Int {
    let cal = Calendar.current
    let today = cal.startOfDay(for: now)
    let df = DateFormatter(); df.dateFormat = "HH:mm"; df.locale = Locale(identifier: "tr")
    for (i, p) in times.enumerated() {
        if let parsed = df.date(from: p.time) {
            let c = cal.dateComponents([.hour, .minute], from: parsed)
            if let full = cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: today), full > now {
                return i
            }
        }
    }
    return 0
}

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), city: "—", times: [
            PrayerTime(name: "İmsak", time: "03:31"), PrayerTime(name: "Güneş", time: "05:12"),
            PrayerTime(name: "Öğle", time: "12:38"), PrayerTime(name: "İkindi", time: "16:28"),
            PrayerTime(name: "Akşam", time: "19:55"), PrayerTime(name: "Yatsı", time: "21:26"),
        ])
    }
    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        let (city, times) = loadPrayerTimes()
        completion(PrayerEntry(date: Date(), city: city, times: times.isEmpty ? placeholder(in: context).times : times))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let (city, loaded) = loadPrayerTimes()
        let times = loaded.isEmpty ? placeholder(in: context).times : loaded
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let df = DateFormatter(); df.dateFormat = "HH:mm"; df.locale = Locale(identifier: "tr")

        // Refresh at "now" and at each remaining prayer time today, so the
        // highlighted "next" stays correct as prayers pass.
        var dates: [Date] = [now]
        for p in times {
            if let parsed = df.date(from: p.time) {
                let c = cal.dateComponents([.hour, .minute], from: parsed)
                if let full = cal.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: today), full > now {
                    dates.append(full)
                }
            }
        }
        dates.append(cal.date(byAdding: .hour, value: 1, to: now)!)
        let entries = Array(Set(dates)).sorted().map { PrayerEntry(date: $0, city: city, times: times) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct PrayerEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: PrayerEntry

    private var nextIdx: Int { nextPrayerIndex(entry.times, now: entry.date) }
    private var nextLabel: String {
        guard !entry.times.isEmpty else { return "—" }
        let p = entry.times[nextIdx]; return "\(p.name) \(p.time)"
    }

    var body: some View {
        switch family {
        case .accessoryInline: Text(nextLabel)
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(entry.times.isEmpty ? "" : entry.times[nextIdx].name).font(.system(size: 11, weight: .bold))
                Text(entry.times.isEmpty ? "" : entry.times[nextIdx].time).font(.system(size: 13, weight: .bold))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("SIRADAKİ VAKİT").font(.system(size: 10, weight: .bold))
                Text(nextLabel).font(.system(size: 16, weight: .bold))
                if !entry.city.isEmpty { Text(entry.city).font(.system(size: 11)) }
            }
        case .systemSmall:
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.city.isEmpty ? "Namaz" : entry.city).font(.system(size: 11, weight: .bold)).foregroundColor(gold).lineLimit(1)
                Spacer(minLength: 0)
                Text(entry.times.isEmpty ? "—" : entry.times[nextIdx].name).font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                Text(entry.times.isEmpty ? "" : entry.times[nextIdx].time).font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        default:
            VStack(spacing: 6) {
                HStack {
                    Text(entry.city.isEmpty ? "Namaz Vakitleri" : entry.city).font(.system(size: 11, weight: .bold)).foregroundColor(gold).lineLimit(1)
                    Spacer()
                    Text("NIDA").font(.system(size: 11, weight: .heavy)).foregroundColor(gold)
                }
                let cols = Array(repeating: GridItem(.flexible()), count: 3)
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(Array(entry.times.enumerated()), id: \.offset) { i, p in
                        VStack(spacing: 1) {
                            Text(p.name).font(.system(size: 10)).foregroundColor(i == nextIdx ? gold : .white.opacity(0.6))
                            Text(p.time).font(.system(size: 15, weight: .bold)).foregroundColor(i == nextIdx ? gold : .white)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct PrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NidaPrayerWidget", provider: PrayerProvider()) { entry in
            PrayerEntryView(entry: entry).nidaContainer()
        }
        .configurationDisplayName("NIDA — Namaz Vakitleri")
        .description("Namaz vakitleri ve sıradaki vakit")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

// ============================================================ Helpers + Bundle

/// A day-stable index so the daily content varies by date.
private func dayIndex(_ date: Date = Date()) -> Int {
    Int(date.timeIntervalSince1970 / 86400)
}
/// Rotates through the day (changes every ~2h) so the widget isn't static.
private func rotIndex(_ date: Date = Date()) -> Int {
    let h = Calendar.current.component(.hour, from: date)
    return dayIndex(date) + h / 2
}

/// Builds a timeline that steps through [list] every 2 hours for 24h.
private func rotatingTimeline<T, E: TimelineEntry>(_ list: [T], _ make: (Date, T) -> E) -> Timeline<E> {
    let cal = Calendar.current
    let now = Date()
    let base = rotIndex(now)
    var entries: [E] = []
    for i in 0..<12 {
        let date = cal.date(byAdding: .hour, value: i * 2, to: now)!
        entries.append(make(date, list[(base + i) % list.count]))
    }
    return Timeline(entries: entries, policy: .atEnd)
}

@main
struct NidaWidgets: WidgetBundle {
    var body: some Widget {
        HadithWidget()
        PrayerWidget()
        AyahWidget()
        EsmaWidget()
        HijriWidget()
    }
}
