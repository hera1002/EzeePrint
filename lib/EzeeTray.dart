import 'dart:convert';

import 'package:ezeetrayflutter/constants.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class EzeePrint extends StatefulWidget {
  final String title;
  final String deviceIP;

  const EzeePrint({Key? key, required this.title, required this.deviceIP}) : super(key: key);

  @override
  _EzeePrintState createState() => _EzeePrintState();
}

class _EzeePrintState extends State<EzeePrint> {
  var _channel = WebSocketChannel.connect(
    Uri.parse('ws://10.0.2.2:8182'),
    //Uri.parse('ws://${widget.deviceIP}:8182'),
  );
  // add certificate after connecting
  // _channel.sink.add(jsonEncode({"certificate": certificate}));
 bool findPrinter =false;
  List<String> printerList=[];
  String dropdownvalue="select Printer";

 @override
  void initState() {
    // TODO: implement initState
    super.initState();
    findPrinter=true;
    _channel.sink.add(jsonEncode({
      "call": "printers.find",
      "promise": {},
      "params": {},
    }));

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              _channel = WebSocketChannel.connect(
                Uri.parse('wss://10.0.2.2:8181'),
              );
              print("==============");
              // add certificate after connecting
              // _channel.sink.add(jsonEncode({"certificate": certificate}));

              print("00000000");
            },
            child: Text("Connect"),
          ),
          ElevatedButton(
            onPressed: () {
              _channel.sink.close();
              print("connecton closed");
            },
            child: Text("Disconnect"),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                _channel.sink.add(jsonEncode({
                  "call": "printers.getDefault",
                  "promise": {},
                  "params": {},
                }));
              } on Exception catch (e) {
                print(e);
                // TODO
              }
            },
            child: Text("find printers"),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                _channel.sink.add(jsonEncode({
                  "call": "printers.find",
                  "promise": {},
                  "params": {},
                }));
              } on Exception catch (e) {
                print(e);
                // TODO
              }
            },
            child: Text("Get network Info"),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                _channel.sink.add(jsonEncode(printbase64));
                print(printbase64);
              } on Exception catch (e) {
                print(e);
                print("88888888888888888888");
                // TODO
              }
            },
            child: Text("PrintFile"),
          ),
          StreamBuilder(
            stream: _channel.stream,
            builder: (context, AsyncSnapshot<Object?> snapshot) {
              if(findPrinter){
                var d1= snapshot.data;
                printerList=jsonDecode(d1.toString())["result"];
                //printerList.add(snapshot.data);
              }
              return Text(snapshot.hasData ? '${snapshot.data}' : '');

            },
          ),


        ],
      ),

      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
  }

