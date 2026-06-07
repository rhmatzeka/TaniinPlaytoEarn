import 'package:web/web.dart' as web;

bool hasCoarsePointer() {
  try {
    return web.window.matchMedia('(pointer: coarse)').matches;
  } on Object {
    return false;
  }
}
