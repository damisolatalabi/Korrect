import 'package:flutter/material.dart';
import '../models/scenario_model.dart';
import 'scenario_screen.dart';
import 'package:confetti/confetti.dart';

class VocabPrepScreen extends StatefulWidget {
  final Scenario scenario;

  const VocabPrepScreen({super.key, required this.scenario});

  @override
  State<VocabPrepScreen> createState() => _VocabPrepScreenState();
}

class _VocabPrepScreenState extends State<VocabPrepScreen> {
  final Set<String> _selectedVerbs = {}; // tracks which verb chips the child tapped
  final Set<String> _selectedNouns = {}; // tracks which noun chips the child tapped
  final List<String?> _sentence = [null, null]; // holds the two parts of the sentence

  late ConfettiController _confettiController; // controls when confetti fires

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2), // confetti lasts 2 seconds
    );
  }

  @override
  void dispose() {
    _confettiController.dispose(); // clean up controller when screen closes
    super.dispose();
  }

  // gets the vocab data for the current scenario, falls back to 'bank' if not found
  Map<String, dynamic> get _data =>
      _vocabData[widget.scenario.id] ?? _vocabData['bank']!;

  static const Map<String, Map<String, dynamic>> _vocabData = {
    'hospital': {
      'situation': '병원에서',       // "At the hospital" in Korean
      'situationRu': 'В больнице', // "At the hospital" in Russian
      'icon': '🏥',
      'verbs': ['아프다', '가다', '말하다', '먹다'],                    // "To hurt, To go, To speak, To eat"
      'verbsRu': ['болеть', 'идти', 'говорить', 'есть'],            // Russian translations of verbs
      'nouns': ['머리', '배', '팔', '다리', '열'],                     // "Head, Stomach, Arm, Leg, Fever"
      'nounsRu': ['голова', 'живот', 'рука', 'нога', 'температура'], // Russian translations of nouns
      'sentenceTemplate': ['___가', '아파요'],  // sentence = "___ hurts" — blank is first word
      'blankIndex': 0,                        // position 0 is the blank
      'blankOptions': ['머리', '배', '팔', '다리'], // word choices to fill the blank
    },
    'bank': {
      'situation': '은행에서',      // "At the bank" in Korean
      'situationRu': 'В банке',   // "At the bank" in Russian
      'icon': '🏦',
      'verbs': ['바꾸다', '보내다', '열다', '내다'],               // "To exchange, To send, To open, To pay"
      'verbsRu': ['обменять', 'отправить', 'открыть', 'платить'], // Russian translations
      'nouns': ['돈', '통장', '카드', '환율'],                    // "Money, Account, Card, Exchange rate"
      'nounsRu': ['деньги', 'счёт', 'карта', 'курс'],           // Russian translations
      'sentenceTemplate': ['돈을', '___싶어요'], // sentence = "Money ___want" — blank is second word
      'blankIndex': 1,                         // position 1 is the blank
      'blankOptions': ['바꾸고', '보내고', '찾고'], // "exchange, send, withdraw"
    },
    'immigration': {
      'situation': '출입국에서',                    // "At immigration" in Korean
      'situationRu': 'В миграционной службе',    // "At immigration" in Russian
      'icon': '✈️',
      'verbs': ['신청하다', '제출하다', '연장하다', '받다'],          // "To apply, To submit, To extend, To receive"
      'verbsRu': ['подать', 'представить', 'продлить', 'получить'], // Russian translations
      'nouns': ['비자', '여권', '서류', '체류'],                    // "Visa, Passport, Documents, Residence"
      'nounsRu': ['виза', 'паспорт', 'документы', 'проживание'],  // Russian translations
      'sentenceTemplate': ['비자를', '___싶어요'], // sentence = "Visa ___want"
      'blankIndex': 1,
      'blankOptions': ['연장하고', '신청하고', '받고'], // "extend, apply, receive"
    },
  };

  // toggles a verb chip on/off when tapped
  void _toggleVerb(String verb) =>
      setState(() => _selectedVerbs.contains(verb)
          ? _selectedVerbs.remove(verb)
          : _selectedVerbs.add(verb));

  // toggles a noun chip on/off when tapped
  void _toggleNoun(String noun) =>
      setState(() => _selectedNouns.contains(noun)
          ? _selectedNouns.remove(noun)
          : _selectedNouns.add(noun));

  // fills the blank in the sentence when child taps a word option + fires confetti
  void _fillBlank(String word) {
    final blankIndex = _data['blankIndex'] as int;
    setState(() => _sentence[blankIndex] = word);
    _confettiController.play(); // 🎉 fire confetti when blank is filled!
  }

  // returns true only when all blanks in the sentence are filled
  bool get _sentenceComplete => !_sentence.contains(null);

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final verbs = List<String>.from(data['verbs']);
    final verbsRu = List<String>.from(data['verbsRu']);   // Russian verb translations
    final nouns = List<String>.from(data['nouns']);
    final nounsRu = List<String>.from(data['nounsRu']);   // Russian noun translations
    final template = List<String>.from(data['sentenceTemplate']);
    final blankOptions = List<String>.from(data['blankOptions']);
    final blankIndex = data['blankIndex'] as int;

    // pre-fill the non-blank parts of the sentence on every build
    for (int i = 0; i < template.length; i++) {
      if (i != blankIndex) _sentence[i] = template[i];
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6), // warm cream background
      appBar: AppBar(
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Container(
          // pill-shaped logo container
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.5),
            color: Colors.white.withOpacity(0.18),
          ),
          child: const Text('Korrect',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              shadows: [Shadow(color: Colors.black26, offset: Offset(0, 3), blurRadius: 0)],
            )),
        ),
        actions: [
          // step counter showing "1 / 3" — this is step 1 of 3 in the app flow
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('1 / 3',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
        flexibleSpace: Container(
          // orange to yellow gradient header — same as home screen
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8C00), Color(0xFFFFD000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      // wrap body in Stack so confetti can float on top of everything
      body: Stack(
        children: [

          // ── MAIN CONTENT ────────────────────────────────────────────
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [

                    // ── SITUATION CARD ────────────────────────────────
                    _SectionLabel(
                      korean: '오늘의 상황',        // "Today's situation"
                      russian: 'Ситуация сегодня', // "Today's situation" in Russian
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD600), // saturated yellow card
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(
                          color: Color(0xFFC9A800), // darker yellow shadow
                          offset: Offset(0, 4),
                          blurRadius: 0,
                        )],
                      ),
                      child: Row(
                        children: [
                          Text(data['icon'], style: const TextStyle(fontSize: 36)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['situation'],   // Korean situation name
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF5a3a00))),
                              Text(data['situationRu'], // Russian situation name below
                                style: const TextStyle(fontSize: 12, color: Color(0xFF7a5200))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── VERB CHIPS ────────────────────────────────────
                    _VocabCard(
                      koreanTitle: '🔵 어떤 동사가 필요해요?', // "What verbs do you need?"
                      russianTitle: 'Какие глаголы нужны?',  // same in Russian
                      words: verbs,
                      translations: verbsRu,
                      selected: _selectedVerbs,
                      chipColor: ChipColor.blue,
                      onTap: _toggleVerb,
                    ),
                    const SizedBox(height: 12),

                    // ── NOUN CHIPS ────────────────────────────────────
                    _VocabCard(
                      koreanTitle: '🟢 관련 단어는요?',    // "What are the related words?"
                      russianTitle: 'Связанные слова?', // same in Russian
                      words: nouns,
                      translations: nounsRu,
                      selected: _selectedNouns,
                      chipColor: ChipColor.green,
                      onTap: _toggleNoun,
                    ),
                    const SizedBox(height: 12),

                    // ── SENTENCE BUILDER ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(
                          color: Color(0xFFE0D5B0),
                          offset: Offset(0, 3),
                          blurRadius: 0,
                        )],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🟡 문장을 만들어봐요!',   // "Let's make a sentence!"
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                          const Text('Составьте предложение!', // "Make a sentence!" in Russian
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 10),

                          // sentence display box with blank
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFFD700), width: 2),
                            ),
                            child: Row(
                              children: List.generate(_sentence.length, (i) {
                                final word = _sentence[i];
                                final isFilled = word != null && i == blankIndex; // blank has been filled
                                final isStatic = i != blankIndex;                 // this part is fixed text
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      // filled blank = yellow, empty blank = white, static = transparent
                                      color: isStatic ? Colors.transparent : (isFilled ? const Color(0xFFFFD600) : Colors.white),
                                      borderRadius: BorderRadius.circular(10),
                                      border: isStatic ? null : Border.all(color: const Color(0xFFFFD700), width: 2),
                                    ),
                                    child: Text(
                                      isStatic ? template[i] : (word ?? '_____'),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isStatic ? const Color(0xFF7a5200) : const Color(0xFF3a2000),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // word options to fill the blank
                          Wrap(
                            spacing: 8,
                            children: blankOptions.map((w) => GestureDetector(
                              onTap: () => _fillBlank(w),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  // selected option = dark orange, unselected = light orange
                                  color: _sentence[blankIndex] == w
                                    ? const Color(0xFFBA7517)
                                    : const Color(0xFFFAEEDA),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFEF9F27), width: 2),
                                ),
                                child: Text(w,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _sentence[blankIndex] == w
                                      ? Colors.white
                                      : const Color(0xFF633806),
                                  )),
                              ),
                            )).toList(),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '단어를 눌러서 문장을 완성해봐요\nНажмите на слово, чтобы завершить предложение',
                            // "Tap a word to complete the sentence" in Korean and Russian
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // ── START BUTTON ────────────────────────────────────────
              // grey and disabled until sentence is complete, then turns green
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: GestureDetector(
                  onTap: _sentenceComplete ? () {
                    // go straight to chat — no popup!
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScenarioScreen(scenario: widget.scenario),
                      ),
                    );
                  } : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _sentenceComplete ? const Color(0xFF27AE60) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: _sentenceComplete ? const Color(0xFF1a7a42) : Colors.transparent,
                          offset: const Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      '대화 시작하기 ▶', // "Start the conversation"
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _sentenceComplete ? Colors.white : Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── CONFETTI ────────────────────────────────────────────────
          // sits on top of everything, fires from the top center when blank is filled
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive, // confetti flies in all directions
              numberOfParticles: 30,   // how many confetti pieces
              gravity: 0.3,            // how fast they fall
              colors: const [
                Color(0xFFFFD600), // yellow — matches bank card
                Color(0xFF27AE60), // green — matches start button
                Color(0xFF4DD8F0), // cyan — matches hospital card
                Color(0xFFC97EE8), // lavender — matches immigration card
                Color(0xFFFF8C00), // orange — matches header
              ],
            ),
          ),

        ],
      ),
    );
  }
}

enum ChipColor { blue, green }

class _VocabCard extends StatelessWidget {
  final String koreanTitle, russianTitle;
  final List<String> words, translations;
  final Set<String> selected;
  final ChipColor chipColor;
  final Function(String) onTap;

  const _VocabCard({
    required this.koreanTitle,
    required this.russianTitle,
    required this.words,
    required this.translations,
    required this.selected,
    required this.chipColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBlue = chipColor == ChipColor.blue;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(
          color: Color(0xFFE0D5B0),
          offset: Offset(0, 3),
          blurRadius: 0,
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(koreanTitle,  // Korean section heading
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
          Text(russianTitle, // Russian section heading below
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: List.generate(words.length, (i) {
              final w = words[i];         // Korean word
              final ru = translations[i]; // Russian translation
              final isSelected = selected.contains(w);
              return GestureDetector(
                onTap: () => onTap(w),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    // selected = solid blue/green, unselected = light blue/green
                    color: isSelected
                      ? (isBlue ? const Color(0xFF378ADD) : const Color(0xFF639922))
                      : (isBlue ? const Color(0xFFE8F4FD) : const Color(0xFFEAF3DE)),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isSelected
                        ? (isBlue ? const Color(0xFF185FA5) : const Color(0xFF3B6D11))
                        : (isBlue ? const Color(0xFF93C8F0) : const Color(0xFF97C459)),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(w,  // Korean word on top
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white
                            : (isBlue ? const Color(0xFF0a4a7a) : const Color(0xFF274d0a)),
                        )),
                      Text(ru, // Russian translation below in smaller text
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white70
                            : (isBlue ? const Color(0xFF5a8abf) : const Color(0xFF5a8a3a)),
                        )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// section label widget showing Korean title and Russian subtitle
class _SectionLabel extends StatelessWidget {
  final String korean, russian;
  const _SectionLabel({required this.korean, required this.russian});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(korean,  // Korean label
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: Color(0xFFb85c00), letterSpacing: 0.06)),
      Text(russian, // Russian label below
        style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ],
  );
}