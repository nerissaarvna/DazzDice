import 'dart:async';
import 'dart:convert';
import 'package:dice_client/providers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dice_client/model.dart';
import 'dart:math';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

class SatuplayerPage extends StatefulWidget {
  const SatuplayerPage({super.key});

  @override
  State<SatuplayerPage> createState() => _SatuplayerPageState();
}

class _SatuplayerPageState extends State<SatuplayerPage> {
  final String _address = 'localhost';
  final String _port = "3000";
  bool _hasResult = false;
  final ValueNotifier<int> _count = ValueNotifier<int>(3);
  final ValueNotifier<int> _dice1 = ValueNotifier<int>(6);
  final ValueNotifier<int> _dice2 = ValueNotifier<int>(6);
  ValueNotifier<double> _timer = ValueNotifier<double>(1);
  bool _isRolling = false;
  late Timer timer;

  late WebSocketChannel _channelArena;

  Future<void> _rollDice() async {
    while (true) {
      await Future.delayed(
          Duration(milliseconds: 100 + Random().nextInt(250 - 50)));
      if (!_hasResult) {
        _dice1.value = Random().nextInt(6) + 1;
        _dice2.value = Random().nextInt(6) + 1;
      }
    }
  }

  Future<void> _countDown() async {
    for (int i = 1; i < 4; i++) {
      await Future.delayed(const Duration(seconds: 1), () {
        _count.value--;
      });
      print(_count.value);
    }
    _timerDown();

    _rollDice();
  }

  _timerDown() async {
    while (_timer.value > 0) {
      await Future.delayed(Duration(seconds: 1));
      _timer.value = _timer.value - 1 / 30;
    }
    _showTimerFinishedDialog();
  }

  void _showTimerFinishedDialog() {
    showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Color.fromARGB(255, 30, 30, 30),
            content: Container(
              width: 500,
              height: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                    child: Image(
                        width: 100,
                        image:
                            AssetImage('assets/images/emoticon/amazing.png')),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Text(
                    'Awesome!',
                    style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Kamu benar-benar hebat! Teruslah berlatih dan jadilah bintang cerdas di dunia perhitungan!',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          primary: Colors.pink.shade100,
                          fixedSize: Size(100, 40)),
                      onPressed: () {
                        context.pushNamed("lobby");
                      },
                      child: Text('OK',
                          style: TextStyle(fontSize: 22, color: Colors.white))),
                ],
              ),
            ),
          );
        });

    // setState(() {
    //   _isTimerRunning = false;
    // });
  }

  Widget _cardInfo(User user) {
    return SizedBox(
      width: 150.w,
      height: 250.h,
      child: Card(
        clipBehavior: Clip.hardEdge,
        color: Colors.blueAccent,
        shadowColor: (Provider.of<UserProvider>(context).user.id == user.id)
            ? Colors.white
            : null,
        elevation: 16,
        child: Padding(
          padding: EdgeInsets.only(left: 8.w, right: 8.w),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      "W: ${user.history?.win}",
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      "D: ${user.history?.draw}",
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      "L: ${user.history?.lose}",
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _endWidget(String text) {
    return Center(
      child: Column(
        children: [
          Text(
            text,
            style: const TextStyle(
                fontSize: 48, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          ElevatedButton(
              onPressed: () {
                context.pushReplacementNamed("lobby");
              },
              child: const Text("Back"))
        ],
      ),
    );
  }

  @override
  void initState() {
    _countDown();

    // _channelArena = WebSocketChannel.connect(Uri.parse(
    //     "ws://$_address:$_port/arena?id=${Provider.of<UserProvider>(context, listen: false).user.id}&match_id=${Provider.of<MatchProvider>(context, listen: false).match.matchId}"));

    // _channelArena.stream.listen((event) {
    //   if (event != null) {
    //     DataEvent data = DataEvent.fromJson(jsonDecode(event));
    //     if (data.event == "result") {
    //       _hasResult = true;
    //       Match match = Match.fromJson(data.params);
    //       Provider.of<MatchProvider>(context, listen: false).setMatch(match);
    //     }
    //   }
    // });
    // _match();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              fit: BoxFit.fill,
              image: AssetImage('assets/images/background/background2.png'),
            ),
          ),
          child: Stack(
            children: [
              ValueListenableBuilder(
                  valueListenable: _count,
                  builder: (context, value, _) {
                    if (value > 0) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                          child: Text(
                            value.toString(),
                            style: TextStyle(
                                fontSize: 56, fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    } else {
                      return SizedBox();
                    }
                  }),
              Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 40, 0, 0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              primary: Colors.pink.shade100,
                              padding: EdgeInsets.all(0),
                              fixedSize: Size(65, 65),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20))),
                          child: Icon(
                            Icons.home,
                            color: Colors.white,
                            size: 40,
                          ),
                          onPressed: () {
                            showDialog<String>(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor:
                                        Color.fromARGB(255, 30, 30, 30),
                                    content: Container(
                                      width: 350,
                                      height: 200,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                0, 20, 0, 0),
                                            child: Image(
                                                width: 50,
                                                image: AssetImage(
                                                    'assets/images/emoticon/suspicious.png')),
                                          ),
                                          SizedBox(
                                            height: 20,
                                          ),
                                          Text(
                                            'Are you sure?',
                                            style: TextStyle(
                                                fontSize: 24,
                                                color: Colors.white),
                                          ),
                                          SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                          primary: Colors
                                                              .pink.shade100,
                                                          fixedSize:
                                                              Size(100, 40)),
                                                  onPressed: () {
                                                    context.pop();
                                                    context.pop();
                                                  },
                                                  child: Text('Yes',
                                                      style: TextStyle(
                                                          fontSize: 22,
                                                          color:
                                                              Colors.white))),
                                              SizedBox(
                                                width: 20,
                                              ),
                                              ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                          primary: Colors
                                                              .blue.shade200,
                                                          fixedSize:
                                                              Size(100, 40)),
                                                  onPressed: () {
                                                    context.pop();
                                                  },
                                                  child: Text('No',
                                                      style: TextStyle(
                                                          fontSize: 22,
                                                          color: Colors.white)))
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                });
                          },
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 120, 0, 0),
                      child: SizedBox(
                        height: 24,
                        width: 360,
                        child: ValueListenableBuilder(
                          valueListenable: _timer,
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              backgroundColor: Colors.white,
                              value: value,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceAround,
              //   children: [
              //     _cardInfo(Provider.of<MatchProvider>(context, listen: false)
              //         .match
              //         .players
              //         .player1
              //         .player),
              //     _cardInfo(Provider.of<MatchProvider>(context, listen: false)
              //         .match
              //         .players
              //         .player2
              //         .player),
              //   ],
              // ),
              // Consumer<MatchProvider>(builder: (context, match, _) {
              //   return
              Padding(
                padding: const EdgeInsets.fromLTRB(100, 200, 100, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    SizedBox(
                      height: 150,
                      width: 150,
                      child: ValueListenableBuilder(
                        valueListenable: _dice1,
                        builder: (context, value, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              const Image(
                                image: AssetImage(
                                    'assets/images/dices/dice_0.png'),
                              ),
                              Image(
                                image: AssetImage(
                                    'assets/images/dices/dice_$value.png'),
                              )
                            ],
                          );
                        },
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _count,
                      builder: (context, value, _) {
                        return SizedBox(
                            width: 100,
                            height: 100,
                            child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(15))),
                                child: Image(
                                    image: AssetImage(
                                        'assets/images/operasi/Plus.png')))

                            // child: Builder(builder: (context) {
                            // if (_hasResult) {
                            //   if (Provider.of<UserProvider>(context).user.id ==
                            //           match.match.players.player1.player.id &&
                            //       match.match.winner == 1) {
                            //     return _endWidget("You Win");
                            //   } else if (Provider.of<UserProvider>(context)
                            //               .user
                            //               .id ==
                            //           match.match.players.player2.player.id &&
                            //       match.match.winner == 2) {
                            //     return _endWidget("You Win");
                            //   } else if (Provider.of<UserProvider>(context)
                            //               .user
                            //               .id ==
                            //           match.match.players.player1.player.id &&
                            //       match.match.winner == 2) {
                            //     return _endWidget("You Lose");
                            //   } else if (Provider.of<UserProvider>(context)
                            //               .user
                            //               .id ==
                            //           match.match.players.player2.player.id &&
                            //       match.match.winner == 1) {
                            //     return _endWidget("You Lose");
                            //   } else {
                            //     return _endWidget("DRAW");
                            //   }
                            // } else {
                            // if (value != 0) {
                            //  return Center(
                            //    child: Text(
                            //      value.toString(),
                            //      style: const TextStyle(
                            //          fontSize: 38,
                            //          fontWeight: FontWeight.w700,
                            //          color: Colors.white),
                            //    ),
                            //);
                            //} else {
                            //  return Container();
                            //}
                            // }
                            //}),
                            );
                      },
                    ),
                    SizedBox(
                      height: 150,
                      width: 150,
                      child:
                          //(match.match.dices.dice2 != 0)
                          //     ? Consumer<MatchProvider>(
                          //         builder: (context, match, _) {
                          //           return Image(
                          //             image: AssetImage(
                          //                 'assets/images/dices/dice_${match.match.dices.dice2.toString()}.png'),
                          //           );
                          //         },
                          //       )
                          //     :
                          ValueListenableBuilder(
                        valueListenable: _dice2,
                        builder: (context, value, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              const Image(
                                image: AssetImage(
                                    'assets/images/dices/dice_0.png'),
                              ),
                              Image(
                                image: AssetImage(
                                    'assets/images/dices/dice_$value.png'),
                              )
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 300, 0, 0),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Choose the correct answer below',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(400, 470, 400, 0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Container(
                        child: Align(
                            alignment: Alignment.center,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  primary: Colors.green.shade200,
                                  minimumSize: Size(100, 100),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () {},
                                child: Text(
                                  '5',
                                  style: TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ))),
                      ),
                      Container(
                        child: Align(
                            alignment: Alignment.center,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  primary: Colors.green.shade200,
                                  minimumSize: Size(100, 100),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () {},
                                child: Text(
                                  '7',
                                  style: TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ))),
                      ),
                      Container(
                        child: Align(
                            alignment: Alignment.center,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  primary: Colors.green.shade200,
                                  minimumSize: Size(100, 100),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: () {},
                                child: Text(
                                  '12',
                                  style: TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ))),
                      )
                    ],
                  ),
                ),
              ),
              // },
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channelArena.sink.close();
    Provider.of<MatchProvider>(context, listen: false).clear();
    super.dispose();
  }
}
