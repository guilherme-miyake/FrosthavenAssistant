import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Model/monster.dart';
import 'package:frosthaven_assistant/Resource/stat_calculator.dart';

import '../Resource/game_state.dart';

class LineBuilder {
  static const double tempScale = 0.8;

  static const Map<String, String> _tokens = {
    "attack": "Attack",
    "move": "Move",
    "range": "Range",
    "heal": "Heal",
    "target": "Target",
    "shield": "Shield",
    "loot": "Loot",
    "retaliate": "Retaliate",
    "jump": "Jump",
    "stun": "STUN",
    "wound": "WOUND",
    "disarm": "DISARM",
    "immobilize": "IMMOBILIZE",
    "poison": "POISON",
    "invisible": "INVISIBLE",
    "strengthen": "STRENGTHEN",
    "muddle": "MUDDLE",
    "regenerate": "REGENERATE",
    "ward": "WARD",
    "impair": "IMPAIR",
    "bane": "BANE",
    "brittle": "BRITTLE",
    "chill": "CHILL",
    "infect": "INFECT",
    "rupture": "RUPTURE",
    "push": "PUSH",
    "pull": "PULL",
    "pierce": "PIERCE",
    "curse": "CURSE",
    "bless": "BLESS",
    "and": "and"
  };

  static double _getIconHeight(String iconToken, double height) {
    if (iconToken == "air" ||
        iconToken == "earth" ||
        iconToken == "fire" ||
        iconToken == "ice" ||
        iconToken == "dark" ||
        iconToken == "light"||
        iconToken == "any"
    ) {
      return height * 1.2;
    }
    if (iconToken.contains("aoe")) {
      return height * 2;
    }
    return height;
  }

  static EdgeInsetsGeometry _getMarginForToken(String iconToken, double height,
      bool mainLine, CrossAxisAlignment alignment) {
    double margin = 0.5;
    if (alignment != CrossAxisAlignment.center) {
      margin = 0.1;
    }
    if (iconToken.contains("aoe")) {
      return EdgeInsets.only(left: margin * height, right: margin * height);
    }
    if (mainLine &&
        (iconToken == "attack" ||
            iconToken == "heal" ||
            iconToken == "loot" ||
            iconToken == "shield" ||
            iconToken == "move")) {
      return EdgeInsets.only(left: margin * height, right: margin * height);
    }
    if (iconToken == "air" ||
        iconToken == "earth" ||
        iconToken == "fire" ||
        iconToken == "ice" ||
        iconToken == "dark" ||
        iconToken == "light"||
    iconToken == "any"
    ) {
      return EdgeInsets.only(
          top: 0.19 * height); //since icons lager, need lager margin top
    }
    return EdgeInsets.zero;
  }

  static List<Map<String, int>> _getStatTokens(Monster monster, bool elite) {
    List<Map<String, int>> values = [];
    MonsterStatsModel data;
    if (monster.type.levels[monster.level.value].boss != null) {
      //is boss
      if (elite) {
        return values;
      }
      data = monster.type.levels[monster.level.value].boss!;
    } else {
      if (elite) {
        data = monster.type.levels[monster.level.value].elite!;
      } else {
        data = monster.type.levels[monster.level.value].normal!;
      }
    }
    for (String item in data.attributes) {
      if (item.substring(0, 1) == "%") { //expects token to be first in line. is this ok?
        //parse item and then parse number;
        for (int i = 1; i < item.length; i++) {
          if (item[i] == '%') {
            String token = item.substring(1, i);
            int number = 0;
            if (i != item.length - 1)
            {
              for (int j = i+2; j < item.length; j++){
                if(item[j] == ' ' || j == item.length-1){
                  //need to find end of nr and ignore the rest
                  String nr = item.substring(i + 1, j+1);
                  int? res = StatCalculator.calculateFormula(nr);
                  if(res != null){
                    number = res;
                  }else {
                    if(kDebugMode) {
                      print("failed calculation for formula: " + nr +  "for token: "+ token);

                    }
                  }
                  break;
                }
              }

            }
            var map = <String, int>{};
            map[token] = number;
            values.add(map);
            break; //only one token added per line
          }
        }
      }
    }
    return values;
  }

  static List<String> _applyStatForToken(
      String formula,
      String line,
      String sizeModifier,
      int startIndex,
      int endIndex,
      Monster monster,
      bool showMinimal,
      String lastToken,
      List<Map<String, int>> normalTokens,
      List<Map<String, int>> eliteTokens) {
    List<String> retVal = [];
    List<String> tokens = [];
    List<String> eTokens = [];
    int normalValue = 0;
    int eliteValue = 0;
    bool skipCalculation = false; //in case uncalculable
    MonsterStatsModel? normal = monster.type.levels[monster.level.value].boss ??
        monster.type.levels[monster.level.value].normal;
    MonsterStatsModel? elite = monster.type.levels[monster.level.value].elite;
    if (lastToken == "attack") {
      int? calc = StatCalculator.calculateFormula(normal!.attack);
      if(calc != null) {
        normalValue = calc;
      } else {
        skipCalculation = true;
      }
      if (elite != null) {
        calc = StatCalculator.calculateFormula(elite.attack);
        if(calc != null) {
          eliteValue = calc;
        }
      }

      RegExp regEx =
          RegExp(r"(?=.*[a-z])"); //not sure why I fdo this. only letters?
      for (var item in normalTokens) {
        if (regEx.hasMatch(item.keys.first) == true) {
          if (item.keys.first != "shield" &&
              item.keys.first != "retaliate" &&
              item.keys.first != "jump") {
            tokens.add("%${item.keys.first}%");
          }
        }
      }
      for (var item in eliteTokens) {
        if (regEx.hasMatch(item.keys.first) == true) {
          if (item.keys.first != "shield" &&
              item.keys.first != "retaliate" &&
              item.keys.first != "jump") {
            eTokens.add("%${item.keys.first}%");
          }
        }
      }
    } else if (lastToken == "range") {
      if (normal?.range != 0) {
        normalValue = normal!.range;
        if (elite != null) {
          eliteValue = elite.range;
        }
      }
    } else if (lastToken == "move") {
      normalValue = StatCalculator.calculateFormula(normal!.move)!;
      if (elite != null) {
        eliteValue = eliteValue = StatCalculator.calculateFormula(elite.move)!;
      }
      //TODO: add jump if has innate jump
    }

    //TODO: handle shield, jump and add target. heal. maybe retaliate??
    else if (lastToken == "shield") {
      //TOOD: at least this is needed
    } else if (lastToken == "target") {
    } else if (lastToken == "retaliate") {
    } else if (lastToken == "jump") {
    } else if (lastToken == "heal") {}
    String normalResult = formula;
    if (!skipCalculation) {
      int res = StatCalculator.calculateFormula(formula + "+" + normalValue.toString())!;
      if (res < 0) {
        res = 0; //needed for blood tumor: has 0 move and a -1 move card
      }
      normalResult = res.toString();
    }

    String newStartOfLine =
        line.substring(0, startIndex) + normalResult;
    if (!skipCalculation) {
      for (var item in tokens) {
        newStartOfLine += "|" + item;
      }
    }

    if (elite != null && !skipCalculation) {
      newStartOfLine += "/";
      retVal.add(newStartOfLine);

      int eliteResult = StatCalculator.calculateFormula(
          formula + "+" + eliteValue.toString())!;
      if (eliteResult < 0) {
        eliteResult = 0;
      }
      String eliteString = "!" + sizeModifier + "£" + eliteResult.toString();
      for (var item in eTokens) {
        eliteString += "|" + item;
      }
      retVal.add(eliteString);
    } else {
      retVal.add(newStartOfLine);
    }
    if (endIndex < line.length) {
      String leftOver =
          "!" + sizeModifier + line.substring(endIndex + 1, line.length);

      //retVal.addAll(applyMonsterStats(leftOver, sizeToken, monster)); //TODO
      retVal.add(leftOver);
    }
    return retVal;
  }

  static List<String> _applyMonsterStats(
      final String lineInput, String sizeToken, Monster monster) {
    String line = "" + lineInput; //make sure lineInput is not altered
    if (kDebugMode) {
      print("monster: ${monster.id}");
      print("line: $line");
    }

    List<String> retVal = [];

    //get the data
    var normalTokens = _getStatTokens(monster, false);
    var eliteTokens = _getStatTokens(monster, true);

    RegExp regExpNumbers = RegExp(r'^[\d ()xCL/*+-]+$');
    //first pass fix values only
    String lastToken =
        ""; //turn this into move or attack or whatever, then apply correct monster stat
    bool isInToken = false;
    int tokenStartIndex = 0;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == "%") {
        if (!isInToken) {
          isInToken = true;
          tokenStartIndex = i + 1;
        } else {
          isInToken = false;
          lastToken = line.substring(tokenStartIndex, i);
        }
      }
      if (!isInToken &&
                  (line[i] == '+' ||
                      line[i] == '-' ||
                      line[i] == 'C' ||
                      line[i] == 'L') ||
              (line[i].contains(regExpNumbers) &&
                      lastToken
                          .isEmpty) //plain numbers cant be calculated for tokens (e.g. attack 1 is not same as attack +1)
                  &&
                  (i == 0 ||
                      line[i - 1] ==
                          ' ') //supposing there is always a leading whitespace to any formula
          ) {
        String formula = line[i];
        int startIndex = i;
        int endIndex = i;

        for (int j = i + 1; j < lineInput.length; j++) {
          String val = lineInput[j];
          if (val.contains(regExpNumbers)) {
            if (val != ' ') formula += val;
            endIndex = j;
          } else {
            i = j; //skip ahead
            if (lineInput[i - 1] == ' ') {
              i = j - 1; //restore any skipped whitespace
              endIndex = endIndex - 1;
            }
            //hack for when a formula is followed by " (..."
            if (i > 0 && lineInput[i - 1] == '(') {
              i = j - 1; //restore any skipped (
              endIndex = endIndex - 1;
              formula = formula.substring(0, formula.length - 1);
              if (i > 1 && lineInput[i - 2] == ' ') {
                i = j - 1; //restore any skipped whitespace
                endIndex = endIndex - 1;
              }
            }
            break;
          }
        }
        if (formula.length > 1 && lastToken.isNotEmpty || formula.length > 2) {
          //this disallows a single digit or C,L. single C or L could be part of regular text
          //for a formula to work (oustside of plain C or L) it must either be modifying a token vslue or be 3+ chars long
          //might not be right. test.
          if (kDebugMode) {
            print("formula:$formula");
          }

          if (lastToken.isNotEmpty) {
            retVal = _applyStatForToken(
              formula,
              line,
              sizeToken,
              startIndex,
              endIndex,
              monster,
              false,
              lastToken,
              normalTokens,
              eliteTokens,
            );
            lastToken = "";
            if (retVal.isNotEmpty) {
              return retVal;
            }
          } else {
            int result = StatCalculator.calculateFormula(formula)!;
            if (result < 0) {
              //just some nicety. probably never applies
              result = 0;
            }
            line =
                line.replaceRange(startIndex, endIndex + 1, result.toString());
          }
        }
      }
    }

    return [line];
  }

  static Widget createLines(List<String> strings, bool left, bool applyStats,
      Monster monster, CrossAxisAlignment alignment, double scale) {
    var shadow = Shadow(
        offset: Offset(1 * scale * tempScale, 1 * scale * tempScale),
        color: left ? Colors.white : Colors.black);
    var dividerStyle = TextStyle(
        fontFamily: 'Majalla',
        color: left ? Colors.black : Colors.white,
        fontSize: 8 * tempScale * scale,
        letterSpacing: 2 * tempScale * scale,
        height: 0.7,
        shadows: [shadow]);

    var smallStyle = TextStyle(
        fontFamily: 'Majalla',
        color: left ? Colors.black : Colors.white,
        fontSize: (alignment == CrossAxisAlignment.center ? 11 : 12) *
            tempScale *
            scale,
        //sizes are larger on stat cards
        height: 0.85,
        shadows: [shadow]);
    var midStyle = TextStyle(
        fontFamily: 'Majalla',
        color: left ? Colors.black : Colors.white,
        fontSize: (alignment == CrossAxisAlignment.center ? 12.7 : 13) *
            tempScale *
            scale,
        //sizes are larger on stat cards
        height: 0.9,
        shadows: [shadow]);
    var normalStyle = TextStyle(
        //maybe slightly bigger between chars space?
        fontFamily: 'Majalla',
        color: left ? Colors.black : Colors.white,
        fontSize: (alignment == CrossAxisAlignment.center ? 15.7 : 14) *
            tempScale *
            scale,
        height: 0.8,
        shadows: [shadow]);

    var eliteStyle = TextStyle(
        //maybe slightly bigger between chars space?
        fontFamily: 'Majalla',
        color: Colors.yellow,
        fontSize: 15.7 * tempScale * scale,
        height: 0.8,
        shadows: [shadow]);

    var eliteSmallStyle = TextStyle(
        fontFamily: 'Majalla',
        color: Colors.yellow,
        fontSize: 11 * tempScale * scale,
        height: 0.8,
        shadows: [shadow]);
    var eliteMidStyle = TextStyle(
        fontFamily: 'Majalla',
        color: Colors.yellow,
        fontSize: 12.7 * tempScale * scale,
        height: 0.9,
        shadows: [shadow]);

    List<Text> lines = [];
    List<String> localStrings = [];
    localStrings.addAll(strings);
    List<InlineSpan> lastLineTextPartList = [];
    for (int i = 0; i < localStrings.length; i++) {
      String line = localStrings[i];
      String sizeToken = "";
      bool isRightPartOfLastLine = false;
      var styleToUse = normalStyle;
      //because most stat card txt should use mid style but not specified in data:
      /*if(alignment != CrossAxisAlignment.center) {
      styleToUse = midStyle;
    }*/
      //fixed in data side, as should be
      List<InlineSpan> textPartList = [];
      if (line.startsWith('!')) {
        //add as
        isRightPartOfLastLine = true;
        line = line.substring(1, line.length);
      }
      if (line.startsWith('*')) {
        sizeToken = '*';
        styleToUse = smallStyle;
        line = line.substring(1, line.length);
        if (line.startsWith("....")) {
          styleToUse = dividerStyle;
        }
      }
      if (line.startsWith('^')) {
        sizeToken = '^';
        styleToUse = midStyle;
        line = line.substring(1, line.length);
      }
      if (applyStats) {
        List<String> statLines = _applyMonsterStats(line, sizeToken, monster);
        line = statLines.removeAt(0);
        if (statLines.length > 0) {
          localStrings.insertAll(i + 1, statLines);
        }
      }

      int partStartIndex = 0;
      bool isIconPart = false;
      bool addText = true;
      for (int i = 0; i < line.length; i++) {
        if (line[i] == "|") {
          //don't add text for conditions added with calculations
          addText = false;
        }
        if (line[i] == '%') {
          //TODO: show / and elite values in yellow only if elites available and vice versa for normals
          //TODO: do for all conditions + jump, pierce, add target  etc.

          if (isIconPart) {
            //create token part
            String iconToken = line.substring(partStartIndex, i);
            String iconGfx = iconToken;
            if (left) {
              RegExp regEx = RegExp(
                  r"(?=.*[a-z])"); //black versions exist for all tokens containing lower case letters
              if (regEx.hasMatch(_tokens[iconToken]!) == true) {
                iconGfx += "-medium-black";
              }
            }
            if (iconToken == "use") {
              //put use gfx on top of previous and add ':'
              WidgetSpan part = textPartList.removeLast() as WidgetSpan;
              Image lastImage = (part.child as Container).child as Image;
              textPartList.add(WidgetSpan(
                  //alignment: PlaceholderAlignment.top,
                  style: styleToUse, //this is wrong here
                  child: Container(
                    color: Colors.amber,
                    //margin: margin,
                    child: Stack(
                    children: [
                      lastImage,
                      Image(
                        height: styleToUse.fontSize! * 1.2,
                        //alignment: Alignment.topCenter,
                        image:
                            AssetImage("assets/images/abilities/$iconGfx.png"),
                      )
                    ],
                  ))));
              textPartList.add(TextSpan(
                  text: ": ", style: styleToUse));
            } else {
              double height = _getIconHeight(iconToken, styleToUse.fontSize!);
              if (addText) {
                String? iconTokenText = _tokens[iconToken];
                textPartList
                    .add(TextSpan(text: iconTokenText, style: styleToUse));
              }
              bool mainLine = styleToUse == normalStyle;
              EdgeInsetsGeometry margin =
                  _getMarginForToken(iconToken, height, mainLine, alignment);
              if (iconToken == "move" && monster.type.flying) {
                iconGfx = "flying";
              }
              Widget child = Image(
                //fit: BoxFit.fill,
                //could do funk stuff with the color value for cool effects maybe?
                height: height, //TODO: this causes lines to have variable height
                //alignment: Alignment.topCenter,
                image: AssetImage("assets/images/abilities/$iconGfx.png"),
              );
              child = Container(
                ///height: height,// * 0.8,
                //color: Colors.amber,
                margin: margin,
                child: child,
              );

              //TODO: make a solid solution. not a house of cards.
              double wtf = 0.8;
              if(height == styleToUse.fontSize! * 1.2) { //is element height
                wtf = 1.8; //wtf for elements alignment
              }
              //wtf = 1;

              textPartList.add(WidgetSpan(
                  style: TextStyle(
                      //height: styleToUse.height!*5,
                    //backgroundColor: Colors.blueGrey,
                     // textBaseline: TextBaseline.ideographic,
                   // decoration: TextDecoration.lineThrough,
                    //overflow: TextOverflow.visible,
                   // decorationColor: Colors.blueGrey,
                    //leadingDistribution: TextLeadingDistribution.even,

                      fontSize: styleToUse.fontSize! * wtf),
                  //styleToUse, //don't ask (probably because height is 0.8
                  child: child));
            }
            isIconPart = false;
            addText = true;
          } else {
            //create part up to now if length more than 0
            if (i > 0 && partStartIndex < i) {
              String textPart = line.substring(partStartIndex, i);
              if (i > 0 && line[i - 1] == "|") {
                //voi ei. remove the | from output. would be nice to find better place to do this
                textPart = line.substring(partStartIndex, i - 1);
              }

              textPartList.add(TextSpan(text: textPart, style: styleToUse));
            }
            isIconPart = true;
          }
          partStartIndex = i + 1;
        }
        if (line[i] == "£") {
          //finish current part
          partStartIndex = i + 1;
          if (styleToUse == normalStyle) {
            styleToUse = eliteStyle;
          } else if (styleToUse == smallStyle) {
            styleToUse = eliteSmallStyle;
          } else if (styleToUse == midStyle) {
            styleToUse = eliteMidStyle;
          }
        }
      }

      if (partStartIndex < line.length) {
        String textPart = line.substring(partStartIndex, line.length);
        textPartList.add(TextSpan(text: textPart, style: styleToUse));
      }
      TextAlign textAlign = TextAlign.center;
      if (alignment == CrossAxisAlignment.start) {
        textAlign = TextAlign.start;
      }
      if (alignment == CrossAxisAlignment.end) {
        textAlign = TextAlign.end;
      }
      var text = Text.rich(
        textHeightBehavior: const TextHeightBehavior(
          leadingDistribution: TextLeadingDistribution.even
        ),
        textAlign: textAlign,
        TextSpan(
          children: textPartList,
        ),
      );
      if (isRightPartOfLastLine) {
        lines.removeLast();
        textPartList.insertAll(0, lastLineTextPartList);
        text = Text.rich(
          textHeightBehavior: const TextHeightBehavior(
              leadingDistribution: TextLeadingDistribution.even
          ),
          textAlign: textAlign,
          TextSpan(
            children: textPartList,
          ),
        );
        lines.add(text);
      } else {
        lines.add(text);
      }
      lastLineTextPartList = textPartList;
    }
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.max,
        children: lines);
  }
}
