enum AppAppearance { dark, light, system }

class AppPreferences {
  const AppPreferences({this.appearance = AppAppearance.light});
  final AppAppearance appearance;
}
