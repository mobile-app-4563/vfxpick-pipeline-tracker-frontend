// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';

class HrmsView extends StatefulWidget {
  const HrmsView({super.key});

  @override
  State<HrmsView> createState() => _HrmsViewState();
}

class _HrmsViewState extends State<HrmsView> {
  static const String _viewType = 'hrms-proxy-view';
  static const int _reservedTopPx = 2;
  static bool _factoryRegistered = false;

  String get _proxyUrl {
    final host = html.window.location.hostname;
    final isLocalHost = host == 'localhost' || host == '127.0.0.1';
    if (isLocalHost) {
      return 'http://127.0.0.1:3000/api/hrms-proxy/Home/Index';
    }
    return '${ApiConstants.baseUrl}/hrms-proxy/Home/Index';
  }

  @override
  void initState() {
    super.initState();

    if (!_factoryRegistered) {
      ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.position = 'relative'
          ..style.overflow = 'hidden'
          ..style.zIndex = '0';

        final iframe = html.IFrameElement()
          ..src = _proxyUrl
          ..style.border = '0'
          ..style.position = 'absolute'
          ..style.left = '0'
          ..style.top = '${_reservedTopPx}px'
          ..style.width = '100%'
          ..style.height = 'calc(100% - ${_reservedTopPx}px)'
          ..style.zIndex = '0'
          ..allow = 'fullscreen';

        container.children.add(iframe);
        return container;
      });
      _factoryRegistered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const ClipRect(
      child: SizedBox.expand(child: HtmlElementView(viewType: _viewType)),
    );
  }
}
