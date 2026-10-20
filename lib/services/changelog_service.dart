import 'package:flutter/material.dart';

class ChangelogItem {
  final IconData icon;
  final String title;
  final String description;

  const ChangelogItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class ReleaseNote {
  final String version;
  final String date;
  final String headline;
  final bool isLatest;
  final List<ChangelogItem> items;

  const ReleaseNote({
    required this.version,
    required this.date,
    required this.headline,
    this.isLatest = false,
    required this.items,
  });
}

class ChangelogService {
  /// History of all releases. Add new versions to the top of this list.
  static const List<ReleaseNote> releases = [
    ReleaseNote(
      version: '1.2.2',
      date: 'Октябрь 2026',
      headline: 'Оптимизация тем, ручной поворот обоев и устранение черного экрана',
      isLatest: true,
      items: [
        ChangelogItem(
          icon: Icons.rotate_right_rounded,
          title: 'Ручной поворот и исправление автоповорота фото',
          description:
              'Устранена проблема, когда фото из галереи самопроизвольно поворачивалось набок. Добавлены точные переключатели угла (0°, 90°, 180°, 270°) и кнопка шагового поворота как в шторке тем, так и в расширенном редакторе.',
        ),
        ChangelogItem(
          icon: Icons.flash_on_rounded,
          title: 'Мгновенный старт читалки без черного экрана',
          description:
              'Настройки темы и кастомные обои теперь загружаются мгновенно в приоритетном порядке. Исключены зависания при открытии книги и устранен черный экран при перезаходе в приложение.',
        ),
        ChangelogItem(
          icon: Icons.memory_rounded,
          title: 'Аппаратная оптимизация памяти (ResizeImage)',
          description:
              'Кастомные фотографии высокого разрешения (12-48 Мп) теперь оптимизируются при декодировании, предотвращая перегрузку оперативной памяти и видеочипа при наложении размытия и фильтров.',
        ),
        ChangelogItem(
          icon: Icons.save_rounded,
          title: 'Надежное постоянное хранение обоев',
          description:
              'Выбранные фотографии теперь сохраняются в защищенную постоянную директорию приложения, поэтому фоны больше не исчезают после перезапуска или очистки системного кэша Android.',
        ),
      ],
    ),
    ReleaseNote(
      version: '1.2.1',
      date: 'Октябрь 2026',
      headline: 'Всплывающий переводчик, толковый словарь (Wiktionary/Википедия) и личный словарь',
      isLatest: false,
      items: [
        ChangelogItem(
          icon: Icons.g_translate_rounded,
          title: 'Быстрый перевод по выделению текста',
          description:
              'Выделяйте незнакомые слова или фразы во время чтения и мгновенно переводите их на русский или любой другой язык. Доступен быстрый реверс пары языков [ EN ⇄ RU ] и подборка синонимов.',
        ),
        ChangelogItem(
          icon: Icons.menu_book_rounded,
          title: 'Толковый словарь (Wiktionary и Википедия)',
          description:
              'Для отдельных слов автоматически подтягиваются части речи и точные словарные определения из Wiktionary (для английских слов) и энциклопедические статьи Википедии (для русскоязычных терминов).',
        ),
        ChangelogItem(
          icon: Icons.volume_up_rounded,
          title: 'Озвучка произношения (TTS)',
          description:
              'Слушайте правильное звучание незнакомых иностранных слов в одно касание прямо в окне перевода.',
        ),
        ChangelogItem(
          icon: Icons.bookmark_added_rounded,
          title: 'Личный словарь книги в боковой шторке',
          description:
              'Сохраняйте интересные слова вместе с контекстом из книги в один клик. В боковой шторке читалки появилась вкладка «Словарь» с удобным просмотром, прослушиванием и управлением.',
        ),
      ],
    ),
    ReleaseNote(
      version: '1.2.0',
      date: 'Октябрь 2026',
      headline: 'Поддержка комиксов и манги (CBZ/ZIP), режимы Манги и Вебтуна, плавный зум',
      isLatest: false,
      items: [
        ChangelogItem(
          icon: Icons.photo_library_rounded,
          title: 'Полноценный графический ридер (CBZ / ZIP)',
          description:
              'Читайте любимые комиксы, мангу и графические новеллы прямо в LiReader! Автоматическое распознавание архивов CBZ и ZIP с картинками, умная естественная сортировка страниц и автогенерация обложек.',
        ),
        ChangelogItem(
          icon: Icons.auto_stories_rounded,
          title: 'Режимы чтения: Комиксы, Манга (R-L) и Вебтун',
          description:
              'Переключайтесь между классическим листанием слева-направо (L-R), японским стилем чтения справа-налево (R-L Manga) и непрерывной вертикальной лентой (Webtoon).',
        ),
        ChangelogItem(
          icon: Icons.zoom_in_rounded,
          title: 'Свободный зум и двойной тап',
          description:
              'Приближайте мелкие реплики и детали рисунка жестом pinch-to-zoom (до 4.5x) или мгновенно увеличивайте область двойным тапом с плавным сбросом.',
        ),
        ChangelogItem(
          icon: Icons.grid_view_rounded,
          title: 'Сетка страниц и быстрый переход',
          description:
              'Просматривайте миниатюры всех страниц комикса в наглядной сетке и прыгайте на любую страницу в один клик.',
        ),
        ChangelogItem(
          icon: Icons.palette_rounded,
          title: 'Выбор фона: OLED Black, Графит, Сепия',
          description:
              'Адаптируйте фон комикса под освещение — от абсолютного глубокого черного для OLED-экранов до мягкой сепии.',
        ),
      ],
    ),
    ReleaseNote(
      version: '1.1.0',
      date: 'Октябрь 2026',
      headline: 'Озвучка текста голосом (TTS) и дизайнерские карточки цитат',
      isLatest: false,
      items: [
        ChangelogItem(
          icon: Icons.headphones_rounded,
          title: 'Озвучка книг голосом (Text-to-Speech)',
          description:
              'Слушайте книги в дороге или перед сном! Компактный плавающий плеер, регулировка скорости от 0.75x до 2.0x, переход по абзацам и чтение при выключенном экране.',
        ),
        ChangelogItem(
          icon: Icons.record_voice_over_rounded,
          title: 'Умная подсветка и автоскролл при чтении',
          description:
              'При воспроизведении озвучки читаемый абзац мягко подсвечивается акцентным цветом, а страница книги плавно прокручивается следом за голосом.',
        ),
        ChangelogItem(
          icon: Icons.format_quote_rounded,
          title: 'Генератор карточек цитат для соцсетей',
          description:
              'Выделите любую фразу в книге и создайте красивую открытку в 1 клик. 4 авторских стиля оформления, форматы 1:1 (пост) и 9:16 (Stories) и экспорт в Telegram или WhatsApp.',
        ),
        ChangelogItem(
          icon: Icons.auto_stories_rounded,
          title: 'Автоматический переход по главам в аудио',
          description:
              'При завершении текущей главы воспроизведение автоматически переходит к следующей без необходимости доставать телефон.',
        ),
      ],
    ),
    ReleaseNote(
      version: '1.0.1',
      date: 'Октябрь 2026',
      headline: 'Поддержка FB2, честная статистика и GitHub обновления',
      isLatest: false,
      items: [
        ChangelogItem(
          icon: Icons.menu_book_rounded,
          title: 'Полная поддержка формата FB2',
          description:
              'Книги FB2 теперь открываются мгновенно и без сбоев. Добавлена распаковка .fb2.zip, поддержка кодировки Windows-1251 (CP1251), умная очистка XML-разметки и regex-парсинг при повреждениях.',
        ),
        ChangelogItem(
          icon: Icons.insights_rounded,
          title: 'Честная и точная статистика чтения',
          description:
              'Устранены накрутки и галлюцинации таймера. Слова фиксируются один раз при дочитывании главы (100%). При повторном открытии ранее прочитанных глав слова не дублируются. Добавлен умный детектор бездействия (>90 сек паузы) и кнопка сброса истории.',
        ),
        ChangelogItem(
          icon: Icons.fullscreen_rounded,
          title: 'Мягкий полноэкранный режим',
          description:
              'Один тап по центру экрана плавно и аккуратно скрывает верхнюю и нижнюю панели управления, погружая вас в чтение без рывков.',
        ),
        ChangelogItem(
          icon: Icons.system_update_rounded,
          title: 'Автоматические обновления с GitHub',
          description:
              'LiReader проверяет свежие релизы на GitHub. Скачивание APK происходит в фоне с прогрессом, скоростью и процентами в системных уведомлениях Android.',
        ),
        ChangelogItem(
          icon: Icons.auto_awesome_rounded,
          title: 'История версий («Что нового»)',
          description:
              'Удобный и уютный журнал изменений прямо в окне информации о приложении. Всегда в курсе новых возможностей!',
        ),
      ],
    ),
    ReleaseNote(
      version: '1.0.0',
      date: 'Октябрь 2026',
      headline: 'Первый релиз LiReader',
      isLatest: false,
      items: [
        ChangelogItem(
          icon: Icons.library_books_rounded,
          title: 'Библиотека и полки',
          description:
              'Управление книгами, создание пользовательских полок с иконками, добавление в Избранное и сортировка.',
        ),
        ChangelogItem(
          icon: Icons.wallpaper_rounded,
          title: 'Глубокая кастомизация читалки',
          description:
              'Обои из галереи, 4 поворота картинки на 90°, масштабирование (Cover, Contain, Tile, Fill), размытие и затемнение подложки для максимального комфорта глаз.',
        ),
        ChangelogItem(
          icon: Icons.dark_mode_rounded,
          title: 'Премиальная темная и светлая тема',
          description:
              'Шрифты Serif, Sans, Mono, настройки размера текста, межстрочного интервала и выравнивания.',
        ),
        ChangelogItem(
          icon: Icons.backup_rounded,
          title: 'Резервное копирование',
          description:
              'Экспорт всей библиотеки, полок, заметок и прогресса чтения в JSON-файл и быстрое восстановление.',
        ),
      ],
    ),
  ];

  static ReleaseNote get latest => releases.first;
}
