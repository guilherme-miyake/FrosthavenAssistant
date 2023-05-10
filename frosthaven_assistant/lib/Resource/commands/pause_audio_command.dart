
import 'package:audioplayers/audioplayers.dart';

import '../../services/service_locator.dart';
import '../action_handler.dart';
import '../state/game_state.dart';

class PauseAudioCommand extends Command {
  final GameState _gameState = getIt<GameState>();

  PauseAudioCommand();

  @override
  void execute() {
    if(_gameState.audioPlayer.state == PlayerState.playing) {
      _gameState.audioPlayer.pause();
    } else if(_gameState.audioPlayer.state == PlayerState.paused){
      _gameState.audioPlayer.resume();
    }
  }

  @override
  void undo() {
  }

  @override
  String describe() {
    return "Pause/Resume Player";
  }

}
