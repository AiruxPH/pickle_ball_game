// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  final file = File(r'C:\Users\CLienT\Desktop\PICKLEBALL\pickle_ball_game\assets\images\character-spritesheet (2).png');
  final bytes = file.readAsBytesSync();
  int width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  int height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  
  print('Sprite Width: $width, Height: $height');
}
