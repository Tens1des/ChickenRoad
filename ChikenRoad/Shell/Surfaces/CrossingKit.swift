import SwiftUI
import UIKit

/// Палитра серых экранов. Тона сняты с оформления игры — тёплое дерево, золото
/// и жёлток, — но живут отдельными значениями: серый слой не должен ломаться от
/// правки внутренних стилей белой части.
enum CrossingPalette {
    static let ground = Color(red: 0.098, green: 0.052, blue: 0.024)
    static let panelTop = Color(red: 0.196, green: 0.112, blue: 0.052)
    static let panelBottom = Color(red: 0.082, green: 0.042, blue: 0.020)
    static let lane = Color(red: 0.980, green: 0.760, blue: 0.240)
    static let corn = Color(red: 1.000, green: 0.900, blue: 0.380)
    static let ember = Color(red: 0.965, green: 0.520, blue: 0.110)
    static let headline = Color(red: 1.000, green: 0.996, blue: 0.972)
    static let body = Color(red: 0.972, green: 0.945, blue: 0.878)
    static let onLane = Color(red: 0.196, green: 0.092, blue: 0.024)
}

/// Что известно о доступном месте на момент отрисовки.
struct CrossingLayout {
    let isLandscape: Bool
    /// Горизонталь, на которой хватает ширины развести текст и кнопки по
    /// колонкам. На крупном Dynamic Type колонки выключаются: текст важнее.
    let usesSideBySideContent: Bool
    let isAccessibilityLayout: Bool
}

/// Общий каркас трёх серых экранов.
///
/// Раскладка снята с референсов заказчика и одинакова для всех состояний:
/// вордмарк сверху по центру, фокусный объект сцены в середине кадра остаётся
/// открытым, живое содержимое прижато к низу в портрете и стоит сразу под
/// вордмарком в горизонтали, оставляя нижнюю полосу под сцену.
struct CrossingScaffold<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let contentMaxWidth: CGFloat
    private let content: (CrossingLayout) -> Content

    init(
        contentMaxWidth: CGFloat = 520,
        @ViewBuilder content: @escaping (CrossingLayout) -> Content
    ) {
        self.contentMaxWidth = contentMaxWidth
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            // Ориентацию решает соотношение сторон контейнера, а не
            // `UIDevice.orientation`: последнее врёт при заблокированном
            // повороте и на iPad в split view.
            let isLandscape = proxy.size.width > proxy.size.height
            let isAccessibilityLayout = dynamicTypeSize.isAccessibilitySize
            let usesSideBySideContent = isLandscape
                && !isAccessibilityLayout
                && proxy.size.width >= 700
            let layout = CrossingLayout(
                isLandscape: isLandscape,
                usesSideBySideContent: usesSideBySideContent,
                isAccessibilityLayout: isAccessibilityLayout
            )

            // Отступы держат текст в стороне от выреза камеры при любой
            // ориентации. Значения по краям не выводятся из `safeAreaInsets`:
            // они приходят нулевыми на повёрнутом холсте превью и на сцене,
            // которая игнорирует safe area, — и тогда заголовок уезжает под
            // остров. Реальная вставка устройства, если она больше, побеждает.
            let sideInset: CGFloat = isLandscape ? 64 : 26
            let topInset: CGFloat = isLandscape ? 28 : 64
            let insets = EdgeInsets(
                top: max(topInset, proxy.safeAreaInsets.top),
                leading: max(sideInset, proxy.safeAreaInsets.leading),
                bottom: max(isLandscape ? 24 : 40, proxy.safeAreaInsets.bottom),
                trailing: max(sideInset, proxy.safeAreaInsets.trailing)
            )
            // Ширина считается один раз и до отрисовки: если предложить
            // содержимому бесконечность и обрезать его снаружи, длинный
            // заголовок уедет за край многоточием вместо переноса.
            let availableWidth = max(proxy.size.width - insets.leading - insets.trailing, 240)
            let resolvedWidth = usesSideBySideContent
                ? min(availableWidth, 900)
                : min(availableWidth, contentMaxWidth)
            // Горизонталь оставляет нижнюю полосу сцене: содержимое стоит между
            // вордмарком и этой полосой, а не по геометрическому центру, где
            // стоит герой.
            let sceneReserve: CGFloat = isLandscape ? proxy.size.height * 0.10 : 0

            ZStack {
                CrossingBackdrop(isLandscape: isLandscape)

                ScrollView {
                    VStack(spacing: 0) {
                        CrossingWordmark(compact: isAccessibilityLayout || isLandscape)

                        Spacer(minLength: isLandscape ? 16 : 28)

                        content(layout)
                            .frame(width: resolvedWidth)

                        if sceneReserve > 0 {
                            Spacer(minLength: 8)
                            Color.clear.frame(height: sceneReserve)
                        }
                    }
                    .padding(insets)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Фон под экранами: мастер по теме игры, свой на каждую ориентацию.
///
/// Затемнение локальное, а не сплошное: в портрете тянет вниз, под текст и
/// кнопки, в горизонтали — к левому и правому краю, под колонки. Середина
/// кадра остаётся открытой, иначе подложка спрячет тот самый арт, ради
/// которого всё делалось.
private struct CrossingBackdrop: View {
    let isLandscape: Bool

    private var artworkName: String {
        isLandscape ? "CrossingBackdropLandscape" : "CrossingBackdropPortrait"
    }

    var body: some View {
        ZStack {
            CrossingPalette.ground

            if UIImage(named: artworkName) != nil {
                // Кадр задаётся явной геометрией, а не `maxWidth/maxHeight:
                // .infinity`. С бесконечными границами `scaledToFill` считает
                // масштаб по предложенному размеру раньше, чем известен кадр, и
                // обрезка выходит несимметричной: герой уезжает вбок от
                // UI-колонки, которая стоит строго по центру.
                GeometryReader { proxy in
                    Image(artworkName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                        .clipped()
                }
            } else {
                LinearGradient(
                    colors: [
                        CrossingPalette.panelTop,
                        CrossingPalette.ground,
                        CrossingPalette.panelBottom
                    ],
                    startPoint: isLandscape ? .leading : .top,
                    endPoint: isLandscape ? .trailing : .bottom
                )
            }

            if isLandscape {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.42), location: 0.00),
                        .init(color: .black.opacity(0.10), location: 0.26),
                        .init(color: .clear, location: 0.50),
                        .init(color: .black.opacity(0.10), location: 0.74),
                        .init(color: .black.opacity(0.42), location: 1.00)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.10), location: 0.00),
                        .init(color: .clear, location: 0.34),
                        .init(color: .black.opacity(0.22), location: 0.68),
                        .init(color: .black.opacity(0.46), location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Плотный тёмный контур вокруг светлого текста. Держит читаемость прямо на
/// арте — и на дневном небе, и на асфальте, — не пряча кадр под подложкой.
struct CrossingInkOutline: ViewModifier {
    var radius: CGFloat = 1.2
    var glow: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.92), radius: radius, x: 0, y: 0)
            .shadow(color: .black.opacity(0.86), radius: radius, x: 0, y: 0)
            .shadow(color: .black.opacity(0.62), radius: radius * 2.4, x: 0, y: 2)
            .shadow(color: .black.opacity(0.42), radius: glow, x: 0, y: 5)
    }
}

extension View {
    func crossingInkOutline(radius: CGFloat = 1.2, glow: CGFloat = 12) -> some View {
        modifier(CrossingInkOutline(radius: radius, glow: glow))
    }
}

/// Вордмарк приложения. Рисуется текстом: логотипа игры в её ассетах нет, а
/// генератору арта надписи не доверяются — он их перевирает.
struct CrossingWordmark: View {
    let compact: Bool

    var body: some View {
        Text("HEN PATH")
            .font(compact ? .system(size: 34, weight: .black) : .system(size: 44, weight: .black))
            .fontDesign(.rounded)
            .fontWidth(.expanded)
            .tracking(1.6)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.white,
                        CrossingPalette.corn,
                        CrossingPalette.lane,
                        CrossingPalette.ember
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .crossingInkOutline(radius: 1.8, glow: 16)
            .accessibilityLabel("Hen Path")
            .accessibilityAddTraits(.isHeader)
    }
}

/// Заголовок состояния: прописной, узкий, светлый, с контуром — типографика
/// референсов.
struct CrossingHeadline: View {
    let text: String
    var compact = false

    var body: some View {
        Text(text)
            .font(compact ? .title3.weight(.heavy) : .title.weight(.heavy))
            .fontDesign(.rounded)
            .fontWidth(.condensed)
            .tracking(0.8)
            .foregroundStyle(CrossingPalette.headline)
            // Длинный заголовок обязан переноситься, а не обрезаться
            // многоточием: тексты состояний приходят из ТЗ целиком.
            .fixedSize(horizontal: false, vertical: true)
            .crossingInkOutline()
    }
}

/// Пояснение под заголовком.
struct CrossingBodyText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .foregroundStyle(CrossingPalette.body)
            .fixedSize(horizontal: false, vertical: true)
            .crossingInkOutline(radius: 0.9, glow: 8)
    }
}

struct CrossingBadge: View {
    @ScaledMetric(relativeTo: .title2) private var scaledGlyphSize = 31.0
    @ScaledMetric(relativeTo: .body) private var scaledBadgeSize = 72.0

    let systemName: String
    let accessibilityLabel: String
    var compact = false

    var body: some View {
        let badgeSize = min(scaledBadgeSize * (compact ? 0.82 : 1), 104)
        let glyphSize = min(scaledGlyphSize * (compact ? 0.86 : 1), 48)

        Image(systemName: systemName)
            .font(.system(size: glyphSize, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [CrossingPalette.corn, CrossingPalette.ember],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: badgeSize, height: badgeSize)
            .background(
                Circle()
                    .fill(CrossingPalette.panelBottom.opacity(0.88))
            )
            .overlay {
                Circle()
                    .stroke(CrossingPalette.lane.opacity(0.88), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
            .accessibilityLabel(accessibilityLabel)
    }
}

/// Основная кнопка: жёлто-оранжевая заливка игры, тёмный текст поверх неё.
struct CrossingPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .fontDesign(.rounded)
            .foregroundStyle(CrossingPalette.onLane)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                LinearGradient(
                    colors: [CrossingPalette.corn, CrossingPalette.lane, CrossingPalette.ember],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(isEnabled ? 1 : 0.46),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(CrossingPalette.onLane.opacity(0.85), lineWidth: 2.5)
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
                    .padding(2.5)
            }
            .shadow(color: .black.opacity(0.45), radius: configuration.isPressed ? 5 : 12, y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
            .contentShape(Capsule(style: .continuous))
    }
}

/// Вторичная кнопка: мельче и только контуром — как в референсах.
struct CrossingSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .fontDesign(.rounded)
            .foregroundStyle(CrossingPalette.headline)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                Capsule(style: .continuous)
                    .fill(.black.opacity(configuration.isPressed ? 0.55 : 0.38))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(CrossingPalette.headline.opacity(0.85), lineWidth: 1.8)
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
            .contentShape(Capsule(style: .continuous))
    }
}

/// Ссылка на Privacy Policy под кнопками экрана уведомлений.
struct CrossingPolicyLink: View {
    let destination: URL

    var body: some View {
        Link("Privacy Policy", destination: destination)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(CrossingPalette.headline)
            .underline()
            .crossingInkOutline(radius: 0.8, glow: 6)
            .accessibilityHint("Opens the privacy policy")
    }
}
