import UIKit

/// Кто и в каких ориентациях живёт.
///
/// В `Info.plist` объявлены все четыре: резать список там нельзя, иначе витрина
/// не повернётся. Сужает их приложение — здесь, по тому, что сейчас на экране.
///
/// Игра остаётся портретной ровно такой, какой её сдали, и ни одного флага
/// режима внутри себя не получает: решение принимается снаружи, слоем.
enum ShellOrientationPolicy {
    /// Белая часть сдана портретной (`INTAKE.md`, шаг 1).
    static let gameOrientations: UIInterfaceOrientationMask = .portrait

    /// Шесть кастомных экранов и витрина рисуются в обеих ориентациях.
    ///
    /// Ровно три положения: 0°, 90° и 270° — их и проверяет тестовый ресурс.
    /// `.all` добавляла к ним 180°, и слой честно вставал вверх ногами: на
    /// телефоне этого никто не ждёт, а лишний переход между масками — лишний
    /// шанс поймать зависание на повороте.
    static let surfaceOrientations: UIInterfaceOrientationMask = [
        .portrait, .landscapeLeft, .landscapeRight
    ]

    static func mask(
        for destination: ShellDestination,
        isNativeLocked: Bool
    ) -> UIInterfaceOrientationMask {
        switch destination {
        case .game:
            return gameOrientations

        case .loading:
            // Установка, навсегда залоченная в native, показывает загрузку доли
            // секунды и уходит в игру. Разрешить здесь поворот — подарить
            // пользователю разворот экрана на каждом холодном старте в руках,
            // повёрнутых боком.
            return isNativeLocked ? gameOrientations : surfaceOrientations

        case .offline, .recoverableFailure, .setupRequired, .consent, .web:
            return surfaceOrientations
        }
    }

    /// Маска меняется вместе с экраном, но система сама об этом не узнаёт —
    /// её надо попросить перечитать, иначе витрина откроется в портрете, а
    /// игра останется лежать боком до первого поворота устройства.
    @MainActor
    static func refresh() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}
