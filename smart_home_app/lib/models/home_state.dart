class HomeState {
  final int? tankPercent;
  final double? tankDistance;
  final double? tempC;
  final double? humidity;
  final bool fireDetected;
  final bool flamePresent;
  final int fireRaw;
  final int fireHold;
  final bool flameActiveLow;
  final bool doorOpen;
  final bool bulbOn;
  final bool fanOn;
  final DateTime lastUpdated;

  const HomeState({
    this.tankPercent,
    this.tankDistance,
    this.tempC,
    this.humidity,
    this.fireDetected = false,
    this.flamePresent = false,
    this.fireRaw = 0,
    this.fireHold = 0,
    this.flameActiveLow = false,
    this.doorOpen = false,
    this.bulbOn = false,
    this.fanOn = false,
    required this.lastUpdated,
  });

  factory HomeState.initial() {
    return HomeState(
      tankPercent: null,
      tankDistance: null,
      tempC: null,
      humidity: null,
      fireDetected: false,
      flamePresent: false,
      fireRaw: 0,
      fireHold: 0,
      flameActiveLow: false,
      doorOpen: false,
      bulbOn: false,
      fanOn: false,
      lastUpdated: DateTime.now(),
    );
  }

  factory HomeState.fromJson(Map<String, dynamic> json) {
    int? pct;
    double? dist;

    if (json['tank'] is Map) {
      final tankMap = json['tank'] as Map<String, dynamic>;
      if (tankMap['pct'] != null) {
        pct = (tankMap['pct'] as num).toInt();
      }
      if (tankMap['dist'] != null) {
        dist = (tankMap['dist'] as num).toDouble();
      }
    }

    double? temp;
    if (json['temp'] != null) {
      temp = (json['temp'] as num).toDouble();
    }

    double? hum;
    if (json['hum'] != null) {
      hum = (json['hum'] as num).toDouble();
    }

    final isFire = json['fire'] == true;
    final hold = (json['fireHold'] as num?)?.toInt() ?? 0;
    final bool flame = json['flamePresent'] != null
        ? (json['flamePresent'] == true)
        : (isFire && hold == 0);

    return HomeState(
      tankPercent: pct,
      tankDistance: dist,
      tempC: temp,
      humidity: hum,
      fireDetected: isFire,
      flamePresent: flame,
      fireRaw: (json['fireRaw'] as num?)?.toInt() ?? 0,
      fireHold: hold,
      flameActiveLow: json['flameActiveLow'] == true,
      doorOpen: json['door'] == true,
      bulbOn: json['bulb'] == true,
      fanOn: json['fan'] == true,
      lastUpdated: DateTime.now(),
    );
  }

  HomeState copyWith({
    int? tankPercent,
    double? tankDistance,
    double? tempC,
    double? humidity,
    bool? fireDetected,
    bool? flamePresent,
    int? fireRaw,
    int? fireHold,
    bool? flameActiveLow,
    bool? doorOpen,
    bool? bulbOn,
    bool? fanOn,
    DateTime? lastUpdated,
  }) {
    return HomeState(
      tankPercent: tankPercent ?? this.tankPercent,
      tankDistance: tankDistance ?? this.tankDistance,
      tempC: tempC ?? this.tempC,
      humidity: humidity ?? this.humidity,
      fireDetected: fireDetected ?? this.fireDetected,
      flamePresent: flamePresent ?? this.flamePresent,
      fireRaw: fireRaw ?? this.fireRaw,
      fireHold: fireHold ?? this.fireHold,
      flameActiveLow: flameActiveLow ?? this.flameActiveLow,
      doorOpen: doorOpen ?? this.doorOpen,
      bulbOn: bulbOn ?? this.bulbOn,
      fanOn: fanOn ?? this.fanOn,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
