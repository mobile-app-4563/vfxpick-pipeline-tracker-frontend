{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Force local CanvasKit so web works without internet access.
    canvasKitBaseUrl: "canvaskit/",
  },
});
