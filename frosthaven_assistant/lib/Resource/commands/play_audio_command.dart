
import 'package:audioplayers/audioplayers.dart';

import '../../services/service_locator.dart';
import '../action_handler.dart';
import '../state/game_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PlayAudioCommand extends Command {
  final GameState _gameState = getIt<GameState>();
  late final String track;

  PlayAudioCommand(this.track);

  @override
  void execute() async {
    var path = p.join((await getApplicationDocumentsDirectory()).path,"frosthaven","audio","output",track);
    _gameState.audioPlayer.play(DeviceFileSource(path));
  }

  @override
  void undo() {
  }

  @override
  String describe() {
    return "Play Track ${track}";
  }

}
