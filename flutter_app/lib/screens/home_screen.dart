import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/scenario_model.dart';
import '../services/api_service.dart';
import 'scenario_screen.dart';
import 'progress_screen.dart';
import 'vocab_prep_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Scenario> _scenarios = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    try {
      final scenarios = await ApiService.getScenarios();
      setState(() {
        _scenarios = scenarios;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '서버에 연결할 수 없어요.\n서버가 켜져 있는지 확인해주세요.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6), // Warm page background
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 2.5,
            ),
            color: Colors.white.withOpacity(0.18),
          ),
          child: const Text(
            'Korrect',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            tooltip: '내 기록',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProgressScreen()),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFF9500), // Orange
                Color(0xFFFFC107), // Yellow
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadScenarios)
              : _ScenarioList(scenarios: _scenarios),
    );
  }
}

class _ScenarioList extends StatelessWidget {
  final List<Scenario> scenarios;

  const _ScenarioList({required this.scenarios});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '어떤 상황을 연습할까요?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: scenarios.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _ScenarioCard(scenario: scenarios[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatefulWidget {
  final Scenario scenario;

  const _ScenarioCard({required this.scenario});

  @override
  State<_ScenarioCard> createState() => _ScenarioCardState();
}

class _ScenarioCardState extends State<_ScenarioCard> {
  bool _isPressed = false;

  Color _getCardColor(String scenarioId) {
    switch (scenarioId) {
      case 'hospital':
        return const Color(0xFF4DD8F0); // Bright cyan blue
      case 'bank':
        return const Color(0xFFFFD600); // Pure saturated yellow
      case 'immigration':
        return const Color(0xFFC97EE8); // Rich lavender
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  Color _getShadowColor(String scenarioId) {
    switch (scenarioId) {
      case 'hospital':
        return const Color(0xFF2BA8C0); // Darker cyan
      case 'bank':
        return const Color(0xFFC9A800); // Darker yellow
      case 'immigration':
        return const Color(0xFFA05EC0); // Darker purple
      default:
        return Colors.grey.shade400;
    }
  }

  String _getShortDescription(String scenarioId) {
    switch (scenarioId) {
      case 'hospital':
        return '증상을 말해요';
      case 'bank':
        return '환전해요';
      case 'immigration':
        return '체류 신청해요';
      default:
        return widget.scenario.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = _getCardColor(widget.scenario.id);
    final shadowColor = _getShadowColor(widget.scenario.id);
    final shortDescription = _getShortDescription(widget.scenario.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.identity()..translate(0, _isPressed ? -4 : 0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VocabPrepScreen(scenario: widget.scenario),
              ),
            );
          },
          splashColor: Colors.white.withOpacity(0.4),
          highlightColor: Colors.white.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Emoji icon
                Text(
                  widget.scenario.id == 'hospital'
                      ? '🏥'
                      : widget.scenario.id == 'bank'
                          ? '🏦'
                          : '🛂',
                  style: const TextStyle(fontSize: 44),
                ),
                const SizedBox(width: 16),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.scenario.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shortDescription,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Play button in circular container
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black54,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
