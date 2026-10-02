// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  final file = File(r'C:\Users\CLienT\Desktop\PICKLEBALL\pickle_ball_game\assets\images\lpc_male_item_animations_2026-10-01T05-11-12\standard\idle\010 body_color__light_.png');
  // Read first 24 bytes to parse PNG header
  final bytes = file.readAsBytesSync();
  // PNG IHDR chunk contains width and height
  // bytes 16-19: width
  // bytes 20-23: height
  int width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  int height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  
  print('Idle Width: $width, Height: $height');

  final fileWalk = File(r'C:\Users\CLienT\Desktop\PICKLEBALL\pickle_ball_game\assets\images\lpc_male_item_animations_2026-10-01T05-11-12\standard\walk\010 body_color__light_.png');
  final bytesWalk = fileWalk.readAsBytesSync();
  int widthWalk = (bytesWalk[16] << 24) | (bytesWalk[17] << 16) | (bytesWalk[18] << 8) | bytesWalk[19];
  int heightWalk = (bytesWalk[20] << 24) | (bytesWalk[21] << 16) | (bytesWalk[22] << 8) | bytesWalk[23];
  print('Walk Width: $widthWalk, Height: $heightWalk');
  
  final fileSlash = File(r'C:\Users\CLienT\Desktop\PICKLEBALL\pickle_ball_game\assets\images\lpc_male_item_animations_2026-10-01T05-11-12\standard\slash\010 body_color__light_.png');
  final bytesSlash = fileSlash.readAsBytesSync();
  int widthSlash = (bytesSlash[16] << 24) | (bytesSlash[17] << 16) | (bytesSlash[18] << 8) | bytesSlash[19];
  int heightSlash = (bytesSlash[20] << 24) | (bytesSlash[21] << 16) | (bytesSlash[22] << 8) | bytesSlash[23];
  print('Slash Width: $widthSlash, Height: $heightSlash');
}
