class LevelUpInfo {
  const LevelUpInfo({required this.level, required this.title});
  final int level;
  final String title;
}

class LevelSystem {
  LevelSystem._();

  static const int expReview = 10;
  static const int expPost = 5;
  static const int expComment = 2;
  static const int expLike = 1;

  // 활발한 유저(월 ~300 EXP) 기준 Lv.7 ≈ 1년
  // 평균 유저(월 ~60 EXP) 기준 Lv.3~4에 머묾
  static const List<int> _thresholds = [
    0,      // Lv.1
    100,    // Lv.2
    300,    // Lv.3
    700,    // Lv.4
    1400,   // Lv.5
    2300,   // Lv.6
    3500,   // Lv.7  (활발한 유저 ~12개월)
    5000,   // Lv.8
    7000,   // Lv.9
    10000,  // Lv.10
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
    if (level >= maxLevel) return _thresholds.last + 13000;
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

  // 카드/댓글 등 공간이 좁은 곳에서 쓰는 짧은 라벨
  static String shortLabel(int level) => 'Lv.$level';
}
