import 'dart:math' as math;
import 'dart:ui';

/// Rarity tier for cosmetic and tactical paddle skins.
enum PaddleRarity {
  common,
  rare,
  epic,
  legendary,
}

/// Information model describing a selectable paddle skin, its color scheme,
/// hit VFX asset, and gameplay attributes.
class PaddleItem {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final PaddleRarity rarity;

  // Kinetic Familiar Colors
  final Color paddleFaceColor;
  final Color paddleRimColor;
  final Color energyColor;
  final Color sweetSpotColor;

  // VFX Sprite configuration
  final String? vfxAsset;
  final int vfxFrameCount;
  final int vfxColumns;
  final int vfxRows;
  final double vfxFrameWidth;
  final double vfxFrameHeight;
  final double vfxScale;
  final double vfxStepDuration;

  // Aesthetic stats
  final int power;
  final int control;
  final int spin;

  const PaddleItem({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.rarity,
    required this.paddleFaceColor,
    required this.paddleRimColor,
    required this.energyColor,
    required this.sweetSpotColor,
    this.vfxAsset,
    this.vfxFrameCount = 1,
    this.vfxColumns = 1,
    this.vfxRows = 1,
    this.vfxFrameWidth = 128,
    this.vfxFrameHeight = 128,
    this.vfxScale = 1.0,
    this.vfxStepDuration = 0.04,
    required this.power,
    required this.control,
    required this.spin,
  });

  String get rarityLabel => switch (rarity) {
        PaddleRarity.common => 'STANDARD',
        PaddleRarity.rare => 'RARE',
        PaddleRarity.epic => 'EPIC',
        PaddleRarity.legendary => 'LEGENDARY',
      };

  Color get rarityColor => switch (rarity) {
        PaddleRarity.common => const Color(0xFF94A3B8),
        PaddleRarity.rare => const Color(0xFF38BDF8),
        PaddleRarity.epic => const Color(0xFFA855F7),
        PaddleRarity.legendary => const Color(0xFFF59E0B),
      };
}

/// Official catalog of tournament and elemental pickleball paddles.
class PaddleCatalog {
  static const List<PaddleItem> allPaddles = [
    PaddleItem(
      id: 'pro_tournament',
      name: 'PRO TOURNAMENT',
      tagline: 'Standard USAP Certified Carbon Core',
      description:
          'Precision tournament weapon forged with raw graphite face and reactive edge guard. Produces a clean kinetic pulse.',
      rarity: PaddleRarity.common,
      paddleFaceColor: Color(0xFF00E5FF),
      paddleRimColor: Color(0xFF102A43),
      energyColor: Color(0xFF00E5FF),
      sweetSpotColor: Color(0xFFFFFFFF),
      vfxAsset: null, // Uses default shockwave
      power: 78,
      control: 92,
      spin: 80,
    ),
    PaddleItem(
      id: 'thunderstrike',
      name: 'THUNDERSTRIKE',
      tagline: 'Overcharged Lightning Core',
      description:
          'Infused with atmospheric electric arcs. Striking the ball unleashes crackling high-voltage lightning sparks.',
      rarity: PaddleRarity.epic,
      paddleFaceColor: Color(0xFF00F0FF),
      paddleRimColor: Color(0xFF1E1B4B),
      energyColor: Color(0xFFFACC15),
      sweetSpotColor: Color(0xFFFEF08A),
      vfxAsset: 'vfx/vfx_lightning.png',
      vfxFrameCount: 4,
      vfxColumns: 4,
      vfxRows: 1,
      vfxFrameWidth: 256,
      vfxFrameHeight: 128,
      vfxScale: 1.4,
      vfxStepDuration: 0.05,
      power: 88,
      control: 82,
      spin: 85,
    ),
    PaddleItem(
      id: 'inferno_blaze',
      name: 'INFERNO BLAZE',
      tagline: 'Thermobaric Fireburst Face',
      description:
          'Superheated volcanic core that detonates brilliant incendiary fireball explosions upon sweet-spot smashes.',
      rarity: PaddleRarity.legendary,
      paddleFaceColor: Color(0xFFFF3D00),
      paddleRimColor: Color(0xFF3E1F00),
      energyColor: Color(0xFFFF6D00),
      sweetSpotColor: Color(0xFFFFD600),
      vfxAsset: 'vfx/vfx_fire.png',
      vfxFrameCount: 8,
      vfxColumns: 8,
      vfxRows: 1,
      vfxFrameWidth: 128,
      vfxFrameHeight: 128,
      vfxScale: 1.3,
      vfxStepDuration: 0.035,
      power: 96,
      control: 74,
      spin: 88,
    ),
    PaddleItem(
      id: 'blood_sovereign',
      name: 'BLOOD SOVEREIGN',
      tagline: 'Occult Sanguine Resonance',
      description:
          'Ethereal dark crimson and obsidian composite that channels pulsing blood-void shockwaves upon contact.',
      rarity: PaddleRarity.legendary,
      paddleFaceColor: Color(0xFFE11D48),
      paddleRimColor: Color(0xFF1C060D),
      energyColor: Color(0xFFFB7185),
      sweetSpotColor: Color(0xFFFDA4AF),
      vfxAsset: 'vfx/vfx_blood.png',
      vfxFrameCount: 12,
      vfxColumns: 12,
      vfxRows: 1,
      vfxFrameWidth: 128,
      vfxFrameHeight: 128,
      vfxScale: 1.25,
      vfxStepDuration: 0.03,
      power: 92,
      control: 80,
      spin: 91,
    ),
    PaddleItem(
      id: 'starcaller',
      name: 'STARCALLER COSMOS',
      tagline: 'Astral Supernova Weave',
      description:
          'Forged from stardust and nebular crystal. Renders celestial lavender aura trails and shimmering cosmic burst motes.',
      rarity: PaddleRarity.epic,
      paddleFaceColor: Color(0xFFA855F7),
      paddleRimColor: Color(0xFF2E1065),
      energyColor: Color(0xFFC084FC),
      sweetSpotColor: Color(0xFFF3E8FF),
      vfxAsset: 'vfx/vfx_starcaller.png',
      vfxFrameCount: 8,
      vfxColumns: 5,
      vfxRows: 2,
      vfxFrameWidth: 128,
      vfxFrameHeight: 128,
      vfxScale: 1.25,
      vfxStepDuration: 0.04,
      power: 84,
      control: 90,
      spin: 94,
    ),
    PaddleItem(
      id: 'heavy_impact',
      name: 'KINETIC SLAMMER',
      tagline: 'Industrial High-Impact Alloy',
      description:
          'Reinforced titanium cross-weave designed for unrelenting drive velocity with concentric kinetic concussion rings.',
      rarity: PaddleRarity.rare,
      paddleFaceColor: Color(0xFFF59E0B),
      paddleRimColor: Color(0xFF292524),
      energyColor: Color(0xFFFBBF24),
      sweetSpotColor: Color(0xFFFEF3C7),
      vfxAsset: 'vfx/vfx_impact.png',
      vfxFrameCount: 6,
      vfxColumns: 5,
      vfxRows: 2,
      vfxFrameWidth: 128,
      vfxFrameHeight: 64,
      vfxScale: 1.35,
      vfxStepDuration: 0.04,
      power: 90,
      control: 85,
      spin: 78,
    ),
    PaddleItem(
      id: 'shadow_smoke',
      name: 'SHADOW PHANTOM',
      tagline: 'Sub-Zero Stealth Composite',
      description:
          'Stealth matte carbon blade emitting dissipating phantom smoke trails and dust poofs that conceal ball spin.',
      rarity: PaddleRarity.rare,
      paddleFaceColor: Color(0xFF64748B),
      paddleRimColor: Color(0xFF0F172A),
      energyColor: Color(0xFF94A3B8),
      sweetSpotColor: Color(0xFFE2E8F0),
      vfxAsset: 'vfx/vfx_smoke.png',
      vfxFrameCount: 7,
      vfxColumns: 7,
      vfxRows: 1,
      vfxFrameWidth: 128,
      vfxFrameHeight: 128,
      vfxScale: 1.2,
      vfxStepDuration: 0.04,
      power: 82,
      control: 89,
      spin: 87,
    ),
  ];

  static PaddleItem getById(String id) {
    return allPaddles.firstWhere(
      (paddle) => paddle.id == id,
      orElse: () => allPaddles.first,
    );
  }

  /// Returns a randomly selected paddle skin from the catalog for AI bots.
  static PaddleItem getRandomPaddle([math.Random? random]) {
    final rng = random ?? math.Random();
    return allPaddles[rng.nextInt(allPaddles.length)];
  }
}
