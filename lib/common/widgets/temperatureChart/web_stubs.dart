// Stub for dart:html on non-web platforms
library html;

class Blob {
  Blob(List<dynamic> parts, [Map<String, String>? options]) {}
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  AnchorElement({required String href}) {}
  void setAttribute(String name, String value) {}
  void click() {}
}
