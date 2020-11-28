import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:exp_contact_tracing/database_helpers.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Contact Tracer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'PrivTrak Contact Tracing'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Set<String> _macAddresses = {};
  Set<String> _oldMacAddresses = {};
  Set<String> _displayedMacAddresses = {};
  int currentRowId = 1;
  int counter = 0;

  _save(String ad, DateTime frequency) async {
    Word word = Word();
    word.word = ad;
    word.frequency = frequency.toString();
    DatabaseHelper helper = DatabaseHelper.instance;
    int id = await helper.insert(word);
  }

  Future<Word> _read(int rowId) async {
    DatabaseHelper helper = DatabaseHelper.instance;
    Word word = await helper.queryWord(rowId);
    return word;
  }

  _erase(int rowId) async {
    DatabaseHelper helper = DatabaseHelper.instance;
    await helper.delete(rowId);
  }

  _eraseAll() async {
    DatabaseHelper helper = DatabaseHelper.instance;
    await helper.deleteAll();
  }

  eraseMacAddresses() async {
    while (true) {
      if ((await _read(currentRowId)) != null) {
        if (DateTime.parse((await _read(currentRowId)).frequency)
            .isBefore(DateTime.now())) {
          await _erase(currentRowId);
          currentRowId++;
        } else {
          break;
        }
      } else {
        break;
      }
    }
  }

  readMacAddresses() async {
    while (true) {
      if ((await _read(currentRowId)) != null) {
        _oldMacAddresses.add((await _read(currentRowId)).word);
        currentRowId++;
      } else {
        currentRowId = 1;
        break;
      }
    }
  }

  addMacAddresses() async {
    for (String i in _macAddresses) {
      _save(i, DateTime.now().add(Duration(days: 14)));
    }
    if (counter != 0) {
      _macAddresses.clear();
    }
  }

  blueScan() async {
    FlutterBlue flutterBlue = FlutterBlue.instance;
    await flutterBlue.stopScan();
    if (counter % 30 == 0) {
      await eraseMacAddresses();
      await addMacAddresses();
      await readMacAddresses();
    }
    await flutterBlue.startScan(timeout: Duration(seconds: 10));
    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        print('${r.device.id} found! rssi: ${r.rssi}');
        _macAddresses.add(r.device.id.toString());
      }
    });
    await flutterBlue.stopScan();
    counter++;
    _displayedMacAddresses.clear();
    _displayedMacAddresses = {..._oldMacAddresses, ..._macAddresses};
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 0), () async {
      await blueScan();
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      bottomNavigationBar: Container(
          color: Colors.blue[100],
          padding: EdgeInsets.fromLTRB(125, 2, 125, 2),
          child: RaisedButton(
              onPressed: blueScan,
              child: Icon(
                Icons.bluetooth_rounded,
                size: 80,
                color: Colors.white,
              ),
              elevation: 10,
              highlightElevation: 0,
              color: Colors.blue[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(500)))),
      body: Container(
          child: SingleChildScrollView(
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            child: LinearProgressIndicator(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
          ),
          Container(
            width: 300,
            padding: EdgeInsets.all(10),
            color: Colors.blue[100],
            child: Text(
              'Bluetooth devices nearby',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Arial',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: ListView.builder(
              itemCount: _macAddresses.length,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: ((BuildContext context, int index) {
                return ListTile(
                  leading: Text((index + 1).toString(),
                      style: TextStyle(fontSize: 20, fontFamily: 'Georgia')),
                  trailing: Icon(
                    Icons.bluetooth,
                    size: 25,
                  ),
                  title: Text(
                    _macAddresses.elementAt(index),
                    style: TextStyle(fontSize: 15, fontFamily: 'Georgia'),
                  ),
                );
              }),
            ),
          ),
          Container(
            child: Text(
              _macAddresses.isEmpty ? 'No new devices found' : '',
              style: TextStyle(fontSize: 10, fontFamily: 'Arial'),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
          ),
          Container(
            width: 300,
            padding: EdgeInsets.all(10),
            color: Colors.blue[100],
            child: Text(
              'Bluetooth devices previously encountered',
              style: TextStyle(
                fontSize: 20,
                fontFamily: 'Arial',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _oldMacAddresses.length,
              itemBuilder: ((BuildContext context, int index) {
                return ListTile(
                  leading: Text((index + 1).toString(),
                      style: TextStyle(fontSize: 20, fontFamily: 'Georgia')),
                  trailing: Icon(
                    Icons.bluetooth,
                    size: 25,
                  ),
                  title: Text(
                    _oldMacAddresses.elementAt(index),
                    style: TextStyle(fontSize: 15, fontFamily: 'Georgia'),
                  ),
                );
              }),
            ),
          ),
          Container(
            child: Text(
              _oldMacAddresses.isEmpty
                  ? 'No previously encountered devices'
                  : '',
              style: TextStyle(fontSize: 10, fontFamily: 'Arial'),
              textAlign: TextAlign.center,
            ),
          ),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     RaisedButton(onPressed: _eraseAll, child: Text('Delete All')),
          //   ],
          // ),
          Container(
            color: Colors.blue[100],
            padding: EdgeInsets.all(20),
            child: Column(children: <Widget>[
              Container(
                color: Colors.blue[900],
                width: 450,
                padding: EdgeInsets.all(10),
                child: Text(
                  'What is PrivTrak?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Image.asset('LogoRawr.png', width: 250),
              Text(
                'CONTACT TRACING doesn\'t always have to invade privacy',
                style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.bold),
              ),
              Text(
                'With PrivTrak, you can be updated of the people you have encountered in the past 14 days and be warned of you possible exposure to COVID-19, ALL WHILE INVOLVING THE MINIMAL PERSONAL INFORMATION.',
                textAlign: TextAlign.justify,
              )
            ]),
          ),
          Container(
            color: Colors.blue[200],
            padding: EdgeInsets.all(20),
            child: Column(children: <Widget>[
              Container(
                color: Colors.blue[900],
                width: 450,
                padding: EdgeInsets.all(10),
                child: Text(
                  'How it works',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Icon(
                Icons.bluetooth_outlined,
                color: Colors.white,
                size: 100,
              ),
              Text(
                'PrivTrak solely depends on the low-energy bluetooth functionality of most devices',
                style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.bold),
              ),
              Text(
                'It periodically scans for bluetooth devices (T=10 seconds) and logs the bluetooth mac addresses of the devices it encounters and accesses the logs everytime the app is opened. In this way, your privacy is never breached because no other information is collected.',
                textAlign: TextAlign.justify,
              )
            ]),
          ),
          Container(
            color: Colors.blue[100],
            padding: EdgeInsets.all(20),
            child: Column(children: <Widget>[
              Container(
                color: Colors.blue[900],
                width: 450,
                padding: EdgeInsets.all(10),
                child: Text(
                  'Using PrivTrak',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Icon(
                Icons.smart_button_outlined,
                color: Colors.white,
                size: 150,
              ),
              Text(
                'YOU DON\'T EVEN HAVE TO PUSH A BUTTON',
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Arial',
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(10),
                child: Text(
                  'But you can! PrivTrak automatically scans for BLE devices as long as your device\'s bluetooth is turned on. Pressing the bluetooth icon button below will invoke the scan without waiting for the regular 10-second scans.',
                  textAlign: TextAlign.justify,
                ),
              ),
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(10),
                child: Text(
                  'When physical proximity has been confirmed by PrivTrak, you can browse for the updated list of mac addresses of the COVID-infected individuals\' devices.',
                  textAlign: TextAlign.justify,
                ),
              ),
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(10),
                child: Text(
                  'If you find a common mac address in the website, YOU HAVE TO QUARANTINE YOURSELF because you were a first-degree exposure.',
                  textAlign: TextAlign.justify,
                ),
              )
            ]),
          ),
        ],
      ))),
    );
  }
}
