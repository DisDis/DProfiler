import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:analyzer_experimental/analyzer.dart';
import 'code_injector.dart';

class TokenStat {
  final int start;
  final int end;
  TokenStat(this.start, this.end);
}

class CodeWrapper {
  List<String> sourceChars;
  CodeInjector _injector = new CodeInjector();
  int globalInjectId = 0;
  int lastInjectId = -1;
  int globalResultId = 0;
  int globalTokenId = 0;
  ImportDirective _firstImport = null;
  bool _isLibrary = true;
  String _projectRootPath;
  static const String profilerImport = "dprofiler.init.dart";
  static const String _PROFILER_SOURCE = "./lib/dprofiler.dart";

  String _currentFile;
  FunctionExpression _mainFunction = null;
  Map<int, TokenStat> _tokens = new Map();
  List<String> _tokenFileInfo = new List();

  _genResultId() {
    return globalResultId++;
  }

  _genInjectId() {
    return globalInjectId++;
  }

  wrapASTNode(ASTNode node, int injectId) {
    bool firstInject = false;
    if (lastInjectId < injectId) {
      lastInjectId = injectId;
      firstInject = true;
    }
    var stopWKey = "_StWa${injectId}_";
    if (firstInject) {
      _injector.injection(node.beginToken.offset,
          "Stopwatch $stopWKey = new Stopwatch();");
    }
    _injector.injection(node.beginToken.offset, "$stopWKey.start();");
    _injector.injection(node.endToken.end,
        "$stopWKey.stop();DProfiler.stat($stopWKey,$globalTokenId);");
    _tokens[globalTokenId] = new TokenStat(node.beginToken.offset,
        node.endToken.end);
    globalTokenId++;
  }



  parseMethodInvocation(MethodInvocation mi) {
    mi.argumentList.arguments.forEach((arg) {
      if (arg is MethodInvocation) {
        parseMethodInvocation(arg);
      } else if (arg is FunctionExpression) {
        parseFunctionExpression(arg);
      } else {
        //print("$arg ${arg.runtimeType}");
      }
    });
  }

  parseVariableDeclarationStatement(VariableDeclarationStatement vds) {
    parseVariableDeclarationList(vds.variables.variables);
  }


  parseStatement(Statement stat, int injectId) {
    //print("  ${stat.runtimeType} $stat");
    if (stat is WhileStatement) {
      _parseWhileStatement(stat, injectId);
    } else if (stat is ForStatement) {
      _parseForStatement(stat, injectId);
    } else if (stat is ExpressionStatement) {
      _parseExpressionStatement(stat, injectId);
    } else if (stat is VariableDeclarationStatement) {
      wrapASTNode(stat, injectId);
      parseVariableDeclarationStatement(stat);
      //         print("${stat.runtimeType} $stat");
    } else if (stat is ReturnStatement) {
      parseReturnStatement(stat, injectId);
    } else if (stat is Block) {
      parseBlock(stat);
    }
  }

  _parseExpressionStatement(ExpressionStatement stat, int injectId) {
    wrapASTNode(stat, injectId);
    if (stat.expression is MethodInvocation) {
      parseMethodInvocation(stat.expression);
    }
  }

  _parseWhileStatement(WhileStatement stat, int injectId) {
    wrapASTNode(stat, injectId);
    Block block = stat.body;
    if (block == null) {
      return;
    }
    parseBlock(block);
  }

  void _parseForStatement(ForStatement stat, injectId) {
    wrapASTNode(stat, injectId);
    Block block = stat.body;
    if (block == null) {
      return;
    }
    parseBlock(block);
  }

  void parseReturnStatement(ReturnStatement stat, int injectId) {
    //SimpleIdentifier
    Expression exp = stat.expression;
    /*if (exp is SimpleIdentifier || exp is SimpleStringLiteral || exp is BooleanLiteral || exp is DoubleLiteral|| exp is IntegerLiteral
        || exp is NullLiteral){
      return;
    }*/
    var resultVar = "_rEsUlT_${_genResultId()}";
    wrapASTNode(stat, injectId);
    _injector.injection(stat.beginToken.offset, "var $resultVar  = /*");
    _injector.injection(stat.beginToken.end, "*/");
    _injector.injection(stat.endToken.end, "return $resultVar;");
    if (exp is FunctionExpression) {
      parseFunctionExpression(exp);
    }
    /* else {
      print("${exp.runtimeType} ${exp}");
    }*/
  }

  parseBlock(Block block) {
    int injectId = _genInjectId();
    block.statements.forEach((stat) {
      parseStatement(stat, injectId);
    });
  }

  parseFunctionExpression(FunctionExpression fe) {
    try{
    BlockFunctionBody bfb = fe.body as BlockFunctionBody;
    if (bfb != null) {
      Block block = bfb.block;
      if (block == null) {
        return;
      }
      parseBlock(block);
    }
  }catch(e){
        print("${fe} ${fe.body.runtimeType} ${fe.body}");
        throw e;
      }
  }

  void parseDeclaration(Declaration dec) {
    //print("-----------=== [${dec.runtimeType}] ===-----------");
    if (dec is FunctionDeclaration) {
      if (dec.functionExpression != null) {
        if (dec.name != null) {
          if (dec.name.toString() == "main") {
            _mainFunction = dec.functionExpression;
          }
        }
        parseFunctionExpression(dec.functionExpression);
      }
    } else if (dec is ClassDeclaration) {
      parseClassDeclaration(dec);
    } else if (dec is TopLevelVariableDeclaration) {
      parseVariableDeclarationList(dec.variables.variables);
    }
  }

  void parseClassDeclaration(ClassDeclaration dec) {
    dec.members.forEach((member) {
      if (member is MethodDeclaration) {
        parseMethodDeclaration(member);
      }
      if (member is FieldDeclaration) {
        parseFieldDeclaration(member);
      } else {
        //print("${member.runtimeType} $member");
      }
    });
  }

  parseVariableDeclarationList(NodeList<VariableDeclaration> list) {
    list.forEach((VariableDeclaration v) {
      if (v.initializer is FunctionExpression) {
        parseFunctionExpression(v.initializer);
      }
      //print("${v.runtimeType} $v");
    });

    /*.variables.forEach((v) {
        if (v.initializer is InstanceCreationExpression) {
          InstanceCreationExpression ice = v.initializer as
              InstanceCreationExpression;
          print("${ice.runtimeType} $ice");
        } else {
          print("${v.runtimeType} $v");
        }
      });*/
  }

  parseFieldDeclaration(FieldDeclaration member) {
    parseVariableDeclarationList(member.fields.variables);
  }

  void parseMethodDeclaration(MethodDeclaration member) {
    if (member.body is ExpressionFunctionBody){
      return;
    }
    try{
    BlockFunctionBody bfb = member.body as BlockFunctionBody;
    if (bfb != null) {
      Block block = bfb.block;
      if (block == null) {
        return;
      }
      parseBlock(block);
    }
    }catch(e){
      print("${member} ${member.body.runtimeType} ${member.body}");
      throw e;
    }

  }

  entryPoint(String fileName) {
    File f = new File(fileName);
    _currentFile = f.absolute.path;
    _mainFunction = null;
    _isLibrary = true;
    var fileDir = path.dirname(_currentFile);
    _projectRootPath = fileDir;
    wrappingFile(fileName);
    var importFile = path.join(_projectRootPath, profilerImport);
    StringBuffer sb = new StringBuffer(new File(_PROFILER_SOURCE
        ).readAsStringSync());

    sb.write(
        """
class DProfilerExt extends DProfiler{
  DProfilerExt(){
    init($globalTokenId);
    var instance = this;
"""
        );
    _tokenFileInfo.forEach((item) {
      sb.writeln(item);
    });
    sb.write("""  }
}
""");
    var file = new File(importFile);
    file.writeAsStringSync(sb.toString());

    print("Execute: dart $fileName.profiler.dart");
    print("Show report: dprofiler -m report -d ./reports/ -f $fileName.profiler"
        );
  }

  wrappingFile(String fileName) {
    _injector.clear();
    File f = new File(fileName);
    _firstImport = null;
    _currentFile = f.absolute.path;
    _mainFunction = null;
    _isLibrary = true;
    var fileDir = path.dirname(_currentFile);
    print('parsing: $_currentFile');

    CompilationUnit cu = parseDartFile(_currentFile);
    var contents = new File(_currentFile).readAsStringSync();
    sourceChars = contents.split("");
    cu.declarations.forEach((dec) {
      parseDeclaration(dec);
    });
    if (_mainFunction != null) {
      _injector.injection(_mainFunction.body.endToken.offset,
          "DProfiler.save('${_currentFile}.profiler');");
    }
    cu.directives.forEach((dir) {
      if (dir is ImportDirective) {
        _isLibrary = false;
        if (_firstImport ==null){
          _firstImport = dir;
        }
      }
      if (dir is PartOfDirective) {
        _isLibrary = true;
      }
    });

    cu.directives.forEach((dir) {
      if (dir is ImportDirective) {
        var importFile = path.join(fileDir, dir.uri.stringValue);
        var f = new File(importFile);
        if (f.existsSync()) {
          _replaceFileImport(dir.uri);
        }
      } else if (dir is PartDirective) {
        _replaceFileImport(dir.uri);
      }
    });
    _saveFile();
    _tokenFileInfo.add(_tokenInfoToBuffer());
    _tokens.clear();
    cu.directives.forEach((dir) {
      if (dir is ImportDirective) {
        var importFile = path.join(fileDir, dir.uri.stringValue);
        var f = new File(importFile);
        if (f.existsSync()) {
          wrappingFile(importFile);
        }
      }
      if (dir is PartDirective) {
        var importFile = path.join(fileDir, dir.uri.stringValue);
        wrappingFile(importFile);
      }
    });
  }

  _replaceFileImport(StringLiteral uri) {
    //dir.uri.beginToken.offset;
    //dir.uri.endToken.end;
    _injector.injection(uri.endToken.end - 1, ".profiler.dart");
  }

  void _saveFile() {
    String sb = _getWrapperSource();
    var file = new File(_currentFile + ".profiler.dart");
    file.writeAsStringSync(sb);
    //    print(sb);
  }

  String _getWrapperSource() {
    StringBuffer sb = new StringBuffer();
    if (!_isLibrary) {
      var importFile = path.join(_projectRootPath, profilerImport);
      _injector.injection(_firstImport.endToken.end, "import \"$importFile\";");
    }
    int index = 0;
    sourceChars.forEach((char) {
      if (_injector.containsKey(index)) {
        sb.writeAll(_injector.get(index));
      }
      sb.write(char);
      index++;
    });

    return sb.toString();
  }

  String _tokenInfoToBuffer() {
    StringBuffer sb = new StringBuffer();
    sb
        ..write("instance.addFile('")
        ..write(_currentFile)
        ..write("',")
        ..write("[");
    _tokens.forEach((k, v) {
      var str = "[$k,[${v.start},${v.end}]],";
      if (k % 10 == 0) {
        sb.writeln(str);
      } else {
        sb.write(str);
      }
    });
    sb
        ..write("null]")
        ..write(");");
    return sb.toString();
  }
}
