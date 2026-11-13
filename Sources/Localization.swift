import Foundation

enum L10n {
    static var english = UserDefaults.standard.string(forKey: "language") == "en"
    static let translations: [String: String] = [
        "Язык": "Language",
        "Пауза и скрыть эффекты": "Pause and hide effects",
        "Продолжить снегопад": "Resume snowfall",
        "Отключить сугробы": "Disable snow accumulation",
        "Адский режим": "Infernal mode",
        "Скорость накопления": "Accumulation speed",
        "Скорость накопления: ×%.1f": "Accumulation speed: ×%.1f",
        "Транспорт": "Vehicle",
        "Паровоз": "Steam train",
        "Снегоуборочная машина": "Snowplow truck",
        "Вид снежинок": "Snowflake style",
        "Мягкие точки": "Soft dots",
        "Снежинки-кристаллы": "Crystal snowflakes",
        "Размер снежинок": "Snowflake size",
        "Размер снежинок: %d%%": "Snowflake size: %d%%",
        "Добавить снежок": "Add snowball",
        "Добавить череп": "Add skull",
        "Позвать снегоуборочный транспорт": "Call snow-clearing vehicle",
        "Очистить снег": "Clear snow",
        "Подключить снег на Dock…": "Enable snow on Dock…",
        "Универсальный доступ разрешён ✓": "Accessibility access granted ✓",
        "Универсальный доступ для снега на Dock": "Accessibility for snow on Dock",
        "Продолжить": "Continue",
        "Отмена": "Cancel",
        "Как играть…": "How to play…",
        "Выйти": "Quit",
        "Собери своего снеговика": "Build your snowman",
        "Понятно": "Got it",
        "Снегоуборочный транспорт, перетащите мышью": "Snow-clearing vehicle, drag with the mouse",
        "Снежок, перетащите к другому, чтобы собрать снеговика": "Snowball, drag onto another to build a snowman",
        "Череп, перетащите мышью": "Skull, drag with the mouse"
    ]

    static func text(_ source: String) -> String {
        if english { return translations[source] ?? source }
        return translations.first { $0.value == source }?.key ?? source
    }

    static var accessibilityNotice: String {
        english
            ? "Accessibility is a system-wide permission that can allow an app to read and control other apps’ interfaces; it is not limited to Dock. Winter Desktop uses it only to read Dock geometry for snow placement. Other effects work without this permission. You can revoke it in System Settings → Privacy & Security → Accessibility."
            : "Универсальный доступ — системное разрешение, позволяющее приложению читать интерфейс других приложений и управлять им; оно не ограничено Dock. Winter Desktop использует его только для чтения геометрии Dock и размещения снега. Остальные эффекты работают без этого разрешения. Отозвать его можно в Системные настройки → Конфиденциальность и безопасность → Универсальный доступ."
    }

    static var help: String {
        (english ? """
        Drag snowballs with the mouse. Roll them through snow to grow them; combine two, then add a third to build a snowman. Each ball keeps its size. Place them gently on window edges. Right-click removes a character.

        Small snowballs occasionally fall from the sky, with up to six characters across all displays. Their first landing is safe. Lift and drop a snowball or snowman to shatter it into a mound on a hard landing.

        Move the pointer over snow on windows or Dock to brush it off without clicking. Resizing sheds the unsupported edge; fast movement flings snow off. Closing a window releases its snow and characters.

        Choose a steam train or snowplow truck under Vehicle. It arrives when enough snow builds up, or you can call it from the menu and drag it along the bottom. Its growing mound collects snowballs and snowmen; held characters are protected.

        Use the sliders to adjust accumulation speed and snowflake size. Disable snow accumulation leaves only falling snow. Infernal mode replaces flakes with ash and snowballs with skulls.

        For snow on Dock, choose Enable snow on Dock… and grant Winter Desktop access under System Settings → Privacy & Security → Accessibility. Other effects work without this permission.
        """ : """
        Перетаскивай снежки мышью. Катай их по снегу, чтобы они росли; соедини два и добавь третий — получится снеговик. Каждый шар сохраняет размер. Аккуратно ставь их на края окон. Правый клик удаляет персонажа.

        Маленькие снежки иногда падают с неба; всего доступно до шести персонажей на всех экранах. Первое приземление безопасно. Подними снежок или снеговика и отпусти — при сильном ударе он рассыплется в сугроб.

        Проведи курсором по снегу на окнах или Dock, чтобы смахнуть его без клика. При сужении окна осыпается убранный край, при резком движении снег слетает с инерцией. Закроешь окно — снег и персонажи упадут вниз.

        В меню «Транспорт» можно выбрать паровоз или снегоуборочную машину. Транспорт выезжает, когда накопится снег; его можно вызвать из меню и двигать мышью вдоль нижнего края. Горка перед ним собирает снежки и снеговиков; удерживаемых мышью персонажей он не трогает.

        Ползунки регулируют скорость накопления и размер снежинок. «Отключить сугробы» оставляет только падающий снег. В адском режиме вместо снежинок падает пепел, а вместо снежков — черепа.

        Для снега на Dock выбери «Подключить снег на Dock…» и разреши Winter Desktop доступ в Системные настройки → Конфиденциальность и безопасность → Универсальный доступ. Остальные эффекты работают без этого разрешения.
        """) + "\n\n" + accessibilityNotice
    }
}
