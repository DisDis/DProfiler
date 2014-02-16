import "code_wrapper.dart";
import "package:args/args.dart";
import "report_view.dart";
import 'package:logging/logging.dart' show Logger, Level, LogRecord;



void main(List<String> args) {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    var msg =
        '${rec.level.name}: ${rec.time}: ${rec.loggerName}: ${rec.message}';
    print(msg);
    //stdout.writeln(msg);
  });
  Logger.root.info("");
  Logger.root.info("---== Start Application ==---");
  Logger.root.info("");
  var parser = new ArgParser();
  parser.addOption("mode", abbr: "m", defaultsTo: "profiler");
  parser.addOption("entry", abbr: "e");
  var result = parser.parse(args);
  var mode = result["mode"];
  if (mode == "report") {
    new ReportView("test1.dart.profiler").generateHtmls("./reports/");
  } else if (mode == "profiler") {
    CodeWrapper cw = new CodeWrapper();cw.entryPoint(result["entry"]);
  } else {
    parser.options.forEach((k, v) {
      print("$k");
    });
  }
}
