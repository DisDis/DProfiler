class CodeInjector {
  Map<int, List<String>> _injectCode = new Map<int, List<String>>();
  clear() {
    _injectCode.clear();
  }

  injection(int position, String code) {
    if (_injectCode.containsKey(position)) {
      _injectCode[position].add(code);
    } else {
      _injectCode[position] = [code];
    }
  }
  
  bool containsKey(int index){
    return _injectCode.containsKey(index);
  }
  
  List<String> get(int index){
    return _injectCode[index];
  }
}
