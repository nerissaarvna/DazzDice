import 'dart:convert';
import 'package:dice_client/providers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dice_client/model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math';
import 'package:provider/provider.dart';

class DiceModel with ChangeNotifier {
  int _dice1 = 6;
  int _dice2 = 6;
  int get dice1 => _dice1;
  int get dice2 => _dice2;

  void setDices(int d1, int d2) {
    _dice1 = d1;
    _dice2 = d2;
    notifyListeners();
  }

  void roll() {
    _dice1 = Random().nextInt(6) + 1;
    _dice2 = Random().nextInt(6) + 1;
    notifyListeners();
  }
}

class VsPlayerPage extends StatefulWidget {
  const VsPlayerPage({super.key});

  @override
  State<VsPlayerPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<VsPlayerPage> with TickerProviderStateMixin {
  static const Duration _timerDuration = Duration(seconds: 10);
  final ValueNotifier<int> _count = ValueNotifier<int>(5);
  final ValueNotifier<bool> _answer1Locked = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _answer2Locked = ValueNotifier<bool>(false);
  final ValueNotifier<List<int>> _options = ValueNotifier<List<int>>([]);
  final List<int> _scores1 = [];
  final List<int> _scores2 = [];
  final ValueNotifier<int?> _score1D = ValueNotifier<int?>(null);
  final ValueNotifier<int?> _score2D = ValueNotifier<int?>(null);
  final ValueNotifier<int?> _selectedOption = ValueNotifier<int?>(null);
  final ValueNotifier<int> _round = ValueNotifier<int>(1);
  final ValueNotifier<int> _score1 = ValueNotifier<int>(0);
  final ValueNotifier<int> _score2 = ValueNotifier<int>(0);
  final ValueNotifier<int?> _answer1 = ValueNotifier<int?>(null);
  final ValueNotifier<int?> _answer2 = ValueNotifier<int?>(null);
  final ValueNotifier<bool?> _result1 = ValueNotifier<bool?>(null);
  final ValueNotifier<bool?> _result2 = ValueNotifier<bool?>(null);
  final DiceModel _diceModel = DiceModel();
  bool _hasResult = false;
  final ValueNotifier<bool?> _timesup = ValueNotifier<bool?>(null);
  final ColorTween _colorTween = ColorTween(begin: Colors.red, end: Colors.green);
  late AnimationController _timerBarController;
  DataEvent? _dataEvent;
  int i = 0;
  double rDx1 = 0;
  double rDx2 = 0;
  bool _rolling = false;

  late WebSocketChannel _channelArena;
  late MatchProvider _matchProvider;
  late UserProvider _userProvider;

  Future<void> _rollDice() async {
    _rolling = true;
    while (!_hasResult) {
      _diceModel.roll();
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _countDown() async {
    for (int i = 1; i < 6; i++) {
      await Future.delayed(const Duration(seconds: 1));
      _count.value--;
    }
    _rollDice();

    await Future.delayed(const Duration(seconds: 1));
    _count.value--;

    await Future.delayed(const Duration(seconds: 2));
    _diceModel.setDices(_matchProvider.question!.num1, _matchProvider.question!.num2);

    _hasResult = true;
    _rolling = false;
    _options.value = (_matchProvider.question!.wrong!..add(_matchProvider.question!.answer!))..shuffle();

    _matchProvider.notify();
    _timerBarController.reverse();
  }

  Widget _cardInfo(User user, int no) {
    return SizedBox(
      width: 200,
      height: 80,
      child: Card(
        clipBehavior: Clip.hardEdge,
        color: Colors.blueAccent,
        shadowColor: (_userProvider.user.id == user.id) ? Colors.white : null,
        elevation: 16,
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: Column(
            children: [
              Center(
                child: Text(
                  user.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              Center(
                child: Text(
                  user.matchLeaderboard?.rating?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              Builder(builder: (context) {
                if (no == 1) {
                  return ValueListenableBuilder(
                    valueListenable: _score1,
                    builder: (context, value, _) {
                      return Text('Score $value');
                    },
                  );
                } else if (no == 2) {
                  return ValueListenableBuilder(
                    valueListenable: _score2,
                    builder: (context, value, _) {
                      return Text('Score $value');
                    },
                  );
                }

                return const SizedBox();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timerWidget() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        ValueListenableBuilder(
          valueListenable: _round,
          builder: (context, value, _) {
            return Text("Round: $value/${_matchProvider.match.round}");
          },
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _timerBarController,
            builder: (context, _) {
              var curDur = _timerDuration * _timerBarController.value;
              return Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: LinearProgressIndicator(
                      value: _timerBarController.value,
                      valueColor: _colorTween.animate(_timerBarController),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Stack(
                      children: [
                        Text(
                          '${curDur.inSeconds}.${(curDur.inMilliseconds % 1000).toString().padLeft(3, "0")}',
                          style: TextStyle(
                            fontSize: 18,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 3
                              ..color = Colors.black,
                          ),
                        ),
                        Text(
                          '${curDur.inSeconds}.${(curDur.inMilliseconds % 1000).toString().padLeft(3, "0")}',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    _timerBarController = AnimationController(vsync: this, duration: _timerDuration, value: 1)
      ..addListener(() {
        if (_timerBarController.value == 0) {
          _timesup.value = true;
          _dataEvent!.event = "answer";
          _dataEvent!.params!["answer"] = -99999;
          _dataEvent!.params!['remaining_seconds'] = _timerBarController.value * _timerDuration.inSeconds;
          _channelArena.sink.add(jsonEncode(_dataEvent!.toJson()));
        }
      });
    _matchProvider = Provider.of<MatchProvider>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _channelArena = WebSocketChannel.connect(
        Uri.parse("$WSENDPOINT/arena?id=${_userProvider.user.id}&match_id=${_matchProvider.match.id}"));

    _channelArena.stream.listen((event) {
      if (event != null) {
        _dataEvent = DataEvent.fromJson(jsonDecode(event));
        if (_dataEvent!.event == "done") {
        } else if (_dataEvent!.event == "question") {
          _matchProvider.setQuestion(Question.fromJson(_dataEvent!.params!['question']));
          _round.value = _matchProvider.question!.difficulty;
          _countDown();
        } else if (_dataEvent!.event == "answer") {
          var result = _dataEvent!.params!["result"];
          if (result["player1_a"] == -99999) {
            _answer1.value = -99999;
            _scores1.add(0);
          } else {
            if (result["score1"] > 0) {
              _result1.value = true;
              _score1.value += result["score1"] as int;
              _score1D.value = result["score1"] as int;
              _scores1.add(result["score1"] as int);
            } else {
              _scores1.add(0);
              _result1.value = false;
            }
            _answer1.value = result["player1_a"];
          }
          if (result["player2_a"] == -99999) {
            _answer2.value = -99999;
            _scores2.add(0);
          } else {
            if (result["score2"] > 0) {
              _result2.value = true;
              _score2.value += result["score2"] as int;
              _score2D.value = result["score2"] as int;
              _scores2.add(result["score2"] as int);
            } else {
              _scores2.add(0);
              _result2.value = false;
            }
            _answer2.value = result["player2_a"];
          }

          _answer1Locked.value = false;
          _answer2Locked.value = false;

          Future.delayed(
            const Duration(seconds: 2),
            (() {
              _timesup.value = null;
              _options.value = [];
              _timerBarController.value = 1;
              _count.value = 5;
              _score1D.value = null;
              _score2D.value = null;
              _hasResult = false;
              _selectedOption.value = null;
              _answer1.value = null;
              _answer2.value = null;
              _result1.value = null;
              _result2.value = null;
              _matchProvider.clearQuestion();
              _dataEvent!.event = "end";
              _channelArena.sink.add(jsonEncode(_dataEvent!.toJson()));
            }),
          );
        } else if (_dataEvent!.event == "has_locked") {
          if (_userProvider.user.id == _matchProvider.match.player1Id) {
            _answer2Locked.value = true;
          } else if (_userProvider.user.id == _matchProvider.match.player2Id) {
            _answer1Locked.value = true;
          }
        } else if (_dataEvent!.event == "end") {
          Match match = Match.fromJson(_dataEvent!.params!["match"]);
          int oldRating = _userProvider.user.matchLeaderboard?.rating ?? 0;
          int newRating = 0;

          if (_userProvider.user.id == _matchProvider.match.player1Id) {
            newRating = match.player1?.matchLeaderboard?.rating ?? 0;
          } else if (_userProvider.user.id == _matchProvider.match.player2Id) {
            newRating = match.player2?.matchLeaderboard?.rating ?? 0;
          }

          String status = '';
          if (_score1.value > _score2.value) {
            if (_userProvider.user.id == _matchProvider.match.player1Id) {
              status = "You Win";
            } else {
              status = "You Lose";
            }
          } else if (_score1.value < _score2.value) {
            if (_userProvider.user.id == _matchProvider.match.player2Id) {
              status = "You Win";
            } else {
              status = "You Lose";
            }
          } else {
            status = "Draw";
          }
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return SizedBox(
                width: 300,
                height: 300,
                child: AlertDialog(
                  title: Text(status),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        context.pop();
                        context.pop();
                      },
                      child: const Text("Exit"),
                    )
                  ],
                  content: SizedBox(
                    height: 300,
                    width: 300,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const Text("Rating"),
                        Text("$oldRating -> $newRating"),
                        Table(
                          border: const TableBorder(verticalInside: BorderSide()),
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide())),
                              children: [
                                Text(_matchProvider.match.player1!.name),
                                Text(_matchProvider.match.player2!.name)
                              ],
                            ),
                            ...List<int>.from(List.generate(_scores1.length, (index) => index)).map(
                              (e) => TableRow(children: [
                                Text(_scores1[e].toString()),
                                Text(_scores2[e].toString()),
                              ]),
                            ),
                            TableRow(
                              decoration: const BoxDecoration(border: Border(top: BorderSide())),
                              children: [
                                Text(_score1.value.toString()),
                                Text(
                                  _score2.value.toString(),
                                )
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
      }
    });

    _channelArena.sink.add(jsonEncode({
      "event": "ready",
    }));

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.red.shade300,
        body: Consumer<MatchProvider>(builder: (context, match, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: ListenableBuilder(
                      listenable: _diceModel,
                      builder: (context, _) {
                        double rDy = 0;
                        double turns = 0;
                        int duration = 500;
                        if (_rolling) {
                          rDy = Random().nextDouble() * -1.0;
                          if (rDx1 > 0) {
                            rDx1 = Random().nextDouble() * -1;
                          } else {
                            rDx1 = Random().nextDouble() * 1;
                          }
                          if (rDx1 < -0.8 || rDx1 > 0.8) {
                            if (rDx1 < -0.8) {
                              turns = (rDx1 * -5);
                            } else {
                              turns = -(rDx1 * 5);
                            }
                          } else if (rDx1 < 0) {
                            turns = (rDx1 * -3).clamp(1, 2);
                          } else {
                            turns = (-(rDx1 * 3)).clamp(-2.0, -1.0);
                          }
                        }
                        if (!_rolling) {
                          rDx1 = 0;
                          rDy = 0;
                          duration = 250;
                        }
                        return AnimatedSlide(
                          offset: Offset(rDx1, rDy),
                          duration: Duration(milliseconds: duration),
                          child: AnimatedRotation(
                            turns: turns,
                            duration: Duration(milliseconds: duration),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Image(
                                key: ValueKey(Random().nextDouble()),
                                image: AssetImage('assets/images/dices/dice_${_diceModel.dice1}.png'),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Builder(
                      builder: (context) {
                        if (match.question != null) {
                          return Center(
                            child: Text(
                              match.question!.op,
                              style: const TextStyle(fontSize: 40, color: Colors.white),
                            ),
                          );
                        } else {
                          return ValueListenableBuilder(
                            valueListenable: _round,
                            builder: (context, round, _) {
                              return ValueListenableBuilder(
                                valueListenable: _count,
                                builder: (context, value, _) {
                                  Widget child = const SizedBox();

                                  if (value == 5) {
                                    return const SizedBox();
                                  } else if (value == -1) {
                                    child = const SizedBox();
                                  } else if (value == 4) {
                                    child = const Text(
                                      "Ready",
                                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                                    );
                                  } else if (value == 0) {
                                    child = const Text(
                                      "ROLL",
                                      style: TextStyle(fontSize: 50, fontWeight: FontWeight.w700, color: Colors.white),
                                    );
                                  } else {
                                    child = Text(
                                      value.toString(),
                                      style: const TextStyle(
                                          fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                                    );
                                  }

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      (value <= 0)
                                          ? const SizedBox()
                                          : Text(
                                              "Round $round",
                                              style: const TextStyle(
                                                  fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                                            ),
                                      AnimatedSwitcher(
                                        duration: (value == 0 || value == 4)
                                            ? const Duration(milliseconds: 0)
                                            : const Duration(milliseconds: 250),
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          );
                                        },
                                        child: Center(
                                          key: ValueKey<int>(value),
                                          child: child,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: ListenableBuilder(
                      listenable: _diceModel,
                      builder: (context, _) {
                        double rDy = 0;
                        double turns = 0;
                        int duration = 500;
                        if (_rolling) {
                          rDy = Random().nextDouble() * -1.0;
                          if (rDx2 > 0) {
                            rDx2 = Random().nextDouble() * -1;
                          } else {
                            rDx2 = Random().nextDouble() * 1;
                          }
                          if (rDx2 < -0.8 || rDx2 > 0.8) {
                            if (rDx2 < -0.8) {
                              turns = (rDx2 * -5);
                            } else {
                              turns = -(rDx2 * 5);
                            }
                          } else if (rDx2 < 0) {
                            turns = (rDx2 * -3).clamp(1, 2);
                          } else {
                            turns = (-(rDx2 * 3)).clamp(-2.0, -1.0);
                          }
                        }
                        if (!_rolling) {
                          rDx2 = 0;
                          rDy = 0;
                          duration = 250;
                        }
                        return AnimatedSlide(
                          offset: Offset(rDx2, rDy),
                          duration: Duration(milliseconds: duration),
                          child: AnimatedRotation(
                            turns: turns,
                            duration: Duration(milliseconds: duration),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Image.asset(
                                'assets/images/dices/dice_${_diceModel.dice2}.png',
                                key: ValueKey(Random().nextDouble()),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 80,
              ),
              Center(
                child: SizedBox(
                  height: 40,
                  child: ValueListenableBuilder(
                    valueListenable: (_userProvider.user.id == match.match.player1Id) ? _result1 : _result2,
                    builder: (context, result, _) {
                      return ValueListenableBuilder(
                        valueListenable: _options,
                        builder: (context, options, _) {
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            itemCount: options.length,
                            separatorBuilder: (context, index) {
                              return const SizedBox(
                                width: 50,
                              );
                            },
                            itemBuilder: (context, index) {
                              return ValueListenableBuilder(
                                valueListenable: _selectedOption,
                                builder: (context, value, _) {
                                  return SizedBox(
                                    width: 100,
                                    child: AnimatedOpacity(
                                      opacity: ((value == null || value == index) ||
                                              (result != null &&
                                                  (result == false && options[index] == match.question!.answer!)))
                                          ? 1
                                          : 0,
                                      duration: const Duration(milliseconds: 250),
                                      child: ElevatedButton(
                                        style: ButtonStyle(
                                          backgroundColor: MaterialStateProperty.resolveWith(
                                            (states) {
                                              bool isCorrect = (options[index] == match.question!.answer!);

                                              if (states.contains(MaterialState.disabled)) {
                                                if (result == null) {
                                                  return Colors.orange;
                                                } else if (isCorrect) {
                                                  return Colors.green;
                                                } else {
                                                  return Colors.red;
                                                }
                                              } else {
                                                return Colors.blue;
                                              }
                                            },
                                          ),
                                        ),
                                        onPressed: (value != null)
                                            ? null
                                            : () {
                                                if ((_userProvider.user.id == match.match.player1Id)) {
                                                  _answer1Locked.value = true;
                                                } else {
                                                  _answer2Locked.value = true;
                                                }
                                                _selectedOption.value = index;
                                                _timerBarController.stop();
                                                _dataEvent!.event = "answer";
                                                _dataEvent!.params!["answer"] = options[index];
                                                _dataEvent!.params!['remaining_seconds'] =
                                                    _timerBarController.value * _timerDuration.inSeconds;
                                                _channelArena.sink.add(jsonEncode(_dataEvent!.toJson()));
                                              },
                                        child: Text(options[index].toString(),
                                            style: const TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 80,
                        child: ValueListenableBuilder(
                          valueListenable: _answer1Locked,
                          builder: (context, value, _) {
                            if (value) {
                              return const Text(
                                "Answer Locked",
                                textAlign: TextAlign.center,
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 80,
                        child: ValueListenableBuilder(
                          valueListenable: _answer1,
                          builder: (context, value, _) {
                            if (value != null) {
                              if (value == -99999) {
                                return const Text("Time's Up");
                              } else {
                                return Text(
                                  "Answer: $value",
                                  textAlign: TextAlign.center,
                                );
                              }
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 100,
                        child: ValueListenableBuilder(
                          valueListenable: _result1,
                          builder: (context, value, _) {
                            if (value != null) {
                              if (value) {
                                return const Text(
                                  "Correct Answer",
                                  textAlign: TextAlign.center,
                                );
                              } else {
                                return const Text(
                                  "Wrong Answer",
                                  textAlign: TextAlign.center,
                                );
                              }
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 120,
                        child: ValueListenableBuilder(
                          valueListenable: _score1D,
                          builder: (context, value, _) {
                            if (value != null) {
                              return Text(
                                "+ $value",
                                textAlign: TextAlign.center,
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      _cardInfo(_matchProvider.match.player1!, 1),
                    ],
                  ),
                  Center(
                    child: SizedBox(
                      width: 500,
                      height: 100,
                      child: _timerWidget(),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 80,
                        child: ValueListenableBuilder(
                          valueListenable: _answer2Locked,
                          builder: (context, value, _) {
                            if (value) {
                              return const Text(
                                "Answer Locked",
                                textAlign: TextAlign.center,
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 80,
                        child: ValueListenableBuilder(
                          valueListenable: _answer2,
                          builder: (context, value, _) {
                            if (value != null) {
                              if (value == -99999) {
                                return const Text("Time's Up");
                              } else {
                                return Text(
                                  "Answer: $value",
                                  textAlign: TextAlign.center,
                                );
                              }
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 100,
                        child: ValueListenableBuilder(
                          valueListenable: _result2,
                          builder: (context, value, _) {
                            if (value != null) {
                              if (value) {
                                return const Text(
                                  "Correct Answer",
                                  textAlign: TextAlign.center,
                                );
                              } else {
                                return const Text(
                                  "Wrong Answer",
                                  textAlign: TextAlign.center,
                                );
                              }
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 120,
                        child: ValueListenableBuilder(
                          valueListenable: _score2D,
                          builder: (context, value, _) {
                            if (value != null) {
                              return Text(
                                "+ $value",
                                textAlign: TextAlign.center,
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                        ),
                      ),
                      _cardInfo(_matchProvider.match.player2!, 2),
                    ],
                  ),
                ],
              ),
            ],
          );
        }));
  }

  @override
  void dispose() {
    _channelArena.sink.close();
    _matchProvider.onDispose();
    super.dispose();
  }
}
