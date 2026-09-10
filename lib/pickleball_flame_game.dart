import 'package:flame/game.dart';

import 'game_simulation.dart';

class PickleballFlameGame extends FlameGame {
  PickleballFlameGame({GameSimulation? simulation})
      : simulation = simulation ?? GameSimulation();

  static const double fixedStep = 0.025;

  final GameSimulation simulation;
  double inputX = 0;
  double inputY = 0;
  double _timeAccumulator = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _timeAccumulator += dt.clamp(0, 0.1);

    while (_timeAccumulator >= fixedStep) {
      simulation.update(joystickX: inputX, joystickY: inputY);
      _timeAccumulator -= fixedStep;
    }
  }
}