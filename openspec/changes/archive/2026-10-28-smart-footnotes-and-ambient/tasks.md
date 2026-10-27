# Задачи (Tasks): Всплывающие сноски и Фоновый Эмбиент

## 1. Зависимости и аудио-ассеты

- [x] 1.1 Добавить `just_audio: ^0.9.43` в `pubspec.yaml`, выполнить `flutter pub get` и подтвердить успешную компиляцию зависимостей.
- [x] 1.2 Создать каталог `assets/audio/ambient/`, сгенерировать/добавить 4 компактные бесшовные дорожки (rain, fireplace, forest, cafe) и зарегистрировать их в секции `flutter.assets` файла `pubspec.yaml`.

## 2. Модель и парсинг сносок (Smart Footnotes Engine)

- [x] 2.1 Добавить поле `final Map<String, String> footnotes;` в класс `BookParsedData` в `lib/services/book_parser_service.dart`.
- [x] 2.2 Реализовать извлечение сносок из FB2 (`<body name="notes">` и блоки `<section id="...">`) в словарь примечаний `footnotes`.
- [x] 2.3 Реализовать извлечение сносок и примечаний из файлов EPUB (якоря `href="#..."`, `aside`, `epub:type="noteref"`).
- [x] 2.4 Написать юнит-тесты в `test/footnote_parser_test.dart` для проверки извлечения сносок FB2 и EPUB и убедиться в успешном прохождении через `flutter test test/footnote_parser_test.dart`.

## 3. Пользовательский интерфейс сносок

- [x] 3.1 Создать виджет всплывающего окна сноски `SmartFootnoteSheet` в `lib/widgets/reader/smart_footnote_sheet.dart` с плавным открытием, оформлением в стиле темы читалки и кнопкой копирования.
- [x] 3.2 Подключить распознавание меток сносок в `ChapterContentView` (`lib/widgets/reader/chapter_content_view.dart`), добавив вызов `SmartFootnoteSheet.show` по нажатию на сноску без перезагрузки или скролла страницы.

## 4. Движок и сервис фонового звука (Ambient Soundscape Engine)

- [x] 4.1 Создать модель дорожки `AmbientTrack` с полями id, названия, иконки и пути к ассету в `lib/models/ambient_track.dart`.
- [x] 4.2 Реализовать синглтон `AmbientSoundService` в `lib/services/ambient_sound_service.dart` с поддержкой зацикливания ExoPlayer (`LoopMode.one`), независимой громкости, фонового воспроизведения и плавного затухания `fadeStop()`.
- [x] 4.3 Написать юнит-тесты в `test/ambient_sound_test.dart` для проверки корректности переключения дорожек, громкости и таймера затухания.

## 5. Интерфейс панели управления эмбиентом

- [x] 5.1 Создать шторку настроек `AmbientSoundSheet` в `lib/widgets/reader/ambient_sound_sheet.dart` с выбором дорожки (чипы с иконками), слайдером громкости и быстрыми пресетами таймера сна.
- [x] 5.2 Интегрировать кнопку эмбиента в панель читалки `lib/screens/reader_screen.dart` с анимированным индикатором активного звучания.

## 6. Контроль качества и проверка регрессий

- [x] 6.1 Выполнить статический анализ `dart analyze lib` и убедиться в отсутствии предупреждений (0 warnings/errors).
- [x] 6.2 Запустить полный набор тестов `flutter test` и подтвердить успешное прохождение всех тестов приложения.
