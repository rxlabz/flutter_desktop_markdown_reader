import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const kShowOpenPanelMethod = "FileChooser.Show.Open";
const kShowSavePanelMethod = "FileChooser.Show.Save";
const kFileChooserCallbackMethod = "FileChooser.Callback";

const kAllowedFileTypesKey = "allowedFileTypes";
const kAllowsMultipleSelectionKey = "allowsMultipleSelection";
const kCanChooseDirectoriesKey = "canChooseDirectories";
const kInitialDirectoryKey = "initialDirectory";
const kPlatformClientIDKey = "clientID";

void main() => runApp(new MDReaderApp());

class MDReaderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Demo',
      theme: new ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: new MainScreen(title: 'Markdown Reader'),
    );
  }
}

class MainScreen extends StatefulWidget {
  MainScreen({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainScreenState createState() => new _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String status;

  final colorChannel =
      new OptionalMethodChannel('flutter/colorpanel', const JSONMethodCodec());

  final fileChannel =
      new OptionalMethodChannel('flutter/filechooser', const JSONMethodCodec());

  Color currentColor = Colors.white;
  File currentFile;
  String currentContent;

  Directory currentFolder;

  List<FileSystemEntity> currentFolderEntities;

  @override
  void initState() {
    super.initState();

    colorChannel.setMethodCallHandler((call) {
      if (call.method == "ColorPanel.Callback") {
        final res = call.arguments[0];
        _hideColorPick();
        setState(() {
          currentColor =
              new Color.fromARGB(255, res['red'], res['green'], res['blue']);
        });
      }
    });

    initFilechooserChannel();
  }

  void initFilechooserChannel() {
    fileChannel.setMethodCallHandler((call) {
      if (call.method == kFileChooserCallbackMethod) {
        final res = call.arguments;

        if (res['result'] == 1) {
          final List<String> paths = res['paths'];
          if (paths.length == 1) {
            final selectedEntity = new File(paths.first);
            if (paths.first.endsWith('.md')) {
              final fileContent = selectedEntity.readAsStringSync();

              setState(() {
                currentFile = selectedEntity;
                currentContent = fileContent;
                currentFolder = null;
                currentFolderEntities = null;
              });
            } else if (selectedEntity.statSync().type ==
                FileSystemEntityType.DIRECTORY) {
              _openDirectory(selectedEntity);
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        backgroundColor: currentColor,
        appBar: new AppBar(
          title: new Text(widget.title),
          actions: <Widget>[
            new IconButton(
                icon: new Icon(Icons.folder), onPressed: _selectFile),
            _buildColorPickerButton()
          ],
        ),
        body: new Center(child: _buildScreenContent()));
  }

  void _selectFile() {
    fileChannel.invokeMethod(
      kShowOpenPanelMethod,
      {
        kPlatformClientIDKey: "fldesk",
        kCanChooseDirectoriesKey: true,
        kInitialDirectoryKey: '/Users/rxlabz/dev/notes/flutter',
        kAllowsMultipleSelectionKey: false,
        kAllowedFileTypesKey: ['md']
      },
    );
  }

  void _openDirectory(FileSystemEntity selectedEntity) {
    setState(() {
      currentFolder = new Directory(selectedEntity.path);
      currentFolderEntities = currentFolder
          .listSync()
          .where((entity) => entity is Directory || entity.path.endsWith('.md'))
          .toList();
      currentContent = '';
    });
  }

  void _colorPick() {
    colorChannel.invokeMethod('ColorPanel.Show');
  }

  void _hideColorPick() {
    colorChannel.invokeMethod('ColorPanel.Hide');
  }

  Widget _buildScreenContent() {
    final screenContent = <Widget>[
      currentFolder != null
          ? new Expanded(
              flex: 2,
              child: new Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildFileList(currentFolderEntities),
                  new Expanded(
                      flex: 2, child: new Markdown(data: currentContent))
                ],
              ))
          : currentContent != null
              ? new Expanded(child: new Markdown(data: currentContent))
              : new Text('')
    ];

    if (currentFolder != null || currentFile != null) {
      screenContent.insert(
        0,
        _buildPathBar(),
      );
    }
    return new LayoutBuilder(builder: (context, constraints) {
      return new Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: screenContent,
      );
    });
  }

  Row _buildPathBar() {
    return new Row(children: [
      new Expanded(
        child: new Container(
          color: Colors.blueGrey.shade700,
          /*padding: new EdgeInsets.all(16.0),*/
          child: new Row(children: [
            _buildParentFolderButton(),
            new Text(
              currentFolder != null ? currentFolder.path : currentFile.path,
              style: new TextStyle(fontSize: 12.0, color: Colors.white),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildFileList(List<FileSystemEntity> entities) {
    final size = context.size /*MediaQuery.of(context).size*/;
    return new Expanded(
      child: new Material(
          elevation: 2.0,
          child: new Container(
              width: 200.0,
              height: size.height,
              padding: new EdgeInsets.all(10.0),
              child: new ListView.builder(
                  itemCount: entities.length,
                  itemBuilder: (context, index) {
                    final entity = entities[index];
                    final isDirectory = entity.uri.pathSegments.last == '';
                    return new ListTile(
                      dense: true,
                      onTap: () => _selectEntity(entity.path),
                      leading: new Icon(
                        isDirectory ? Icons.folder : Icons.insert_drive_file,
                        color: Colors.blueGrey,
                      ),
                      title: new Text(
                        isDirectory
                            ? entity.path.split('/').last
                            : entity.uri.pathSegments.last,
                      ),
                    );
                  }))),
    );
  }

  GestureDetector _buildParentFolderButton() {
    return new GestureDetector(
        onTap: () => _openDirectory(currentFolder.parent),
        child: new Padding(
            padding: new EdgeInsets.all(14.0),
            child: new Row(children: [
              new Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
              new Icon(
                Icons.folder,
                color: Colors.white,
              )
            ])));
  }

  Widget _buildColorPickerButton() {
    return new IconButton(
        icon: new Icon(
          Icons.colorize,
          color: currentColor,
        ),
        onPressed: _colorPick);
/*
    return new ConstrainedBox(
        constraints: new BoxConstraints(maxWidth: 30.0, maxHeight: 30.0),
        child: new GestureDetector(
          onTap: _colorPick,
          child: new Container(
            width: 20.0,
            height: 20.0,
            decoration: new BoxDecoration(
                color: currentColor,
                border: new Border.all(width: 2.0),
                boxShadow: [new BoxShadow(blurRadius: 4.0, spreadRadius: 2.0)]),
          ),
        ));
*/
  }

  void _selectEntity(String path) {
    final entity = new File(path);
    if (entity.statSync().type == FileSystemEntityType.DIRECTORY) {
      _openDirectory(entity);
    } else {
      _selectMD(path);
    }
  }

  void _selectMD(String path) {
    setState(() {
      currentFile = new File(path);
      currentContent = currentFile.readAsStringSync();
    });
  }
}
