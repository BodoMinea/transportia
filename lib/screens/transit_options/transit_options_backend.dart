import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../api/nominatim_client.dart';
import '../../api/transitous_endpoint.dart';
import '../../providers/backend_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/section_title.dart';

/// Backend host and per-endpoint API version overrides.
///
/// Collapsed by default: it is a debugging aid for pointing the app at a
/// different MOTIS instance, not something most people need.
class TransitOptionsBackendCard extends StatefulWidget {
  const TransitOptionsBackendCard({super.key});

  @override
  State<TransitOptionsBackendCard> createState() =>
      _TransitOptionsBackendCardState();
}

class _TransitOptionsBackendCardState extends State<TransitOptionsBackendCard> {
  bool _advancedExpanded = false;
  bool _endpointVersionsExpanded = false;
  late final TextEditingController _hostController;
  late final FocusNode _hostFocusNode;
  late final TextEditingController _versionController;
  late final TextEditingController _nominatimController;
  late final FocusNode _nominatimFocusNode;
  late final FocusNode _versionFocusNode;

  @override
  void initState() {
    super.initState();
    final backend = context.read<BackendProvider>();
    _hostController = TextEditingController(text: backend.host);
    _versionController = TextEditingController(text: backend.apiVersion);
    _nominatimController = TextEditingController(text: backend.nominatimHost);
    _nominatimFocusNode = FocusNode();
    _nominatimFocusNode.addListener(() {
      if (!_nominatimFocusNode.hasFocus) {
        context.read<BackendProvider>().setNominatimHost(
          _nominatimController.text,
        );
      }
    });
    _hostFocusNode = FocusNode();
    _versionFocusNode = FocusNode();
    _hostFocusNode.addListener(() {
      if (!_hostFocusNode.hasFocus) {
        context.read<BackendProvider>().setHost(_hostController.text);
      }
    });
    _versionFocusNode.addListener(() {
      if (!_versionFocusNode.hasFocus) {
        context.read<BackendProvider>().setApiVersion(_versionController.text);
      }
    });
    backend.addListener(_syncBackendControllers);
  }

  void _syncBackendControllers() {
    final backend = context.read<BackendProvider>();
    if (!_hostFocusNode.hasFocus) _hostController.text = backend.host;
    if (!_nominatimFocusNode.hasFocus) {
      _nominatimController.text = backend.nominatimHost;
    }
    if (!_versionFocusNode.hasFocus) {
      _versionController.text = backend.apiVersion;
    }
  }

  @override
  void dispose() {
    context.read<BackendProvider>().removeListener(_syncBackendControllers);
    _hostController.dispose();
    _hostFocusNode.dispose();
    _versionController.dispose();
    _nominatimController.dispose();
    _nominatimFocusNode.dispose();
    _versionFocusNode.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final backendProvider = context.watch<BackendProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _advancedExpanded = !_advancedExpanded),
          child: Row(
            children: [
              const SectionTitle(text: 'Advanced'),
              const Spacer(),
              AnimatedRotation(
                turns: _advancedExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 18,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _advancedExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Backend API host',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              CustomCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                margin: const EdgeInsets.all(0),
                child: Row(
                  children: [
                    Icon(LucideIcons.server, size: 16, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoTextField.borderless(
                        controller: _hostController,
                        focusNode: _hostFocusNode,
                        placeholder: BackendProvider.defaultHost,
                        style: TextStyle(fontSize: 15, color: AppColors.black),
                        placeholderStyle: TextStyle(
                          fontSize: 15,
                          color: AppColors.black.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        autocorrect: false,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (value) => backendProvider.setHost(value),
                      ),
                    ),
                    if (backendProvider.isCustomHost)
                      GestureDetector(
                        onTap: () => backendProvider.resetHost(),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            LucideIcons.rotateCcw,
                            size: 16,
                            color: AppColors.black.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hostname only, without https:// or trailing slash.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Place details server',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              CustomCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                margin: const EdgeInsets.all(0),
                child: Row(
                  children: [
                    Icon(LucideIcons.store, size: 16, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoTextField.borderless(
                        controller: _nominatimController,
                        focusNode: _nominatimFocusNode,
                        placeholder: NominatimClient.defaultHost,
                        style: TextStyle(fontSize: 15, color: AppColors.black),
                        placeholderStyle: TextStyle(
                          fontSize: 15,
                          color: AppColors.black.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        autocorrect: false,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        onSubmitted: backendProvider.setNominatimHost,
                      ),
                    ),
                    if (backendProvider.isCustomNominatimHost)
                      GestureDetector(
                        onTap: () => backendProvider.setNominatimHost(''),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            LucideIcons.rotateCcw,
                            size: 16,
                            color: AppColors.black.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A Nominatim server, for the details of a result tapped on '
                'the map.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'API version',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              CustomCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                margin: const EdgeInsets.all(0),
                child: Row(
                  children: [
                    Icon(LucideIcons.layers, size: 16, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoTextField.borderless(
                        controller: _versionController,
                        focusNode: _versionFocusNode,
                        placeholder: backendProvider.apiVersion,
                        style: TextStyle(fontSize: 15, color: AppColors.black),
                        placeholderStyle: TextStyle(
                          fontSize: 15,
                          color: AppColors.black.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (value) =>
                            backendProvider.setApiVersion(value),
                      ),
                    ),
                    if (backendProvider.isCustomApiVersion)
                      GestureDetector(
                        onTap: () => backendProvider.resetApiVersion(),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            LucideIcons.rotateCcw,
                            size: 16,
                            color: AppColors.black.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Affects routing, stop times and map trips. Map stops and geocode stay on v1 unless overridden below. Auto: v5 for transitous hosts, v1 otherwise.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(
                  () => _endpointVersionsExpanded = !_endpointVersionsExpanded,
                ),
                child: Row(
                  children: [
                    Text(
                      'Per-endpoint versions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _endpointVersionsExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        LucideIcons.chevronDown,
                        size: 16,
                        color: AppColors.black.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _endpointVersionsExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: CustomCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final endpoint in TransitousEndpoint.values)
                          _EndpointVersionField(
                            endpoint: endpoint,
                            defaultVersion: backendProvider.defaultVersionFor(
                              endpoint,
                            ),
                            isLast: endpoint == TransitousEndpoint.values.last,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EndpointVersionField extends StatefulWidget {
  final TransitousEndpoint endpoint;
  final String defaultVersion;
  final bool isLast;

  const _EndpointVersionField({
    required this.endpoint,
    required this.defaultVersion,
    this.isLast = false,
  });

  String get label => endpoint.label;

  @override
  State<_EndpointVersionField> createState() => _EndpointVersionFieldState();
}

class _EndpointVersionFieldState extends State<_EndpointVersionField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final backend = context.read<BackendProvider>();
    _controller = TextEditingController(
      text: backend.endpointVersionOverride(widget.endpoint) ?? '',
    );
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        context.read<BackendProvider>().setEndpointVersion(
          widget.endpoint,
          _controller.text,
        );
      }
    });
    backend.addListener(_sync);
  }

  void _sync() {
    if (!_focusNode.hasFocus) {
      final override = context.read<BackendProvider>().endpointVersionOverride(
        widget.endpoint,
      );
      final newText = override ?? '';
      if (_controller.text != newText) _controller.text = newText;
    }
  }

  @override
  void dispose() {
    context.read<BackendProvider>().removeListener(_sync);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final backend = context.watch<BackendProvider>();
    final isOverridden = backend.isEndpointOverridden(widget.endpoint);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.black.withValues(alpha: 0.65),
                  ),
                ),
              ),
              Expanded(
                child: CupertinoTextField.borderless(
                  controller: _controller,
                  focusNode: _focusNode,
                  placeholder: widget.defaultVersion,
                  style: TextStyle(fontSize: 14, color: AppColors.black),
                  placeholderStyle: TextStyle(
                    fontSize: 14,
                    color: AppColors.black.withValues(alpha: 0.3),
                  ),
                  padding: EdgeInsets.zero,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) =>
                      backend.setEndpointVersion(widget.endpoint, v),
                ),
              ),
              if (isOverridden)
                GestureDetector(
                  onTap: () => backend.resetEndpointVersion(widget.endpoint),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      LucideIcons.rotateCcw,
                      size: 14,
                      color: accent.withValues(alpha: 0.6),
                    ),
                  ),
                )
              else
                const SizedBox(width: 22),
            ],
          ),
        ),
        if (!widget.isLast)
          Container(
            height: 0.5,
            color: AppColors.black.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}
