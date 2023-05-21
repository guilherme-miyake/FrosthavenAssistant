import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:frosthaven_assistant/Resource/commands/add_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_condition_command.dart';
import 'package:frosthaven_assistant/Resource/commands/add_standee_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_health_command.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_xp_command.dart';
import 'package:frosthaven_assistant/Resource/commands/draw_command.dart';
import 'package:frosthaven_assistant/Resource/commands/draw_loot_card_command.dart';
import 'package:frosthaven_assistant/Resource/commands/end_scenario_command.dart';
import 'package:frosthaven_assistant/Resource/commands/ice_wraith_change_form_command.dart';
import 'package:frosthaven_assistant/Resource/commands/imbue_element_command.dart';
import 'package:frosthaven_assistant/Resource/commands/next_round_command.dart';
import 'package:frosthaven_assistant/Resource/commands/next_turn_command.dart';
import 'package:frosthaven_assistant/Resource/commands/remove_character_command.dart';
import 'package:frosthaven_assistant/Resource/commands/remove_condition_command.dart';
import 'package:frosthaven_assistant/Resource/commands/remove_monster_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_character_level_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_init_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_level_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_loot_owner_command.dart';
import 'package:frosthaven_assistant/Resource/commands/set_scenario_command.dart';
import 'package:frosthaven_assistant/Resource/commands/use_element_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/state/character.dart';
import 'package:frosthaven_assistant/Resource/state/loot_deck_state.dart';
import 'package:frosthaven_assistant/Resource/state/monster.dart';
import 'package:frosthaven_assistant/services/network/target.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_static/shelf_static.dart' as shelf_static;

import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import '../service_locator.dart';
import 'package:path/path.dart' as p;

class WebServer {
  static const int VERSION = 4;
  final GameState _gameState = getIt<GameState>();

  HttpServer? _server;

  Future<void> startServer() async {
    final _router = shelf_router.Router()
      ..get('/state', _getStateHandler)
      ..get('/file/<folder>/<file>', _getFileHandler)
      ..get('/play/<folder>/<file>', _playFileHandler)
      ..get('/out/<file>', _getOutFileHandler)
      ..get('/getLoot', _getLootHandler)
      ..post('/startRound', _startRoundHandler)
      ..post('/endRound', _endRoundHandler)
      ..post('/addMonster', _addMonsterHandler)
      ..post('/addCharacter', _addCharacterHandler)
      ..post('/removeCharacter', _removeCharacterHandler)
      ..post('/switchMonster', _switchMonsterTypeHandler)
      ..post('/setScenario', _setScenarioHandler)
      ..post('/setSection', _setSectionHandler)
      ..post('/applyCondition', _applyConditionHandler)
      ..post('/change', _applyChangeHandler)
      ..post('/setElement', _applySetElementHandler)
      ..post('/loot', _lootHandler)
      ..post('/setCurrentTurn', _setCurrentTurnHandler)
      ..post('/endScenario', _endScenarioHandler)
      ..post('/setLevel', _setLevelHandler);

    _server = await shelf_io.serve(
      // See https://pub.dev/documentation/shelf/latest/shelf/logRequests.html
      // logRequests()
      // See https://pub.dev/documentation/shelf/latest/shelf/MiddlewareExtensions/addHandler.html
      // .addHandler(_router),
      _router,
      InternetAddress.anyIPv4, // Allows external connections
      int.parse(getIt<Settings>().lastKnownWebPort),
    );
  }

  void stopServer(String? error) {
    if (_server != null) {
      _server!.close().catchError((error) => print(error));
    }
  }

  // Router instance to handler requests.
  Response _getOutFileHandler(Request request, String file) {
    var folder = getIt<Settings>().webFolder.value;
    if (folder != "") {
      File f = File(p.join(folder, Uri.decodeFull(file)));
      return Response.ok(f.readAsBytesSync(),
          headers: {"Content-Type": "application/json"});
    } else {
      return Response.internalServerError();
    }
  }

  Future<Response> _getFileHandler(
      Request request, String folder, String file) async {
    var path = p.join((await getApplicationDocumentsDirectory()).path,
        "frosthaven", "audio", "output");
    File f = File(p.join(path, Uri.decodeFull(folder), Uri.decodeFull(file)));
    // print(f.path);
    if (await f.exists()) {
      return Response.ok(await f.readAsBytes(),
          headers: {"Content-Type": "audio/mp3"});
    } else {
      return Response.notFound("File not found");
    }
  }

  Future<Response> _playFileHandler(
      Request request, String folder, String file) async {
    _gameState.playAudio(folder, file);
    return Response.ok("");
  }

  Response _getStateHandler(Request request) {
    Map<String, int> elements = {};
    var elementState = _gameState.elementState;
    for (var key in elementState.keys) {
      int value = 0;
      switch (elementState[key]!) {
        case ElementState.inert:
          value = 0;
          break;
        case ElementState.half:
          value = 1;
          break;
        case ElementState.full:
          value = 2;
          break;
      }
      elements[key.name] = value;
    }
    var state = '{'
        '"version": $VERSION,'
        '"level": ${_gameState.level.value}, '
        '"roundState": ${_gameState.roundState.value.index}, '
        '"round": ${_gameState.round.value}, '
        '"currentList": ${_gameState.currentList.toString()}, '
        '"elements":  ${json.encode(elements)}'
        '}';
    var hash = state.hashCode;
    return Response.ok(state,
        headers: {"hash": "$hash", "Content-Type": "application/json"});
  }

  Future<Response> _setSectionHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    var section = info["section"];
    var scenario = _gameState.scenario.value;
    var regexp = RegExp(r'#([^\s]+)\s(.*)');
    RegExpMatch? match = regexp.firstMatch(scenario);
    if (match != null) {
      var number = match[1];
      var name = match[2];
      var key = "#$section $name ($number)";
      print("Adding section $key");
      try {
        _gameState.action(SetScenarioCommand(key, true));
      } catch (e) {
        return Response.notFound("Section not found in scenario");
      }
      return Response.ok("");
    } else {
      return Response.notFound("");
    }
  }

  Future<Response> _setScenarioHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    if (data != null) {
      Map<String, dynamic> info = jsonDecode(data);
      var scenario = info["scenario"];
      var campaign = info["campaign"] ?? "Frosthaven";
      print("$scenario / $campaign");
      GameMethods.setCampaign(campaign);
      _gameState.action(SetScenarioCommand(scenario, false));
      return Response.ok("");
    }
    return Response.notFound("");
  }

  Future<Response> _applySetElementHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    var element = Elements.fromString(info["element"]);
    var state = info["state"];
    print("element : $element, state: $state");
    if (element != null && state != null) {
      switch (state) {
        case 0:
          _gameState.action(UseElementCommand(element));
          break;
        case 1:
          _gameState.action(ImbueElementCommand(element, true));
          break;
        case 2:
          _gameState.action(ImbueElementCommand(element, false));
      }
    }
    return _getStateHandler(request);
  }

  Target? findTarget(String target, int nr) {
    // A bit of hackery for targets which include their number in their name
    // eg. Shambling Skeletons and Brothers in #87
    if (target.substring(target.length - 2, target.length - 1) == " " &&
        "123456789".contains(target.substring(target.length - 1))) {
      nr = int.parse(target.substring(target.length - 1));
      target = target.substring(0, target.length - 2);
    }
    print("findTarget target:$target, nr:$nr");
    for (var item in _gameState.currentList) {
      if (item is Monster) {
        // startsWith lets us handle (FH) and scenario specific monsters without
        // special naming on the tabletop side
        if (item.id.startsWith(target)) {
          for (var instance in item.monsterInstances.value) {
            if (instance.standeeNr == nr ||
                (instance.type == MonsterType.boss && nr == 0)) {
              var stats = item.type.levels.firstWhere(
                  (element) => element.level == instance.level.value);
              var level;
              switch (instance.type) {
                case MonsterType.normal:
                  level = stats.normal;
                  break;
                case MonsterType.elite:
                  level = stats.elite;
                  break;
                case MonsterType.boss:
                  level = stats.boss;
                  break;
              }
              return Target(level, instance, item.id, instance.getId());
            }
          }
        }
      } else if (item is Character) {
        print(item);
        // Special casing for Objectives & Targets
        // In some cases, where the nr is in the name, we need to reconstruct it
        // As we've split name and nr above.
        if (item.id == target || item.id == "$target $nr") {
          return Target(null, item.characterState, item.id, item.id);
        } else if (item.characterClass.name == target) {
          return Target(null, item.characterState, item.id, item.id);
        } else {
          // Look for the summons
          for (var summon in item.characterState.summonList.value) {
            print("summon : $summon");
            if (summon.name == target && summon.standeeNr == nr) {
              return Target(null, summon, item.id, summon.getId());
            }
          }
        }
      }
    }
    return null;
  }

  Future<Response> _applyConditionHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    String name = info["target"];
    var nr = info["nr"];
    var condition = Condition.fromString(info["condition"]);
    if (condition != null) {
      var target = findTarget(name, nr);
      if (target != null) {
        // Make sure the monster is not immune to the condition
        var model = target.model;
        if (model != null) {
          if (model.immunities.contains("%${condition.name}%")) {
            print("monster is immune to the condition, ignoring");
            return _getStateHandler(request);
          }
        }
        var conditions = target.state.conditions.value;
        if (!conditions.contains(condition)) {
          _gameState.action(
              AddConditionCommand(condition, target.id, target.ownerId));
        } else {
          _gameState.action(
              RemoveConditionCommand(condition, target.id, target.ownerId));
        }
      }
    }
    return _getStateHandler(request);
  }

  Future<Response> _applyChangeHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    String name = info["target"] ?? "";
    var nr = info["nr"] ?? 0;
    var what = info["what"] ?? "";
    var change = info["change"] ?? 0;
    var target = findTarget(name, nr);
    if (target != null) {
      if (what == "hp" || what == "health") {
        _gameState
            .action(ChangeHealthCommand(change, target.id, target.ownerId));
      } else if (what == "xp") {
        _gameState.action(ChangeXPCommand(change, target.id, target.ownerId));
      } else if (what == "level") {
        _gameState.action(SetCharacterLevelCommand(change, target.id));
      }
    }
    return _getStateHandler(request);
  }

  Future<Response> _startRoundHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> initiatives = jsonDecode(data);
    initiatives.forEach((key, value) {
      print("$key -> $value");
      _gameState.action(SetInitCommand(key, value));
    });
    if (GameMethods.canDraw()) {
      _gameState.action(DrawCommand());
    }
    return Response.ok('{}');
  }

  Future<Response> _setCurrentTurnHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    var name = info["name"];
    _gameState.action(TurnDoneCommand(name));
    return _getStateHandler(request);
  }

  Future<Response> _endRoundHandler(Request request) async {
    _gameState.action(NextRoundCommand());
    return Response.ok('{}');
  }

  Future<Response> _addCharacterHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    var characterName = info["character"];
    _gameState.action(AddCharacterCommand(characterName, characterName, 1));
    return _getStateHandler(request);
  }

  Future<Response> _removeCharacterHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    var characterName = info["character"];
    var matchingCharacters = _gameState.currentList
        .where((e) => e is Character && e.id == characterName)
        .map((e) => e as Character);
    if (matchingCharacters.isNotEmpty) {
      _gameState.action(RemoveCharacterCommand(matchingCharacters.toList()));
    }
    return _getStateHandler(request);
  }

  Future<Response> _addMonsterHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    var monsterName = info["monster"];
    var isBoss = info["isBoss"];
    for (var item in _gameState.currentList) {
      if (item is Monster) {
        // startsWith lets us handle (FH) and scenario specific monsters without
        // special naming on the tabletop side
        if (item.id.startsWith(monsterName)) {
          int nrOfStandees = item.type.count;
          List<int> available = [];
          for (int i = 0; i < nrOfStandees; i++) {
            bool isAvailable = true;
            for (var item in item.monsterInstances.value) {
              if (item.standeeNr == i + 1) {
                isAvailable = false;
                break;
              }
            }
            if (isAvailable) {
              available.add(i + 1);
            }
          }
          int standeeNr = available[Random().nextInt(available.length)];
          _gameState.action(AddStandeeCommand(standeeNr, null, item.id,
              isBoss ? MonsterType.boss : MonsterType.normal, false));
          return Response.ok("$standeeNr");
        }
      }
    }

    return Response.notFound("");
  }

  Future<Response> _switchMonsterTypeHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    var monsterName = info["monster"];
    var number = int.parse(info["nr"]);
    print("Swapping monster $monsterName number $number");
    for (var item in _gameState.currentList) {
      if (item is Monster) {
        print(item);
        if (item.id.startsWith(monsterName)) {
          for (var monster in item.monsterInstances.value) {
            if (monster.standeeNr == number) {
              // Can't really swap as it messes up the stats, so special case
              // if hp == max, to remove a standee, and add a new one
              if (monster.health.value == monster.maxHealth.value) {
                var newType = monster.type == MonsterType.normal
                    ? MonsterType.elite
                    : MonsterType.normal;
                _gameState.action(
                    ChangeHealthCommand(-999, monster.getId(), item.id));
                _gameState.action(
                    AddStandeeCommand(number, null, item.id, newType, false));
                return Response.ok("");
              } else if (monsterName == "Ice Wraith") {
                _gameState.action(IceWraithChangeFormCommand(
                    monster.type == MonsterType.elite,
                    item.id,
                    monster.getId()));
              }
            }
          }
        }
      }
    }
    return Response.notFound("");
  }

  Future<Response> _lootHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    String name = info["target"];
    int count = info["count"] ?? 1;
    var target = findTarget(name, 0);
    if (target != null) {
      for (var i = 0; i < count; i++) {
        await Future.delayed(Duration(seconds: 1));
        _gameState.action(DrawLootCardCommand());
        LootCard card = _gameState.lootDeck.discardPile.getList().last;
        _gameState.action(SetLootOwnerCommand(target.ownerId, card));
      }
    }
    return Response.ok("");
  }

  Future<Response> _setLevelHandler(Request request) async {
    var data = Uri.decodeFull(await request.readAsString());
    Map<String, dynamic> info = jsonDecode(data);
    int level = info["level"] ?? 0;
    _gameState.action(SetLevelCommand(level, null));
    return _getStateHandler(request);
  }

  Future<Response> _getLootHandler(Request request) async {
    Map<String, Map<String, int>> charactersLoot = {};
    var characters = GameMethods.getCurrentCharacters();
    for (var character in characters) {
      charactersLoot[character.characterClass.name] = {};
    }
    for (var card in _gameState.lootDeck.discardPile.getList()) {
      var owner = card.owner;
      if (owner != null) {
        var characterLoot = charactersLoot[owner]!;
        var itemName = card.gfx;
        int value = 0;
        if (itemName.startsWith("coin")) {
          if (itemName.endsWith("3")) {
            value += 3;
          } else if (itemName.endsWith("2")) {
            value += 2;
          } else {
            value += 1;
          }
          itemName = "coin";
          value += card.enhanced;
        } else {
          value += card.getValue() ?? 0;
        }
        characterLoot[itemName] = value + (characterLoot[itemName] ?? 0);
      }
    }

    var output = charactersLoot.entries
        .map((c) =>
            '"${c.key}" : {${charactersLoot[c.key]!.entries.map((e) => '"${e.key}": ${e.value}').join(",")}}')
        .join(",");
    return Response.ok(
        '{"loot" : {$output}, "baseXp":${GameMethods.getXPValue()}, "coinValue" : ${GameMethods.getCoinValue()}}',
        headers: {"Content-Type": "application/json"});
  }

  Future<Response> _endScenarioHandler(Request request) async {
    _gameState.action(EndScenarioCommand());
    return _getStateHandler(request);
  }
}
