import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
    final host = web.window.location.hostname;
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
        final container = web.HTMLDivElement()
          ..style.setProperty('width', '100%')
          ..style.setProperty('height', '100%')
          ..style.setProperty('position', 'relative')
          ..style.setProperty('overflow', 'hidden')
          ..style.setProperty('z-index', '0');

        final iframe = web.HTMLIFrameElement()
          ..src = _proxyUrl
          ..style.setProperty('border', '0')
          ..style.setProperty('position', 'absolute')
          ..style.setProperty('left', '0')
          ..style.setProperty('top', '${_reservedTopPx}px')
          ..style.setProperty('width', '100%')
          ..style.setProperty('height', 'calc(100% - ${_reservedTopPx}px)')
          ..style.setProperty('z-index', '0')
          ..allow = 'fullscreen';

        container.append(iframe);
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
