import 'package:http_server/http_server.dart' as http_server;
import 'package:route/server.dart' show Router;
import 'package:logging/logging.dart' show Logger, Level, LogRecord;
import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:math' as Math;
import 'dart:convert';
import './lib/dprofiler.dart';
import 'code_injector.dart';

class ReportView {
  static final Logger _log = new Logger('ReportView');
  final String _reportFilename;
  List<DProfilerFile> _files = new List();
  Map<int, List<DProfilerToken>> _tokens = new Map();
  ReportView(this._reportFilename) {
    File reportFile = new File(_reportFilename);
    String reportContent = reportFile.readAsStringSync();
    Map _reportMap = JSON.decode(reportContent);
    List<String> files = _reportMap["files"];
    var id = 0;
    files.forEach((file) {
      _files.add(new DProfilerFile(id, file));
      id++;
    });
    List<List> data = _reportMap["data"];
    data.forEach((tokenData) {
      DProfilerToken result = DProfilerToken.fromJSON(tokenData, _files);
      List<DProfilerToken> tokens;
      if (_tokens.containsKey(result.file.id)) {
        tokens = _tokens[result.file.id];
      } else {
        tokens = new List();
        _tokens[result.file.id] = tokens;
      }
      tokens.add(result);
    });
  }

  void run() {
    int port = 8081; // TODO use args from command line to set this
    HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, port).then((server) {
      _log.info("Search server is running on "
          "'http://${server.address.address}:$port/'");
      var router = new Router(server);

      router.serve("/index.html").listen(_indexHtml);
      router.serve("/file.html").listen(_fileHtml);
    });
  }

  void _indexHtml(HttpRequest request) {
    _log.info("${request.uri}");
    HttpResponse response = request.response;
    _noCache(response);
    StringBuffer sb = new StringBuffer();
    _files.forEach((file) {
      sb
          ..write("<a href='/file.html?fileId=${file.id}'>${file.filename}</a>")
          ..write("</br>");
    });
    response.write(sb.toString());
    response.close();
  }

  _noCache(HttpResponse response) {
    response.headers.contentType = ContentType.parse("text/html; charset=utf-8"
        );
    response.headers.add('Cache-Control', 'no-cache, must-revalidate');
  }

  void _fileHtml(HttpRequest request) {
    _log.info("${request.uri}");
    String url = request.uri.toString();
    url = url.substring(url.indexOf("?") + 1);
    var queryMap = Uri.splitQueryString(url);
    HttpResponse response = request.response;
    _noCache(response);
    var fileIdS = queryMap["fileId"];
    int fileId = int.parse(fileIdS);
    response.write(_generateHtml(fileId));
    response.close();
  }

  void generateHtmls(String outputDir){
    _files.forEach((file){
      var genName = file.filename.replaceAll(path.separator,"_").replaceAll(".","_")+".html";
     var f= new File(path.join(outputDir,genName));
     if (!f.existsSync()){
       f.createSync(recursive: true);
     }
     f.writeAsStringSync(_generateHtml(file.id));
     print("generate: ${f.absolute.path}");
    });
  }
  
  String _generateHtml(int fileId) {
    StringBuffer sb = new StringBuffer();
    List<DProfilerToken> tokens = _tokens[fileId];
    DProfilerFile file = _files[fileId];
    if (tokens == null){
          print("Not found tokens for $fileId:$file");
          return "EMPTY";
    }
    var fileContent = new File(file.filename).readAsStringSync();
    CodeInjector _injector = new CodeInjector();
    int maxTotal = 1;
    tokens.forEach((token) {
      if (token.totalTime > maxTotal) {
        maxTotal = token.totalTime;
      }
    });

    tokens.forEach((token) {
      var color = hsvToRgb(0, ((token.totalTime * 100) / maxTotal).round(), 100
          );
      _injector.injection(token.tokenStart,
          "<span class='token' id='token_${token.id}' title='c:${token.count} min:${token.minTime} max:${token.maxTime} total:${token.totalTime}' style=\"background-color: rgb(${color[0]}, ${color[1]}, ${color[2]})\">"
          );
      _injector.injection(token.tokenEnd, "</span>");
    });

    int index = 0;
    fileContent.split("").forEach((char) {
      if (_injector.containsKey(index)) {
        sb.writeAll(_injector.get(index));
      }
      if (char == " ") {
        sb.write('&nbsp;');
      } else {
        sb.write(char);
      }
      index++;
    });
    fileContent = sb.toString();
    fileContent = fileContent.replaceAll("\n", "<br/>");
    sb.clear();
    sb.writeln('<style type="text/css">');
    sb.writeln('.token:hover > span{ background-color: inherit !important;}');
    sb.writeln('</style>');
    sb.writeln("Date:${new DateTime.now()}<br/><br/>");
    sb.write(fileContent);
    return sb.toString();
  }

  /**
   * HSV to RGB color conversion
   *
   * H runs from 0 to 360 degrees
   * S and V run from 0 to 100
   * 
   * Ported from the excellent java algorithm by Eugene Vishnevsky at:
   * http://www.cs.rit.edu/~ncs/color/t_convert.html
   */
  List<int> hsvToRgb(int hh, int ss, int vv) {
    var r, g, b;
    var i;
    var f, p, q, t;

    // Make sure our arguments stay in-range
    hh = Math.max(0, Math.min(360, hh));
    ss = Math.max(0, Math.min(100, ss));
    vv = Math.max(0, Math.min(100, vv));

    // We accept saturation and value arguments from 0 to 100 because that's
    // how Photoshop represents those values. Internally, however, the
    // saturation and value are calculated from a range of 0 to 1. We make
    // That conversion here.
    var s = ss / 100;
    var v = vv / 100;

    if (s == 0) {
      // Achromatic (grey)
      r = g = b = v;
      return [(r * 255).round(), (g * 255).round(), (b * 255).round()];
    }

    var h = hh / 60; // sector 0 to 5
    i = h.floor();
    f = h - i; // factorial part of h
    p = v * (1 - s);
    q = v * (1 - s * f);
    t = v * (1 - s * (1 - f));

    switch (i) {
      case 0:
        r = v;
        g = t;
        b = p;
        break;

      case 1:
        r = q;
        g = v;
        b = p;
        break;

      case 2:
        r = p;
        g = v;
        b = t;
        break;

      case 3:
        r = p;
        g = q;
        b = v;
        break;

      case 4:
        r = t;
        g = p;
        b = v;
        break;

      default: // case 5:
        r = v;
        g = p;
        b = q;
    }

    return [(r * 255).round(), (g * 255).round(), (b * 255).round()];
  }

}
