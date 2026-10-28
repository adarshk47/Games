/// Staged releases built from one codebase with `--dart-define=STAGE=n`:
///
/// * 1 – 2.5.0: Dominoes and the rest; Business, Brain Age, Saanp-Seedhi and
///   Mom Memory "Coming soon"; old themes only (no theme-linked layout).
/// * 2 – 2.6.0: + Business and Brain Age (shown first) + Neon Night theme.
/// * 3 – 2.7.0: every game, every theme free, seasonal themes, and two
///   "New game – coming soon" cards.
///
/// Without the define (tests, debug runs) everything is on (stage 3).
const int kStage = int.fromEnvironment('STAGE', defaultValue: 3);

/// Version name shown in Profile for each stage.
const String kStageVersion = kStage == 1 ? '2.5.0' : (kStage == 2 ? '2.6.0' : '2.7.0');

/// Games newly opened in this stage: shown first on Home with a big card.
const Set<String> kStageNewGames = kStage == 2
    ? {'business', 'brain_age'}
    : (kStage == 3 ? {'snakes', 'mom_memory'} : {'dominoes'});

/// Game id → first stage it is playable in (earlier stages: "Coming soon").
const Map<String, int> kGameStage = {'business': 2, 'brain_age': 2, 'snakes': 3, 'mom_memory': 3};

/// Theme id → first stage it can be picked in.
const Map<String, int> kThemeStage = {
  'arcade': 3,
  'winter': 3,
  'christmas': 3,
  'newyear': 3,
  'neon': 2,
};

bool themeInStage(String id) => kStage >= (kThemeStage[id] ?? 1);
