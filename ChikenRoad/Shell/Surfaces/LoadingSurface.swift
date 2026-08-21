import SwiftUI

/// Экран загрузки. Индикатор анимированный — и уважает «уменьшение движения»:
/// при включённом флаге вращение и пульсация выключаются, экран остаётся живым
/// по содержанию, а не по движению.
struct LoadingSurface: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .title2) private var scaledIndicatorSize = 96.0
    @State private var isAnimating = false

    init() {}

    var body: some View {
        CrossingScaffold(contentMaxWidth: 480) { layout in
            // Обе раскладки — один и тот же элемент дерева: `AnyLayout` меняет
            // расстановку, не трогая идентичность. Прежний `if/else` на повороте
            // подменял ветку, слой ронял `CAAnimation`, и вращение вставало —
            // навсегда, потому что перезапускать его было некому.
            let stack = layout.usesSideBySideContent
                ? AnyLayout(HStackLayout(spacing: 24))
                : AnyLayout(VStackLayout(spacing: 24))

            stack {
                indicator
                copy(alignment: layout.usesSideBySideContent ? .leading : .center)
            }
        }
        .onAppear(perform: restartAnimation)
        .onChange(of: reduceMotion) { _, _ in restartAnimation() }
        .onChange(of: scenePhase) { _, phase in
            // Возврат из фона, системный алерт, баннер пуша — любой из них может
            // снять анимацию со слоя. Страховка на случай, если идентичности
            // окажется мало.
            if phase == .active { restartAnimation() }
        }
    }

    /// Золотое яйцо в кольце — знак самой игры, а не системный спиннер.
    private var indicator: some View {
        let size = min(scaledIndicatorSize, 122)

        return ZStack {
            Circle()
                .fill(.black.opacity(0.42))

            Circle()
                .trim(from: 0.08, to: 0.82)
                .stroke(
                    AngularGradient(
                        colors: [
                            CrossingPalette.lane.opacity(0.20),
                            CrossingPalette.corn,
                            CrossingPalette.ember
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .padding(size * 0.10)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                // Вращение объявлено здесь, а не запущено императивно из
                // `onAppear`. Раскладка меняется на повороте (колонка ↔ строка),
                // `onAppear` срабатывает заново, и перезапуск `repeatForever`
                // через `withAnimation` приходился ровно на системный переход
                // ориентации — экран вставал намертво.
                .animation(
                    reduceMotion ? nil : .linear(duration: 1.15).repeatForever(autoreverses: false),
                    value: isAnimating
                )

            goldenEgg(width: size * 0.30)
                .scaleEffect(isAnimating && !reduceMotion ? 1.06 : 1)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.85).repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.55), radius: 16, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
        .accessibilityHint("Preparing your experience")
    }

    private func goldenEgg(width: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [CrossingPalette.corn, CrossingPalette.lane, CrossingPalette.ember],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Ellipse().stroke(.white.opacity(0.42), lineWidth: 1)
                }

            Ellipse()
                .fill(.white.opacity(0.55))
                .frame(width: width * 0.26, height: width * 0.36)
                .offset(x: -width * 0.16, y: -width * 0.30)
                .blur(radius: 1.5)
        }
        .frame(width: width, height: width * 1.34)
        .shadow(color: CrossingPalette.ember.opacity(0.55), radius: 10)
    }

    private func copy(alignment: TextAlignment) -> some View {
        VStack(alignment: alignment == .leading ? .leading : .center, spacing: 8) {
            CrossingHeadline(text: "LOADING...")
        }
        .multilineTextAlignment(alignment)
        .accessibilityElement(children: .combine)
    }

    /// Перевзводит флаг, а не «включает, если выключено».
    ///
    /// Анимации объявлены на самих элементах и подхватывают флаг сами, но
    /// подхватывают только его ИЗМЕНЕНИЕ. Проверка «уже включено» делала любую
    /// остановку окончательной: слетевшую со слоя анимацию нечем было вернуть,
    /// и экран замирал до конца сессии — и кольцо, и пульсация яйца разом,
    /// потому что флаг у них общий.
    private func restartAnimation() {
        guard !reduceMotion else {
            isAnimating = false
            return
        }

        isAnimating = false
        // Следующим тактом: без смены значения объявленная анимация не
        // перезапустится, а в одном проходе false и true схлопнутся.
        DispatchQueue.main.async {
            isAnimating = true
        }
    }
}
