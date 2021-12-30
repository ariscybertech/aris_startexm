part of start;

class Route {
  final String _method;
  final Map _path;
  final StreamController _controller = new StreamController();
  Stream stream;
  String _dir;

  Route(String method, path) :
    _method = method.toUpperCase(),
    _path = _normalize(path) {
    stream = _controller.stream;
  }

  Route.file(this._dir) :
    _method = null, _path = null {
    stream = _controller.stream;
  }

  Route.ws(dynamic path) :
    _method = 'WS',
    _path = _normalize(path) {
    stream = _controller.stream.transform(new WebSocketTransformer()).map((WebSocket ws) => new Socket(ws));
  }

  bool match(HttpRequest req) {
    return ((_method == req.method || _method == 'WS')
        && _path['regexp'].hasMatch(req.uri.path));
  }

  void handle(HttpRequest req) {
    if (_dir != null) {
      var path = _dir + req.uri.path,
          directory = new Directory(path),
          response = new Response(req.response);

      directory.exists().then((found) {
        if (found) {
          response.sendFile(directory.path + '/index.html');
        } else {
          response.sendFile(path);
        }
      },
      onError: (e) => print(e));
    } else if (_method == 'WS') {
      _controller.add(req);
    } else {
      var request = new Request(req);
      request.params = _parseParams(req.uri.path, _path);
      request.response = new Response(req.response);
      _controller.add(request);
    }
  }

  static Map _normalize(dynamic path, [bool strict = false]) {
    if (path is RegExp) {
      return {
        'regexp': path,
        'keys': []
      };
    }
    if (path is List) {
      path = '(${path.join('|')})';
    }

    var keys = [];

    if (!strict) {
      path += '/?';
    }

    path = path.replaceAllMapped(new RegExp(r'(\.)?:(\w+)(\?)?'), (Match placeholder) {
          var replace = new StringBuffer('(?:');

          if (placeholder[1] != null) {
            replace.write('\.');
          }

          replace.write('(\\w+))');

          if (placeholder[3] != null) {
            replace.write('?');
          }

          keys.add(placeholder[2]);

          return replace.toString();
        })
        .replaceAll('//', '/');

    return {
      'regexp': new RegExp('^$path\$'),
      'keys': keys
    };
  }

  Map _parseParams(String path, Map routePath) {
    var params = {};
    Match paramsMatch = routePath['regexp'].firstMatch(path);
    for (var i = 0; i < routePath['keys'].length; i++) {
      params[routePath['keys'][i]] = paramsMatch[i+1];
    }
    return params;
  }
}
