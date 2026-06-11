class LevelUpInfo {
  const LevelUpInfo({required this.level, required this.title});
  final int level;
  final String title;
}

class LevelSystem {
  LevelSystem._();

  // 활동별 지급 EXP
  static const int expReview = 10;
  static const int expPost = 5;
  static const int expComment = 2;
  static const int expLike = 1;

  // Lv.1→2: +30, Lv.2→3: +40, ... 매 레벨마다 +10씩 증가
  static const List<int> _thresholds = [
    0,   // Lv.1
    30,  // Lv.2
    70,  // Lv.3
    120, // Lv.4
    180, // Lv.5
    250, // Lv.6
    330, // Lv.7
    420, // Lv.8
    520, // Lv.9
    630, // Lv.10
  ];

  static const int maxLevel = 10;

  static int levelFromExp(int exp) {
    int level = 1;
    for (int i = 1; i < _thresholds.length; i++) {
      if (exp >= _thresholds[i]) {
        level = i + 1;
      } else {
        break;
      }
    }
    return level;
  }

  static int levelStartExp(int level) {
    final idx = (level - 1).clamp(0, _thresholds.length - 1);
    return _thresholds[idx];
  }

  static int levelEndExp(int level) {
    if (level >= maxLevel) return _thresholds.last + 130;
    return _thresholds[level];
  }

  static double progress(int exp) {
    final level = levelFromExp(exp);
    final start = levelStartExp(level);
    final end = levelEndExp(level);
    if (end <= start) return 1.0;
    return ((exp - start) / (end - start)).clamp(0.0, 1.0);
  }

  static String progressLabel(int exp) {
    final level = levelFromExp(exp);
    final start = levelStartExp(level);
    final end = levelEndExp(level);
    return '${exp - start} / ${end - start}';
  }

  static String title(int level) {
    const titles = [
      'Lv.1 · 백지장',
      'Lv.2 · 풋내기',
      'Lv.3 · 어엿한 필객',
      'Lv.4 · 필방 식구',
      'Lv.5 · 베테랑',
      'Lv.6 · 고수',
      'Lv.7 · 원로',
      'Lv.8 · 대가',
      'Lv.9 · 전설',
      'Lv.10 · 살아있는 신화',
    ];
    final idx = (level - 1).clamp(0, titles.length - 1);
    return titles[idx];
  }
}
