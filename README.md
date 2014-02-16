DProfiler v0.0.1 (dirty alpha)
========================
Profiler for Google Dart

##Step 1 Generate profiler app source
dart ./dprofiler.dart -m profiler -e app/test1.dart

##Step 2 Run profiler app 
dart test1.dart.profiler.dart

##Step 3 Generate html report
dart ./dprofiler.dart -m report -d ./reports/ -f app/test1.dart.profiler

##Step 4 Show reports in browser
Profit

