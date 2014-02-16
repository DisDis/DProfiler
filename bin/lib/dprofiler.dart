import 'dart:math' as math;
import "dart:io";
import 'dart:convert';

class DProfilerFile {
  final String filename;
  final int id;
  DProfilerFile(this.id, this.filename);
  
  toString()=> filename;
}
class DProfilerToken {
  final int id;
  DProfilerToken(this.id);
  int tokenStart;
  int tokenEnd;
  int count = 0;
  int totalTime = 0;
  int minTime = 0;
  int maxTime = 0;
  DProfilerFile file;
  stat(Stopwatch stopWatch) {
    var micros = stopWatch.elapsedMicroseconds;
    totalTime += micros;
    if (count == 0) {
      minTime = micros;
      maxTime = micros;
    } else {
      minTime = math.min(minTime, micros);
      maxTime = math.max(maxTime, micros);
    }
    count++;
  }
  
  List toJSON(){
    return [file!=null?file.id:-1,id,tokenStart,tokenEnd, count, minTime, maxTime, totalTime,
              avg];
  }
  
  static DProfilerToken fromJSON(List list,List<DProfilerFile> _files){
    int fileId = list[0];
    int id = list[1];
    int tokenStart = list[2];
    int tokenEnd = list[3];
    int count = list[4];
    int minTime = list[5];
    int maxTime = list[6];
    int totalTime = list[7];
    var result = new DProfilerToken(id);
    result.file = _files[fileId];
    result.count = count;
    result.minTime = minTime;
    result.maxTime = maxTime;
    result.totalTime = totalTime;
    result.tokenStart = tokenStart;
    result.tokenEnd = tokenEnd;
    return result;
  }

  int get avg => count == 0 ? 0 : (totalTime / count).truncate();
}

abstract class DProfiler {
  int _filecount = 0;
  List<DProfilerToken> _tokens;
  DProfiler() {
  }

  init(int count) {
    _tokens = new List<DProfilerToken>(count);
  }
  saveToFile(String fileName) {
    Map output = new Map();
    StringBuffer sb = new StringBuffer();
    var files = new List<String>();
    _files.forEach((f) {
      files.add(f.filename);
    });
    var id = 0;
    var data = new List<List>();
    _tokens.forEach((v) {
      data.add(v.toJSON());
      id++;
    });
    output["files"] = files;
    output["data"] = data;
    File file = new File(fileName);
    file.writeAsStringSync(JSON.encode(output));
  }

  DProfilerToken _getToken(int tokenId) {
    DProfilerToken token = _tokens[tokenId];
    if (token == null) {
      token = new DProfilerToken(tokenId);
      _tokens[tokenId] = token;
    }
    return token;
  }

  DProfiler addFile(String filename, List<List> tokensCfg) {
    DProfilerFile file = new DProfilerFile(_filecount,filename);
    _filecount++;
    _files.add(file);
    tokensCfg.forEach((list) {
      if (list == null) {
        return;
      }
      int tokenId = list[0];
      List<int> pos = list[1];
      DProfilerToken token = _getToken(tokenId);
      token.tokenStart = pos[0];
      token.tokenEnd = pos[1];
      token.file = file;
    });
    return this;
  }


  static final List<DProfilerFile> _files = new List();
  static final DProfiler _instance = new DProfilerExt();

  static DProfiler getInstance() {
    return _instance;
  }

  static void save(String fileName) {
    _instance.saveToFile(fileName);
  }

  static void stat(Stopwatch stopWatch, int tokenId) {
    _instance._getToken(tokenId).stat(stopWatch);
    stopWatch.reset();
  }
}
