import 'dart:async';
import 'dart:convert';
import 'package:ezeetrayflutter/EzeeTray.dart';
import 'package:ezeetrayflutter/TcpScanner.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:lan_scanner/lan_scanner.dart' ;
import 'constants.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const title = 'EZEETRAY';
    return const MaterialApp(
      debugShowCheckedModeBanner: false ,
      title: title,
      home: MyHomePage(
        title: title,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    Key? key,
    required this.title,
  }) : super(key: key);

  final String title;


  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  LanScanner scanner = LanScanner(debugLogging: false);
  String deviceIP = "";


  @override
  void initState() {
    print("iniit");
    _getPrinterIp();
  }

  _getPrinterIp() async {
    final info = NetworkInfo();
    String? wifiIP = await info.getWifiIP(); // 192.168.1.43
    String? wifiSubmask = await info.getWifiSubmask(); // 255.255.255.0
    String? wifiGateway = await info.getWifiGatewayIP(); // 192.168.1.1
    double Progress;
    print(wifiIP?.lastIndexOf("."));
    String scanAdr = (wifiIP!.substring(0,wifiIP.lastIndexOf(".")));
     final stream = scanner.icmpScan(scanAdr, progressCallback: (progress) {
    //final stream = scanner.icmpScan('192.168.29', progressCallback: (progress) {
      Progress = progress;
    });
    stream.listen((HostModel device) async {
      print("Host found");
      await TCPScanner(device.ip, [8181, 8182]).scan().then((result) {
        if(result.open.isNotEmpty){
          setState(() {
            print("Device Found");
            deviceIP =  result.host! ;
          });
        }

      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          child:
          Column(
            mainAxisAlignment: MainAxisAlignment.center ,
            children: [
              Visibility(
                visible: deviceIP.isNotEmpty ? false : true,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      Text("Scanning for Printer"),
                    ],
                  ),
                ),
              ),
              Visibility(
                  visible: deviceIP.isNotEmpty ? true : false,
                  child: ElevatedButton(
                    onPressed: () {
                      print("pressed");
                      print(deviceIP);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => EzeePrint(title: "EzeePrint", deviceIP: deviceIP)));
                    },
                    child: Text("connect"),
                  )
              )
            ],
          ),

        ),
      ),
    );
  }

}
/***
 *
 * get version
 *{"call":"getVersion","promise":{},"timestamp":1641365670695,"uid":"2bh79o","signAlgorithm":"SHA512","position":{"x":960,"y":553.5}}
 *
 * findprinter
 * {"call":"printers.find","promise":{},"params":{"query":""},"timestamp":1641365760983,"uid":"uza66z","signAlgorithm":"SHA512","position":{"x":960,"y":553.5}}
 *
 *
 * {"call":"printers.getDefault","promise":{},"params":{"query":""},"timestamp":1641365760983,"uid":"uza66z","signAlgorithm":"SHA512","position":{"x":960,"y":553.5}}
 *
 *
 *
 *
 *
 *
 * {"call":"print","promise":{},"params":{"printer":{"name":"CUPS-BRF-Printer"},"options":{"bounds":null,"colorType":"color","copies":1,"density":0,"duplex":false,"fallbackDensity":null,"interpolation":"bicubic","jobName":null,"legacy":false,"margins":0,"orientation":null,"paperThickness":null,"printerTray":null,"rasterize":false,"rotation":0,"scaleContent":true,"size":null,"units":"in","forceRaw":false,"encoding":null,"spool":{}},"data":[{"type":"raw","format":"command","flavor":"file","data":"https://demo.qz.io/assets/zpl_sample.txt"}]},"timestamp":1641365878821,"uid":"z7gmxw","signAlgorithm":"SHA512","position":{"x":960,"y":553.5}}
 *
 *
 *
 * type: 'pixel',
    format: 'pdf',
    flavor: 'base64',
 *
 *
 *
 *
 *
 * EZEE CERTIFICATE REQUEST
 *
 *
 *  {"certificate":"-----BEGIN CERTIFICATE-----MIIEXzCCA0egAwIBAgIGAX5NpgwzMA0GCSqGSIb3DQEBCwUAMIHMMQswCQYDVQQGEwJJTjELMAkGA1UECAwCVE4xFzAVBgNVBAcMDkNoZW5uYWksIEluZGlhMSkwJwYDVQQKDCBFemVlSW5mbyBDbG91ZCBTb2x1dGlvbnMgUHZ0IEx0ZDEpMCcGA1UECwwgRXplZUluZm8gQ2xvdWQgU29sdXRpb25zIFB2dCBMdGQxIjAgBgkqhkiG9w0BCQEWE2NvbnRhY3RAZXplZWluZm8uaW4xHTAbBgNVBAMMFEV6ZWUgUHJpbnQgRGVtbyBDZXJ0MB4XDTIyMDExMTA5MzcxNFoXDTQyMDExMTA5MzcxNFowgcwxCzAJBgNVBAYTAklOMQswCQYDVQQIDAJUTjEXMBUGA1UEBwwOQ2hlbm5haSwgSW5kaWExKTAnBgNVBAoMIEV6ZWVJbmZvIENsb3VkIFNvbHV0aW9ucyBQdnQgTHRkMSkwJwYDVQQLDCBFemVlSW5mbyBDbG91ZCBTb2x1dGlvbnMgUHZ0IEx0ZDEiMCAGCSqGSIb3DQEJARYTY29udGFjdEBlemVlaW5mby5pbjEdMBsGA1UEAwwURXplZSBQcmludCBEZW1vIENlcnQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC4MXJ+qAkpEcWY0TMZcEOtVyPqnKeBXtbBaUBhNZg3s7e0tKw/TQpos/+utiGJ1m2mBJvVnlq0cY0C6GNNJYotOC8r+vHReDia3IRSoxa5y6pliALp4VTo2/fCdOgf3a9/AG9EEw6atTGIPsXmAcH712PWHFJYy5Z2idJDnCaYQkoiwpDi7v8YLyzpoUCxZNdUI0mDk533qjq3ypSPMFG+ps1BgVbG0aF3dONZ/LSK0XUHLlRmPm8jHy/G7OTWB/SRDguoc2lHx2fF0rXEaRoNANKNW2kWCW/+R0INNP4ejISmk23vclJDe7PO65FjT/S6XseuMDI8OqE9KShtP3+/AgMBAAGjRTBDMBIGA1UdEwEB/wQIMAYBAf8CAQEwDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBRQnt+rH1G2xqqXniik/b6xdapb0zANBgkqhkiG9w0BAQsFAAOCAQEABVoHq2wuSfhMUMPcvoSkcKZeskhaBO31gBWcZfxSnLWxY4XN+/NOipR9K1W98/NxlgWhWqNt9yCfleKIg4BUfWgGMDcuPzrHEdX5MyrS6zkQelHM+ZnK38AHTatPM2eb3A5g+A5OowTUSP9VNrFlRzoKi1VUo0vOlQSvEblqU2qa0p9c4qOBj41YtTE+MNjVsg2aMbJ56qQcekKLQwsZ7gLhCrnOTSESAMoEAtZNCglnByChv60aBxT8KEtsYyfrSIlWaoI686fFyj7bSyESXDhGTV25+pamFfWmX2HCQz4BHMk/qH8Vi8jkFJ+k+nQMzwMsLW6gdq0I82M4r72R8A==-----END CERTIFICATE-----","promise":{},"timestamp":1642316854624,"uid":"95asnn","signAlgorithm":"SHA512","position":{"x":960,"y":553.5}}
 *
 *
 *
 *
 *
 *
 *
 */

/*    return Scaffold(
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
            builder: (context, snapshot) {
              print(snapshot.data);
              return Text(snapshot.hasData ? '${snapshot.data}' : '');
            },
          )
        ],
      ),

      // This trailing comma makes auto-formatting nicer for build methods.
    );*/
