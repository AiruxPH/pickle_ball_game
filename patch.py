import re

with open('lib/game_simulation.dart', 'r') as f:
    code = f.read()

# 1. Update SwingResult enum
code = re.sub(r'enum SwingResult \{ hit, missed, kitchenFault \}', 'enum SwingResult { hit, missed, kitchenFault, twoBounceFault }', code)

# 2. Add Telemetry variables
code = code.replace('int rallyLength = 0;', 'int rallyLength = 0;\n  double _telemetryTimer = 0.0;')

# 3. Add Telemetry logging in update
old_update = '  RallyEnd? update({double joystickX = 0, double joystickY = 0}) {\n    double jX = joystickX;\n    double jY = joystickY;'
new_update = '''  RallyEnd? update({double joystickX = 0, double joystickY = 0}) {
    _telemetryTimer += 0.025;
    if (_telemetryTimer >= 0.5) {
      _telemetryTimer = 0.0;
      print('[TELEMETRY] Bot(X: , Y: ) | Target(X: , Y: ) | Ball(X: , Y: , Z: )');
    }
    double jX = joystickX;
    double jY = joystickY;'''
code = code.replace(old_update, new_update)

# 4. Update swing() two bounce rule
old_swing = '''    if (gameMode != GameMode.freeRoamPractice && !GameDebugConfig.bypassKitchenRules && PickleballRules.isKitchenVolley(
      playerY: playerY,
      ballHasBounced: ball.hasBounced,
    )) {
      return SwingResult.kitchenFault;
    }
    if ((ball.x - playerX).abs() > playerHitRadiusX || 
        (ball.y - playerY).abs() > playerHitRadiusY || 
        ball.z < playerHitZMin || 
        ball.z > playerHitZMax) {
      return SwingResult.missed;
    }'''

new_swing = '''    if ((ball.x - playerX).abs() > playerHitRadiusX || 
        (ball.y - playerY).abs() > playerHitRadiusY || 
        ball.z < playerHitZMin || 
        ball.z > playerHitZMax) {
      return SwingResult.missed;
    }

    if (gameMode != GameMode.freeRoamPractice && !GameDebugConfig.bypassKitchenRules) {
      if (rallyLength < 3 && !ball.hasBounced) {
        return SwingResult.twoBounceFault;
      }
      if (PickleballRules.isKitchenVolley(
        playerY: playerY,
        ballHasBounced: ball.hasBounced,
      )) {
        return SwingResult.kitchenFault;
      }
    }'''
code = code.replace(old_swing, new_swing)

# 5. Update bot two bounce rule
old_bot = '''    if (ball.velocityY < 0 &&
        (ball.y - botY).abs() <= botHitRadiusY &&
        (ball.x - botX).abs() <= botHitRadiusX &&
        ball.z >= botHitZMin &&
        ball.z <= botHitZMax &&
        ball.hasBounced) {'''

new_bot = '''    if (ball.velocityY < 0 &&
        (ball.y - botY).abs() <= botHitRadiusY &&
        (ball.x - botX).abs() <= botHitRadiusX &&
        ball.z >= botHitZMin &&
        ball.z <= botHitZMax) {
      if (rallyLength < 3 && !ball.hasBounced) {
         // Bot must wait for the ball to bounce
      } else {'''

code = code.replace(old_bot, new_bot)

# 6. Fix bot closing brace
old_bot_end = '''         ball.velocityX = (ball.x - botX) * 0.12;
      }
      ball.hasBounced = false;
    }

    camera.updateDynamics('''
new_bot_end = '''         ball.velocityX = (ball.x - botX) * 0.12;
      }
      ball.hasBounced = false;
      }
    }

    camera.updateDynamics('''
code = code.replace(old_bot_end, new_bot_end)

# 7. Player Free Roam inertia
code = code.replace('playerVelocityX += (targetVelX - playerVelocityX) * 0.15;', 'final friction = gameMode == GameMode.freeRoamPractice ? 0.05 : 0.15; playerVelocityX += (targetVelX - playerVelocityX) * friction;')
code = code.replace('playerVelocityY += (targetVelY - playerVelocityY) * 0.15;', 'playerVelocityY += (targetVelY - playerVelocityY) * friction;')


with open('lib/game_simulation.dart', 'w') as f:
    f.write(code)

print("Patched!")
