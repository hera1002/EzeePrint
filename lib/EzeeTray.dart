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

  // add certificate after connecting
  var _channel ;
  //add certificate


  bool findPrinter =false;
  List<String> printerList=[];
  String dropdownvalue="select Printer";

  String selectedPrinter="NoneSelected";

 @override
  void initState() {
    // TODO: implement initState
    super.initState();
    print("set");
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://${widget.deviceIP}:8182'),
      //Uri.parse('ws://${widget.deviceIP}:8182'),
    );
    print("deviceIp");
    print(widget.deviceIP);
    _channel.sink.add(jsonEncode({"certificate": certificate}));
    //find printer

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
              findPrinter=true;
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
            child: Text("FindAvailable Printers"),
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
              if(snapshot.hasData)
                {
                  if(findPrinter){
                    var printerObject= jsonDecode(snapshot.data.toString());
                    List<dynamic> dynList = null!=(printerObject["result"])?printerObject["result"]:[];
                    printerList.clear();
                    print("---findPrinter = ${findPrinter}----");
                      printerList = dynList.cast<String>();
                      print(printerList);
                      printerList.add("Test");
                      print(printerList);
                    findPrinter=false;
                    print("---findPrinter = ${findPrinter}----");
                  }
              }
              return Column(
                children: [
                  Text(snapshot.hasData ? '${snapshot.data}' : ''),
                  MultiSelectChip(
                    printerList,
                    onSelectionChanged: (printer) {
                      setState(() {
                        selectedPrinter  = printer;
                      });
                    },
                  ),
                  Text("DefaultPrinter=$selectedPrinter")
                ],
              );

            },
          ),


        ],
      ),

      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
  }

class MultiSelectChip extends StatefulWidget {
  final List<String> reportList;
  final Function(String) onSelectionChanged;
  MultiSelectChip(this.reportList, {required this.onSelectionChanged});
  @override
  _MultiSelectChipState createState() => _MultiSelectChipState();
}
class _MultiSelectChipState extends State<MultiSelectChip> {
  String selectedChoice = "";
  _buildChoiceList() {
    List<Widget> choices = [];
    widget.reportList.forEach((item) {
      choices.add(Container(
        padding: const EdgeInsets.all(2.0),
        child: ChoiceChip(
          label: Text(item),
          selected: selectedChoice == item,
          onSelected: (selected) {
            setState(() {
              selectedChoice = item;
              widget.onSelectionChanged(selectedChoice);
            });
          },
        ),
      ));
    });
    return choices;
  }
  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: _buildChoiceList(),
    );
  }
}