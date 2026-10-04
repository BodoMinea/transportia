import 'package:transportia/widgets/pressable_highlight.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/home_section.dart';
import '../models/tab_bar_item.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../utils/list_reorder.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_toggle_switch.dart';
import '../widgets/section_title.dart';
import '../widgets/toggle_card.dart';
import '../theme/app_text.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final List<Color> _accentColors = [
    const Color.fromARGB(255, 0, 113, 133),
    const Color(0xFF007AFF),
    const Color(0xFF34C759),
    const Color(0xFFFF9500),
    const Color(0xFFFF3B30),
    const Color(0xFFAF52DE),
    const Color(0xFFFF2D55),
    const Color(0xFF5856D6),
  ];

  Future<void> _saveAccentColor(Color color) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setAccentColor(color);
  }

  Future<void> _resetToDefault() async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.resetAccentColor();
  }

  Future<void> _saveMapStyle(String style) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setMapStyle(style);
  }

  Future<void> _saveAppThemeMode(AppThemeMode mode) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setAppThemeMode(mode);
  }

  Future<void> _saveVibrationsEnabled(bool enabled) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setVibrationsEnabled(enabled);
  }

  Future<void> _saveSearchMapEnabled(bool enabled) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setSearchMapEnabled(enabled);
  }

  Future<void> _saveSearchOptionsOpening(SearchOptionsOpening opening) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setSearchOptionsOpening(opening);
  }

  Future<void> _saveShowCalories(bool show) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setShowCalories(show);
  }

  Future<void> _moveHomeSection(
    List<HomeSectionConfig> sections,
    int index,
    int delta,
  ) async {
    final target = index + delta;
    if (target < 0 || target >= sections.length) return;
    await context.read<ThemeProvider>().setHomeSections(
      reorderWithin(sections, sections, index, target),
    );
  }

  Future<void> _toggleHomeSection(
    List<HomeSectionConfig> sections,
    HomeSection section,
    bool enabled,
  ) async {
    await context.read<ThemeProvider>().setHomeSections([
      for (final config in sections)
        config.section == section ? config.copyWith(enabled: enabled) : config,
    ]);
  }

  Future<void> _toggleTabBarItem(
    List<TabBarItemConfig> items,
    TabBarItem item,
    bool enabledAsTab,
  ) async {
    await context.read<ThemeProvider>().setTabBarItems([
      for (final config in items)
        config.item == item
            ? config.copyWith(enabledAsTab: enabledAsTab)
            : config,
    ]);
  }

  /// What each choice shows, in the words the search card itself uses.
  static String _openingDescription(SearchOptionsOpening opening) =>
      switch (opening) {
        SearchOptionsOpening.closed =>
          'Each part of the trip is one line. Tap it to see its options.',
        SearchOptionsOpening.stagesOpen =>
          'Each part of the trip shows its row of icons.',
        SearchOptionsOpening.everything =>
          'Each part of the trip shows every option, sliders included.',
      };

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final selectedAccentColor = themeProvider.accentColor;
    final selectedAppThemeMode = themeProvider.appThemeMode;
    final vibrationsEnabled = themeProvider.vibrationsEnabled;
    final searchMapEnabled = themeProvider.searchMapEnabled;
    final searchOptionsOpening = themeProvider.searchOptionsOpening;
    final showCalories = themeProvider.showCalories;
    final homeSections = themeProvider.homeSections;
    final tabBarItems = themeProvider.tabBarItems;

    return AppPageScaffold(
      title: 'Appearance',
      scrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconHeader(
            icon: LucideIcons.palette,
            title: 'Customize Your Experience',
            subtitle: 'Personalize the look and feel of the app',
            iconColor: selectedAccentColor,
            backgroundColor: selectedAccentColor.withValues(alpha: 0.12),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const SectionTitle(text: 'Accent Color'),
              const SizedBox(height: 8),
              Text(
                'Choose your preferred accent color',
                style: AppText.bodyFaint,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  const double itemExtent = 56;
                  const double spacing = 12;
                  final availableWidth = constraints.maxWidth;
                  int crossAxisCount = (availableWidth / (itemExtent + spacing))
                      .floor();
                  if (crossAxisCount < 1) {
                    crossAxisCount = 1;
                  } else if (crossAxisCount > _accentColors.length) {
                    crossAxisCount = _accentColors.length;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _accentColors.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final color = _accentColors[index];
                      final isSelected = selectedAccentColor == color;
                      return GestureDetector(
                        onTap: () => _saveAccentColor(color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.solidWhite : color,
                              width: isSelected ? 3 : 0,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  LucideIcons.check,
                                  color: AppColors.solidWhite,
                                  size: 24,
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: PressableHighlight(
                  onPressed: _resetToDefault,
                  enableHaptics: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Reset to default',
                        style: TextStyle(
                          fontSize: 16,
                          color: selectedAccentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.rotateCw,
                        size: 20,
                        color: selectedAccentColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const SectionTitle(text: 'App Theme'),
              const SizedBox(height: 8),
              Text(
                'Pick light, dark, or follow your system',
                style: AppText.bodyFaint,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInlineThemeOption(
                      'White',
                      AppThemeMode.light,
                      LucideIcons.sun,
                      const [ThemeProvider.lightBackground, Color(0xFFECECEC)],
                      selectedAppThemeMode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInlineThemeOption(
                      'Dark',
                      AppThemeMode.dark,
                      LucideIcons.moon,
                      const [ThemeProvider.darkBackground, Color(0xFF1D1D1D)],
                      selectedAppThemeMode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInlineThemeOption(
                      'System',
                      AppThemeMode.system,
                      LucideIcons.settings2,
                      const [
                        ThemeProvider.lightBackground,
                        ThemeProvider.darkBackground,
                      ],
                      selectedAppThemeMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const SectionTitle(text: 'Map Style'),
              const SizedBox(height: 8),
              Text(
                'Select your preferred map appearance',
                style: AppText.bodyFaint,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInlineMapStyleOption(
                      'Default',
                      'default',
                      LucideIcons.map,
                      const [
                        Color(0xFFE8F5E9),
                        Color(0xFF4CAF50),
                        Color(0xFF2196F3),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInlineMapStyleOption(
                      'Light',
                      'light',
                      LucideIcons.sun,
                      const [
                        Color(0xFFFFF9C4),
                        Color(0xFFFFEB3B),
                        Color(0xFF81D4FA),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInlineMapStyleOption(
                      'Dark',
                      'dark',
                      LucideIcons.moon,
                      const [
                        Color(0xFF263238),
                        Color(0xFF37474F),
                        Color(0xFF455A64),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Under the styles, since it decides whether there is a map on
              // the search screen to style at all.
              ToggleCard(
                icon: searchMapEnabled ? LucideIcons.map : LucideIcons.mapMinus,
                title: 'Map on the search screen',
                subtitle: searchMapEnabled
                    ? 'Shown above the search, with live vehicles'
                    : 'Hidden, so no map data is downloaded until you '
                          'open a map yourself',
                value: searchMapEnabled,
                onChanged: _saveSearchMapEnabled,
              ),
              const SizedBox(height: 32),
              const SectionTitle(text: 'Search Options'),
              const SizedBox(height: 8),
              Text(
                'How much is open when you start a search. You can still '
                'open and close each part yourself.',
                style: AppText.bodyFaint,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildOpeningOption(
                      'Summaries',
                      SearchOptionsOpening.closed,
                      LucideIcons.chevronsDownUp,
                      searchOptionsOpening,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOpeningOption(
                      'Quick icons',
                      SearchOptionsOpening.stagesOpen,
                      LucideIcons.layoutGrid,
                      searchOptionsOpening,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOpeningOption(
                      'All options',
                      SearchOptionsOpening.everything,
                      LucideIcons.slidersHorizontal,
                      searchOptionsOpening,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _openingDescription(searchOptionsOpening),
                style: AppText.bodyFaint,
              ),
              const SizedBox(height: 32),
              const SectionTitle(text: 'Trips'),
              const SizedBox(height: 8),
              Text(
                'Choose what a trip tells you besides the way',
                style: AppText.bodyFaint,
              ),
              const SizedBox(height: 16),
              ToggleCard(
                icon: LucideIcons.flame,
                title: 'Show calories',
                subtitle: showCalories
                    ? 'An estimate for the walking on each trip'
                    : 'Hidden on trip lists and trip details',
                value: showCalories,
                onChanged: _saveShowCalories,
              ),
              const SizedBox(height: 32),
              const SectionTitle(text: 'Home Screen'),
              const SizedBox(height: 8),
              Text(
                'Choose which lists show under the search, and use the arrows '
                'to put them in order',
                style: AppText.bodyFaint,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.black.withValues(alpha: 0.04),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < homeSections.length; i++)
                      _HomeSectionRow(
                        key: ValueKey(homeSections[i].section),
                        config: homeSections[i],
                        canMoveUp: i > 0,
                        canMoveDown: i < homeSections.length - 1,
                        onToggle: (enabled) => _toggleHomeSection(
                          homeSections,
                          homeSections[i].section,
                          enabled,
                        ),
                        onMoveUp: () => _moveHomeSection(homeSections, i, -1),
                        onMoveDown: () => _moveHomeSection(homeSections, i, 1),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const SectionTitle(text: 'Tab Bar'),
              const SizedBox(height: 8),
              Text(
                'Choose which screens are tabs at the bottom. One you turn '
                'off moves into Settings instead.',
                style: AppText.bodyFaint,
              ),
              const SizedBox(height: 16),
              for (final config in tabBarItems) ...[
                ToggleCard(
                  icon: config.item == TabBarItem.departures
                      ? LucideIcons.clock
                      : LucideIcons.bookmark,
                  title: config.item.label,
                  subtitle: config.enabledAsTab
                      ? 'Shown as a tab'
                      : 'Shown in Settings',
                  value: config.enabledAsTab,
                  onChanged: (enabled) =>
                      _toggleTabBarItem(tabBarItems, config.item, enabled),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 20),
              const SectionTitle(text: 'Interaction'),
              const SizedBox(height: 8),
              Text(
                'Choose whether the app should use tactile feedback',
                style: AppText.bodyFaint,
              ),
              const SizedBox(height: 16),
              ToggleCard(
                icon: vibrationsEnabled
                    ? LucideIcons.vibrate
                    : LucideIcons.vibrateOff,
                title: 'App vibrations',
                subtitle: vibrationsEnabled
                    ? 'Haptic feedback is enabled throughout the app'
                    : 'Haptic feedback is disabled throughout the app',
                value: vibrationsEnabled,
                onChanged: _saveVibrationsEnabled,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineThemeOption(
    String title,
    AppThemeMode value,
    IconData icon,
    List<Color> previewColors,
    AppThemeMode selectedAppThemeMode,
  ) {
    final themeProvider = context.watch<ThemeProvider>();
    final selectedAccentColor = themeProvider.accentColor;
    final isSelected = selectedAppThemeMode == value;

    return GestureDetector(
      onTap: () => _saveAppThemeMode(value),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: isSelected
              ? BorderRadius.circular(15)
              : BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? selectedAccentColor : AppColors.hairline,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: previewColors,
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.solidWhite.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected
                        ? selectedAccentColor
                        : AppColors.solidBlack.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? selectedAccentColor : AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A search-options choice, drawn like the theme choices above it but
  /// without a preview gradient: there is no colour to show.
  Widget _buildOpeningOption(
    String title,
    SearchOptionsOpening value,
    IconData icon,
    SearchOptionsOpening selected,
  ) {
    final accent = context.watch<ThemeProvider>().accentColor;
    final isSelected = selected == value;

    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => _saveSearchOptionsOpening(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentWash(accent)
                : AppColors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(isSelected ? 15 : 14),
            border: Border.all(
              color: isSelected ? accent : AppColors.hairline,
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? accent
                    : AppColors.black.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? accent : AppColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineMapStyleOption(
    String title,
    String value,
    IconData icon,
    List<Color> previewColors,
  ) {
    final themeProvider = context.watch<ThemeProvider>();
    final selectedAccentColor = themeProvider.accentColor;
    final selectedMapStyle = themeProvider.mapStyle;
    final isSelected = selectedMapStyle == value;

    return GestureDetector(
      onTap: () => _saveMapStyle(value),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: isSelected
              ? BorderRadius.circular(15)
              : BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? selectedAccentColor : AppColors.hairline,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: previewColors,
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.solidWhite.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: isSelected
                        ? selectedAccentColor
                        : AppColors.solidBlack.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? selectedAccentColor : AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One home screen section: arrows to move it, its name, and its switch.
class _HomeSectionRow extends StatelessWidget {
  const _HomeSectionRow({
    super.key,
    required this.config,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggle,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final HomeSectionConfig config;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onToggle;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReorderButton(
                icon: LucideIcons.chevronUp,
                label: 'Move ${config.section.label} up',
                onPressed: canMoveUp ? onMoveUp : null,
              ),
              _ReorderButton(
                icon: LucideIcons.chevronDown,
                label: 'Move ${config.section.label} down',
                onPressed: canMoveDown ? onMoveDown : null,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              config.section.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: config.enabled
                    ? AppColors.black
                    : AppColors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
          AppToggleSwitch(value: config.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}

class _ReorderButton extends StatelessWidget {
  const _ReorderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.black.withValues(
              alpha: onPressed != null ? 0.5 : 0.15,
            ),
          ),
        ),
      ),
    );
  }
}
