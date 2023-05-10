import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/commands/pause_audio_command.dart';

import '../Resource/commands/imbue_element_command.dart';
import '../Resource/commands/use_element_command.dart';
import '../Resource/enums.dart';
import '../Resource/state/game_state.dart';
import '../Resource/settings.dart';
import '../services/service_locator.dart';

class PlayButton extends StatefulWidget {
  final String icon;
  final double width = 40;
  final double borderWidth = 2;

  const PlayButton({Key? key, required this.icon}) : super(key: key);

  @override
  AnimatedContainerButtonState createState() => AnimatedContainerButtonState();
}

class AnimatedContainerButtonState extends State<PlayButton> {
  // Define the various properties with default values. Update these properties
  // when the user taps a FloatingActionButton.
  final GameState _gameState = getIt<GameState>();
  final Settings settings = getIt<Settings>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: EdgeInsets.only(right: 2 * settings.userScalingBars.value),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InkWell(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTapDown: (TapDownDetails details) {
                _gameState.action(PauseAudioCommand());
              },
              child: ValueListenableBuilder<int>(
                  valueListenable: _gameState.commandIndex,
                  builder: (context, value, child) {
                    Color? color;
                    if (_gameState.audioPlayer.state == PlayerState.playing) {
                      color = Colors.black;
                    } else if (_gameState.audioPlayer.state ==
                        PlayerState.paused) {
                      color = Colors.grey;
                    } else {
                      color = Colors.transparent;
                    }

                    return Image(
                      //fit: BoxFit.contain,
                      height:
                          widget.width * settings.userScalingBars.value * 0.65,
                      image: AssetImage(widget.icon),
                      color: color,
                      width:
                          widget.width * settings.userScalingBars.value * 0.65,
                    );
                  }),
            ),
            SizedBox(width: 100),
          ],
        ));
  }
}
