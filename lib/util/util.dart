import 'package:flutter/cupertino.dart';
//import 'package:flutter_advanced_networkimage_2/provider.dart';
import '../builder/pattern.dart';
import '../model/locator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:jiffy/jiffy.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';


final encoder = const ZLibEncoder();
final decoder = const ZLibDecoder();

class Util {
  Util._();

  static clearImageCache() {
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  static int getImageCacheSize() {
    return imageCache.currentSize;
  }

/*   static Future<bool> clearSvgCache() async {
    return await DiskCache().clear();
  }

  static Future<int> getSvgCacheSize() async {
    int size = await DiskCache().cacheSize() ?? 0;
    return size;
  } */
}

onShare(Map<String, dynamic> map) {
  String text = map["_text"];
  String? sub = map["_subject"];
  if (sub == null) {
    Share.share(text);
  } else {
    Share.share(text, subject: sub);
  }
}

setLocale() async {
  String l = model.map["userProfile"]["locale"]!;
  if (l == 'en') {
    await Jiffy.setLocale('en');
  } else {
    await Jiffy.setLocale(l);
  }
}

String getRenewDay(Map<String, dynamic> map) {
  bool nextMonth = map["_nextMonth"] ?? false;
  late String day = (nextMonth)
      ? Jiffy.now().add(months: 1).subtract(days: 1).yMMMMd
      : Jiffy.now().add(years: 1).subtract(days: 1).yMMMMd;
  //model.map["userProfile"]["renew"] = day;
  return day;
}

String numString(num n, {int dec = 2}) {
  String c = model.map["lookup"]["NumSep"] ?? ",";
  String ns = "";
  String nns = "";
  if (n is int) {
    ns = n.toString();
    if (n < 1000) {
      return ns;
    }
    nns = c + ns.substring(ns.length - 3);
    ns = ns.substring(0, ns.length - 3);
  } else if (n is double) {
    ns = n.toStringAsFixed(dec);
    if (n < 1000.0) {
      return ns;
    }
    int d = (dec == 0) ? 3 : 4;
    d += dec;
    nns = c + ns.substring(ns.length - d);
    ns = ns.substring(0, ns.length - d);
  }
  while (ns.length > 3) {
    nns = c + ns.substring(ns.length - 3) + nns;
    ns = ns.substring(0, ns.length - 3);
  }
  nns = ns + nns;
  return nns;
}

processValue(Map<String, dynamic> map, dynamic value) {
  dynamic _pe = map["_processEvent"] ?? map["_onTap"];
  ProcessEvent? pe = (_pe is String) ? ProcessEvent(_pe) : _pe;
  if (pe == null) {
    return;
  }
  Agent a = model.appActions.getAgent("pattern");
  pe.map ??= map["_inMap"];
  if (value != null) {
    pe.map ??= {};
    pe.map!["_value"] = value;
  }
  a.process(pe);
}

  String compressText(String text) {
    List<int> bytes = utf8.encode(text);
    List<int> compressed = encoder.encode(bytes);
    return base64.encode(compressed);
  }

  String decompressText(String text) {
    List<int> compressed = base64.decode(text);
    List<int> bytes = decoder.decodeBytes(compressed);
    return utf8.decode(bytes);
  }

  dynamic upzipFile(String filename) {
    final bytes = File(filename).readAsBytesSync();
    return ZipDecoder().decodeBytes(bytes);
  }