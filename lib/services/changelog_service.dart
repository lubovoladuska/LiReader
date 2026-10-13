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
      version: '1.1.0',
      date: 'Октябрь 2026',
      headline: 'Озвучка текста голосом (TTS) и дизайнерские карточки цитат',
      isLatest: true,
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
