import "code_wrapper.dart";
import "package:args/args.dart";
import "report_view.dart";
import 'package:logging/logging.dart' show Logger, Level, LogRecord;

String version = "0.0.1";

void main(List<String> args) {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    var msg =
        '${rec.level.name}: ${rec.time}: ${rec.loggerName}: ${rec.message}';
    print(msg);
    //stdout.writeln(msg);
  });
  Logger.root.info("---== Start Application v$version ==---");
  Logger.root.info("${new DateTime.now()}");
  var parser = new ArgParser();
  parser.addOption("mode", abbr: "m", defaultsTo: "profiler", help:"Mode",allowed:["profiler","report"]);
  parser.addOption("entry", abbr: "e", help:"Main dart file");
  parser.addOption("reportOutputDir", abbr: "d", help:"Report output directory");
  parser.addOption("reportFile", abbr: "f", help:"Report file (*.profiler)");
  print(parser.getUsage());
  var result = parser.parse(args);
  var mode = result["mode"];
  if (mode == "report") {
    new ReportView(result["reportFile"]).generateHtmls(result["reportOutputDir"]);
  } else if (mode == "profiler") {
    CodeWrapper cw = new CodeWrapper();cw.entryPoint(result["entry"]);
  }
}
