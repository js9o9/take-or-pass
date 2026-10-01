import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const TakeOrPassApp());

class TakeOrPassApp extends StatelessWidget {
  const TakeOrPassApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'خذها أو مرّرها',
      themeMode: ThemeMode.dark,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF0A0D14),
        cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      ),
      home: const SplashScreen(),
    );
  }
}

enum GameLevel { beginner, normal, pro, expert }
enum GameMode { solo, teams }

extension GameLevelX on GameLevel {
  String get label => switch (this) {
        GameLevel.beginner => 'مبتدئ',
        GameLevel.normal => 'متوسط',
        GameLevel.pro => 'محترف',
        GameLevel.expert => 'متمرس',
      };
  String get subtitle => switch (this) {
        GameLevel.beginner => 'سهل',
        GameLevel.normal => 'طبيعي',
        GameLevel.pro => 'صعب',
        GameLevel.expert => 'صعب جدًا',
      };
  int get difficulty => index + 1;
}

class GameCategory {
  final String id;
  final String name;
  final String emoji;
  const GameCategory(this.id, this.name, this.emoji);
}

const categories = <GameCategory>[
  GameCategory('country', 'ما هي الدولة', '🌍'),
  GameCategory('animal', 'ما هو الحيوان', '🐾'),
  GameCategory('religion', 'أسئلة دينية', '🕌'),
  GameCategory('general', 'أسئلة عامة', '🧠'),
  GameCategory('car', 'ما هي السيارة', '🚗'),
  GameCategory('tech', 'تقنية', '💻'),
  GameCategory('history', 'تاريخ', '🏺'),
  GameCategory('anime', 'أنمي', '⚔️'),
  GameCategory('sports', 'رياضة', '⚽'),
  GameCategory('riddles', 'ألغاز', '🧩'),
];

class QuestionSeed {
  final String category;
  final int difficulty;
  final String prompt;
  final String answer;
  final List<String> aliases;
  final bool hintStyle;
  const QuestionSeed({
    required this.category,
    required this.difficulty,
    required this.prompt,
    required this.answer,
    this.aliases = const [],
    this.hintStyle = false,
  });
}

class RoundQuestion {
  final QuestionSeed seed;
  final int points;
  bool used;
  RoundQuestion(this.seed, this.points, {this.used = false});
}

String normalizeArabic(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'[ـًٌٍَُِّْ]'), '')
    .replaceAll(RegExp(r'\s+'), ' ');

bool answerMatches(String given, QuestionSeed seed) {
  final g = normalizeArabic(given);
  final accepted = [seed.answer, ...seed.aliases].map(normalizeArabic);
  for (final a in accepted) {
    if (g == a) return true;
    if (g.length >= 4 && (a.contains(g) || g.contains(a))) return true;
  }
  return false;
}

class QuestionBank {
  static final Random _rng = Random();

  static Map<String, List<RoundQuestion>> makeRound(
      GameLevel level, Set<String> chosen, {Set<String> avoidPrompts = const {}}) {
    final out = <String, List<RoundQuestion>>{};
    for (final c in categories.where((e) => chosen.contains(e.id))) {
      final target = level.difficulty;
      var pool = seeds
          .where((q) => q.category == c.id && (q.difficulty - target).abs() <= 1)
          .toList();
      pool.shuffle(_rng);
      pool.sort((a, b) {
        final aSeen = avoidPrompts.contains(a.prompt) ? 1 : 0;
        final bSeen = avoidPrompts.contains(b.prompt) ? 1 : 0;
        if (aSeen != bSeen) return aSeen.compareTo(bSeen);
        final da = (a.difficulty - target).abs();
        final db = (b.difficulty - target).abs();
        if (da != db) return da.compareTo(db);
        return _rng.nextBool() ? -1 : 1;
      });
      if (pool.length < 5) {
        pool = seeds.where((q) => q.category == c.id).toList()..shuffle(_rng);
      }
      final picked = pool.take(5).toList()
        ..sort((a, b) => a.difficulty.compareTo(b.difficulty));
      out[c.id] = List.generate(5, (i) => RoundQuestion(picked[i], (i + 1) * 100));
    }
    return out;
  }

  static const seeds = <QuestionSeed>[
    // دول
    QuestionSeed(category:'country',difficulty:1,prompt:'ما الدولة التي عاصمتها الرياض؟',answer:'السعودية',aliases:['المملكة العربية السعودية']),
    QuestionSeed(category:'country',difficulty:1,prompt:'ما الدولة التي عاصمتها القاهرة؟',answer:'مصر'),
    QuestionSeed(category:'country',difficulty:1,prompt:'ما الدولة التي عاصمتها طوكيو؟',answer:'اليابان'),
    QuestionSeed(category:'country',difficulty:2,prompt:'ما الدولة التي عاصمتها بوخارست؟',answer:'رومانيا'),
    QuestionSeed(category:'country',difficulty:2,prompt:'ما الدولة التي عاصمتها هلسنكي؟',answer:'فنلندا'),
    QuestionSeed(category:'country',difficulty:2,prompt:'ما الدولة التي عاصمتها سراييفو؟',answer:'البوسنة والهرسك',aliases:['البوسنة']),
    QuestionSeed(category:'country',difficulty:3,prompt:'ما الدولة التي عاصمتها بيشكيك؟',answer:'قيرغيزستان'),
    QuestionSeed(category:'country',difficulty:3,prompt:'ما الدولة التي عاصمتها دوشنبه؟',answer:'طاجيكستان'),
    QuestionSeed(category:'country',difficulty:3,prompt:'ما الدولة التي عاصمتها بودغوريتسا؟',answer:'الجبل الأسود',aliases:['مونتينيغرو']),
    QuestionSeed(category:'country',difficulty:4,prompt:'ما الدولة التي عاصمتها ياموسوكرو؟',answer:'ساحل العاج'),
    QuestionSeed(category:'country',difficulty:4,prompt:'ما الدولة التي عاصمتها نغيرولمود؟',answer:'بالاو'),
    QuestionSeed(category:'country',difficulty:4,prompt:'ما الدولة التي عاصمتها فونافوتي؟',answer:'توفالو'),

    // حيوانات - تلميحات خفيفة
    QuestionSeed(category:'animal',difficulty:1,prompt:'تلميح بسيط جدًا: له خرطوم طويل.',answer:'الفيل',hintStyle:true),
    QuestionSeed(category:'animal',difficulty:1,prompt:'تلميح بسيط جدًا: طويل الرقبة جدًا.',answer:'الزرافة',hintStyle:true),
    QuestionSeed(category:'animal',difficulty:1,prompt:'تلميح بسيط جدًا: أسرع حيوان بري.',answer:'الفهد',hintStyle:true),
    QuestionSeed(category:'animal',difficulty:2,prompt:'تلميح بسيط جدًا: الثديي الوحيد القادر على الطيران الحقيقي.',answer:'الخفاش',hintStyle:true),
    QuestionSeed(category:'animal',difficulty:2,prompt:'تلميح بسيط جدًا: قارض ضخم شبه مائي.',answer:'كابيبارا',aliases:['الكابيبارا'],hintStyle:true),
    QuestionSeed(category:'animal',difficulty:2,prompt:'تلميح بسيط جدًا: أسترالي وفضلاته مكعبة.',answer:'الومبت',hintStyle:true),
    QuestionSeed(category:'animal',difficulty:3,prompt:'تلميح بسيط جدًا: قريب الزرافة وتظهر خطوط على أرجله.',answer:'أوكابي',aliases:['اوكابي'],hintStyle:true),
    QuestionSeed(category:'animal',difficulty:3,prompt:'تلميح بسيط جدًا: ثديي مغطى بحراشف كيراتينية.',answer:'البنغول',aliases:['بنغول'],hintStyle:true),
    QuestionSeed(category:'animal',difficulty:3,prompt:'تلميح بسيط جدًا: سمندر مكسيكي مشهور بالتجدد.',answer:'أكسولوتل',aliases:['اكسولوتل'],hintStyle:true),
    QuestionSeed(category:'animal',difficulty:4,prompt:'تلميح بسيط جدًا: رئيسي من مدغشقر وله إصبع طويل جدًا.',answer:'آي آي',aliases:['اي اي'],hintStyle:true),
    QuestionSeed(category:'animal',difficulty:4,prompt:'تلميح بسيط جدًا: ثديي بحري قريب من خروف البحر.',answer:'الأطوم',aliases:['الاطوم'],hintStyle:true),
    QuestionSeed(category:'animal',difficulty:4,prompt:'تلميح بسيط جدًا: ثديي إفريقي ليلي آكل للنمل.',answer:'خنزير الأرض',hintStyle:true),

    // دينية
    QuestionSeed(category:'religion',difficulty:1,prompt:'كم عدد أركان الإسلام؟',answer:'خمسة',aliases:['5']),
    QuestionSeed(category:'religion',difficulty:1,prompt:'ما شهر الصيام عند المسلمين؟',answer:'رمضان'),
    QuestionSeed(category:'religion',difficulty:1,prompt:'من النبي الذي ابتلعه الحوت؟',answer:'يونس',aliases:['يونس عليه السلام']),
    QuestionSeed(category:'religion',difficulty:2,prompt:'ما السورة التي وردت فيها البسملة مرتين؟',answer:'النمل',aliases:['سورة النمل']),
    QuestionSeed(category:'religion',difficulty:2,prompt:'من الصحابي الملقب بترجمان القرآن؟',answer:'عبدالله بن عباس',aliases:['ابن عباس']),
    QuestionSeed(category:'religion',difficulty:2,prompt:'من النبي الذي ألان الله له الحديد؟',answer:'داود',aliases:['داود عليه السلام']),
    QuestionSeed(category:'religion',difficulty:3,prompt:'من الصحابي الذي اهتز لموته عرش الرحمن؟',answer:'سعد بن معاذ'),
    QuestionSeed(category:'religion',difficulty:3,prompt:'في أي سورة ذُكر زيد بن حارثة صراحة؟',answer:'الأحزاب',aliases:['سورة الأحزاب']),
    QuestionSeed(category:'religion',difficulty:3,prompt:'من الصحابي الذي جمع القرآن في عهد أبي بكر؟',answer:'زيد بن ثابت'),
    QuestionSeed(category:'religion',difficulty:4,prompt:'من أول سفير في الإسلام إلى المدينة؟',answer:'مصعب بن عمير'),
    QuestionSeed(category:'religion',difficulty:4,prompt:'من الصحابي الملقب بغسيل الملائكة؟',answer:'حنظلة بن أبي عامر',aliases:['حنظلة']),
    QuestionSeed(category:'religion',difficulty:4,prompt:'من صاحب سر النبي ﷺ في أسماء المنافقين؟',answer:'حذيفة بن اليمان',aliases:['حذيفة']),

    // عامة
    QuestionSeed(category:'general',difficulty:1,prompt:'ما أكبر كوكب في المجموعة الشمسية؟',answer:'المشتري'),
    QuestionSeed(category:'general',difficulty:1,prompt:'ما الكوكب الأحمر؟',answer:'المريخ'),
    QuestionSeed(category:'general',difficulty:1,prompt:'ما عاصمة كندا؟',answer:'أوتاوا',aliases:['اوتاوا']),
    QuestionSeed(category:'general',difficulty:2,prompt:'ما أكبر عضو داخلي في جسم الإنسان؟',answer:'الكبد'),
    QuestionSeed(category:'general',difficulty:2,prompt:'ما أكبر أقمار زحل؟',answer:'تيتان'),
    QuestionSeed(category:'general',difficulty:2,prompt:'ما أكبر صحراء حارة في العالم؟',answer:'الصحراء الكبرى'),
    QuestionSeed(category:'general',difficulty:3,prompt:'ما العنصر الكيميائي الذي رمزه W؟',answer:'التنغستن',aliases:['تنجستن']),
    QuestionSeed(category:'general',difficulty:3,prompt:'ما المضيق الذي يفصل آسيا عن أمريكا الشمالية؟',answer:'مضيق بيرنغ',aliases:['بيرنغ','بيرينغ']),
    QuestionSeed(category:'general',difficulty:3,prompt:'ما الحد الفاصل بين القشرة الأرضية والوشاح؟',answer:'انقطاع موهو',aliases:['موهو']),
    QuestionSeed(category:'general',difficulty:4,prompt:'ما أعمق نقطة معروفة في محيطات الأرض؟',answer:'تشالنجر ديب'),
    QuestionSeed(category:'general',difficulty:4,prompt:'ما الحد الفاصل بين الوشاح واللب الخارجي؟',answer:'انقطاع غوتنبرغ',aliases:['غوتنبرغ']),
    QuestionSeed(category:'general',difficulty:4,prompt:'ما أصغر عظمة في جسم الإنسان؟',answer:'عظمة الركاب',aliases:['الركاب']),

    // سيارات - تلميحات خفيفة
    QuestionSeed(category:'car',difficulty:1,prompt:'تلميح بسيط جدًا: سيدان يابانية شهيرة جدًا في الخليج.',answer:'تويوتا كامري',aliases:['كامري'],hintStyle:true),
    QuestionSeed(category:'car',difficulty:1,prompt:'تلميح بسيط جدًا: عضلية أمريكية بشعار حصان.',answer:'فورد موستانج',aliases:['موستانج'],hintStyle:true),
    QuestionSeed(category:'car',difficulty:1,prompt:'تلميح بسيط جدًا: ألمانية وشعارها نجمة ثلاثية.',answer:'مرسيدس بنز',aliases:['مرسيدس'],hintStyle:true),
    QuestionSeed(category:'car',difficulty:2,prompt:'تلميح بسيط جدًا: يابانية رياضية اشتهرت بمحرك 2JZ.',answer:'تويوتا سوبرا',aliases:['سوبرا'],hintStyle:true),
    QuestionSeed(category:'car',difficulty:2,prompt:'تلميح بسيط جدًا: يابانية أسطورية تحمل الرمز R34.',answer:'نيسان سكايلاين جي تي ار',aliases:['جي تي ار','GTR','R34'],hintStyle:true),
    QuestionSeed(category:'car',difficulty:2,prompt:'تلميح بسيط جدًا: إيطالية فاخرة بشعار رمح ثلاثي.',answer:'مازيراتي',hintStyle:true),
    QuestionSeed(category:'car',difficulty:3,prompt:'تلميح بسيط جدًا: سوبركار يابانية V10 نادرة.',answer:'لكزس LFA',aliases:['LFA','لكزس'],hintStyle:true),
    QuestionSeed(category:'car',difficulty:3,prompt:'تلميح بسيط جدًا: ألمانية كلاسيكية بمحرك وسطي وتحمل M.',answer:'BMW M1',aliases:['M1','بي ام دبليو M1'],hintStyle:true),
    QuestionSeed(category:'car',difficulty:3,prompt:'تلميح بسيط جدًا: يابانية بمحرك دوار وأبواب خلفية صغيرة.',answer:'مازدا RX-8',aliases:['RX8','مازدا RX8'],hintStyle:true),
    QuestionSeed(category:'car',difficulty:4,prompt:'تلميح بسيط جدًا: بريطانية بثلاثة مقاعد والسائق في المنتصف.',answer:'ماكلارين F1',aliases:['McLaren F1','F1'],hintStyle:true),
    QuestionSeed(category:'car',difficulty:4,prompt:'تلميح بسيط جدًا: ألمانية نادرة جدًا من الثمانينيات تحمل 959.',answer:'بورشه 959',aliases:['959'],hintStyle:true),
    QuestionSeed(category:'car',difficulty:4,prompt:'تلميح بسيط جدًا: إيطالية كلاسيكية تحمل الاسم F40.',answer:'فيراري F40',aliases:['F40'],hintStyle:true),

    // تقنية
    QuestionSeed(category:'tech',difficulty:1,prompt:'ما نظام تشغيل آيفون؟',answer:'iOS'),
    QuestionSeed(category:'tech',difficulty:1,prompt:'ما الشركة المطورة لنظام ويندوز؟',answer:'مايكروسوفت'),
    QuestionSeed(category:'tech',difficulty:1,prompt:'ما الجهاز الذي يربط شبكات مختلفة؟',answer:'الراوتر',aliases:['راوتر']),
    QuestionSeed(category:'tech',difficulty:2,prompt:'ما وظيفة DNS بشكل أساسي؟',answer:'تحويل أسماء النطاقات إلى عناوين IP',aliases:['تحويل الاسم الى IP','تحويل الدومين الى IP']),
    QuestionSeed(category:'tech',difficulty:2,prompt:'ما أمر ويندوز الذي يعرض إعدادات IP؟',answer:'ipconfig'),
    QuestionSeed(category:'tech',difficulty:2,prompt:'ما البروتوكول الذي يعطي الأجهزة عناوين IP تلقائيًا؟',answer:'DHCP'),
    QuestionSeed(category:'tech',difficulty:3,prompt:'ما البروتوكول الذي يحول عنوان IP إلى MAC داخل الشبكة المحلية؟',answer:'ARP'),
    QuestionSeed(category:'tech',difficulty:3,prompt:'ما بروتوكول التوجيه الذي يستخدم خوارزمية SPF؟',answer:'OSPF'),
    QuestionSeed(category:'tech',difficulty:3,prompt:'ما التقنية التي تقسّم السويتش إلى شبكات منطقية؟',answer:'VLAN'),
    QuestionSeed(category:'tech',difficulty:4,prompt:'ما نوع سجل DNS المستخدم لعنوان IPv6؟',answer:'AAAA'),
    QuestionSeed(category:'tech',difficulty:4,prompt:'ما البروتوكول المستخدم غالبًا لمزامنة الوقت بالشبكة؟',answer:'NTP'),
    QuestionSeed(category:'tech',difficulty:4,prompt:'ما البروتوكول المستخدم لمنع حلقات Layer 2؟',answer:'STP'),

    // تاريخ
    QuestionSeed(category:'history',difficulty:1,prompt:'من فتح القسطنطينية سنة 1453؟',answer:'محمد الفاتح'),
    QuestionSeed(category:'history',difficulty:1,prompt:'من أول إنسان وطأ القمر؟',answer:'نيل أرمسترونغ'),
    QuestionSeed(category:'history',difficulty:1,prompt:'ما عاصمة الدولة العباسية؟',answer:'بغداد'),
    QuestionSeed(category:'history',difficulty:2,prompt:'في أي عام بدأت الحرب العالمية الثانية؟',answer:'1939'),
    QuestionSeed(category:'history',difficulty:2,prompt:'من القائد المسلم في معركة حطين؟',answer:'صلاح الدين الأيوبي',aliases:['صلاح الدين']),
    QuestionSeed(category:'history',difficulty:2,prompt:'ما الحضارة التي اشتهرت بمدينة ماتشو بيتشو؟',answer:'الإنكا',aliases:['الانكا']),
    QuestionSeed(category:'history',difficulty:3,prompt:'من القائد القرطاجي الذي عبر جبال الألب؟',answer:'هانيبال'),
    QuestionSeed(category:'history',difficulty:3,prompt:'ما المعاهدة التي أنهت الحرب العالمية الأولى مع ألمانيا؟',answer:'معاهدة فرساي',aliases:['فرساي']),
    QuestionSeed(category:'history',difficulty:3,prompt:'من آخر خلفاء الدولة الأموية في دمشق؟',answer:'مروان بن محمد'),
    QuestionSeed(category:'history',difficulty:4,prompt:'من القائد المسلم في معركة بلاط الشهداء؟',answer:'عبد الرحمن الغافقي'),
    QuestionSeed(category:'history',difficulty:4,prompt:'ما الإمبراطورية التي كانت عاصمتها تينوتشتيتلان؟',answer:'الأزتك',aliases:['الازتك']),
    QuestionSeed(category:'history',difficulty:4,prompt:'من الإمبراطور البيزنطي أثناء فتح القسطنطينية عام 1453؟',answer:'قسطنطين الحادي عشر'),

    // أنمي
    QuestionSeed(category:'anime',difficulty:1,prompt:'من بطل ناروتو؟',answer:'ناروتو',aliases:['ناروتو أوزوماكي']),
    QuestionSeed(category:'anime',difficulty:1,prompt:'من بطل ون بيس؟',answer:'لوفي',aliases:['مونكي دي لوفي']),
    QuestionSeed(category:'anime',difficulty:1,prompt:'ما اسم أخ ساسكي؟',answer:'إيتاشي',aliases:['ايتاشي']),
    QuestionSeed(category:'anime',difficulty:2,prompt:'من والد غون في Hunter x Hunter؟',answer:'جين فريكس',aliases:['جين']),
    QuestionSeed(category:'anime',difficulty:2,prompt:'من أول هوكاغي لكونوها؟',answer:'هاشيراما سينجو',aliases:['هاشيراما']),
    QuestionSeed(category:'anime',difficulty:2,prompt:'ما اسم قائد الفرقة السادسة في Bleach؟',answer:'بياكويا كوتشيكي',aliases:['بياكويا']),
    QuestionSeed(category:'anime',difficulty:3,prompt:'ما الاسم الحقيقي لـ L في Death Note؟',answer:'L Lawliet',aliases:['لاوليت','إل لاوليت']),
    QuestionSeed(category:'anime',difficulty:3,prompt:'ما اسم تقنية غوجو التي تجمع الأزرق والأحمر؟',answer:'Hollow Purple',aliases:['هولو بيربل','البنفسجي']),
    QuestionSeed(category:'anime',difficulty:3,prompt:'من قائد العناكب في Hunter x Hunter؟',answer:'كرولو لوسيلفر',aliases:['كرولو']),
    QuestionSeed(category:'anime',difficulty:4,prompt:'ما اسم الزانباكتو الخاص برُوكيا؟',answer:'Sode no Shirayuki',aliases:['سوديه نو شيرايوكي']),
    QuestionSeed(category:'anime',difficulty:4,prompt:'ما اسم بنكاي بياكويا كوتشيكي؟',answer:'Senbonzakura Kageyoshi',aliases:['سينبونزاكورا كاغيوشي']),
    QuestionSeed(category:'anime',difficulty:4,prompt:'ما اسم الشيطان المرتبط بدينجي في Chainsaw Man؟',answer:'بوتشيتا'),

    // رياضة
    QuestionSeed(category:'sports',difficulty:1,prompt:'كم لاعبًا في فريق كرة القدم داخل الملعب؟',answer:'11',aliases:['أحد عشر','احد عشر']),
    QuestionSeed(category:'sports',difficulty:1,prompt:'في أي رياضة تقام بطولة ويمبلدون؟',answer:'التنس'),
    QuestionSeed(category:'sports',difficulty:1,prompt:'كم دقيقة في مباراة كرة القدم الأساسية؟',answer:'90',aliases:['تسعين']),
    QuestionSeed(category:'sports',difficulty:2,prompt:'كم لاعبًا في فريق الكرة الطائرة داخل الملعب؟',answer:'6',aliases:['ستة']),
    QuestionSeed(category:'sports',difficulty:2,prompt:'ما طول حوض السباحة الأولمبي؟',answer:'50 متر',aliases:['50']),
    QuestionSeed(category:'sports',difficulty:2,prompt:'كم حفرة في جولة الغولف القياسية؟',answer:'18',aliases:['ثمانية عشر']),
    QuestionSeed(category:'sports',difficulty:3,prompt:'في أي رياضة يوجد مركز Libero؟',answer:'الكرة الطائرة',aliases:['طائرة']),
    QuestionSeed(category:'sports',difficulty:3,prompt:'أي رياضة تستخدم مصطلح Ippon؟',answer:'الجودو'),
    QuestionSeed(category:'sports',difficulty:3,prompt:'كم نقطة يحصل عليها الفائز بسباق Formula 1؟',answer:'25',aliases:['خمسة وعشرون']),
    QuestionSeed(category:'sports',difficulty:4,prompt:'ما الدولة التي استضافت أول كأس عالم عام 1930؟',answer:'أوروغواي',aliases:['اورغواي','أوروجواي']),
    QuestionSeed(category:'sports',difficulty:4,prompt:'كم مجموعة كحد أقصى في مباراة الرجال بالغراند سلام؟',answer:'5',aliases:['خمسة']),
    QuestionSeed(category:'sports',difficulty:4,prompt:'من أول منتخب فاز بكأس العالم مرتين متتاليتين؟',answer:'إيطاليا',aliases:['ايطاليا']),

    // ألغاز
    QuestionSeed(category:'riddles',difficulty:1,prompt:'شيء له أسنان ولا يعض، ما هو؟',answer:'المشط'),
    QuestionSeed(category:'riddles',difficulty:1,prompt:'شيء كلما أخذت منه كبر، ما هو؟',answer:'الحفرة'),
    QuestionSeed(category:'riddles',difficulty:1,prompt:'له عين ولا يرى، ما هو؟',answer:'الإبرة',aliases:['الابرة']),
    QuestionSeed(category:'riddles',difficulty:2,prompt:'ما الشيء الذي يسمع بلا أذن ويتكلم بلا لسان؟',answer:'الصدى'),
    QuestionSeed(category:'riddles',difficulty:2,prompt:'شيء تملكه ويستخدمه الناس أكثر منك، ما هو؟',answer:'اسمك'),
    QuestionSeed(category:'riddles',difficulty:2,prompt:'أين يوجد البحر بلا ماء؟',answer:'الخريطة'),
    QuestionSeed(category:'riddles',difficulty:3,prompt:'شيء إذا نطقته كسرته، ما هو؟',answer:'الصمت'),
    QuestionSeed(category:'riddles',difficulty:3,prompt:'ما الذي يسافر حول العالم وهو ثابت في زاويته؟',answer:'الطابع البريدي',aliases:['الطابع']),
    QuestionSeed(category:'riddles',difficulty:3,prompt:'ما الذي يزداد كلما شاركته؟',answer:'المعرفة'),
    QuestionSeed(category:'riddles',difficulty:4,prompt:'ما الذي له مفاتيح ولا يفتح أبوابًا؟',answer:'البيانو'),
    QuestionSeed(category:'riddles',difficulty:4,prompt:'ما الذي لا يمكن استخدامه حتى يُكسر؟',answer:'البيضة'),
    QuestionSeed(category:'riddles',difficulty:4,prompt:'شيء يولد كبيرًا ويموت صغيرًا، ما هو؟',answer:'الشمعة'),
  ];
}

class AppPrefs {
  static const _level = 'last_level';
  static const _mode = 'last_mode';
  static const _players = 'last_players';
  static const _categories = 'last_categories';
  static const _teamCount = 'last_team_count';
  static const _sound = 'sound_enabled';
  static const _questionHistory = 'question_history';
  static const _results = 'recent_results';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<SetupSnapshot> loadSetup() async {
    final p = await _prefs;
    final levelIndex = (p.getInt(_level) ?? GameLevel.normal.index)
        .clamp(0, GameLevel.values.length - 1)
        .toInt();
    final modeIndex = (p.getInt(_mode) ?? GameMode.solo.index)
        .clamp(0, GameMode.values.length - 1)
        .toInt();
    final savedPlayers = p.getStringList(_players);
    final savedCategories = p.getStringList(_categories);
    return SetupSnapshot(
      level: GameLevel.values[levelIndex],
      mode: GameMode.values[modeIndex],
      players: (savedPlayers == null || savedPlayers.length < 2)
          ? const ['سكوربيو', 'جواد', 'عبدالله']
          : savedPlayers,
      categories: (savedCategories == null || savedCategories.isEmpty)
          ? categories.map((e) => e.id).toSet()
          : savedCategories.toSet(),
      teamCount: max(2, p.getInt(_teamCount) ?? 2),
      soundEnabled: p.getBool(_sound) ?? true,
    );
  }

  static Future<void> saveSetup({
    required GameLevel level,
    required GameMode mode,
    required List<String> players,
    required Set<String> categories,
    required int teamCount,
    required bool soundEnabled,
  }) async {
    final p = await _prefs;
    await p.setInt(_level, level.index);
    await p.setInt(_mode, mode.index);
    await p.setStringList(_players, players);
    await p.setStringList(_categories, categories.toList());
    await p.setInt(_teamCount, teamCount);
    await p.setBool(_sound, soundEnabled);
  }

  static Future<Set<String>> loadQuestionHistory() async {
    final p = await _prefs;
    return (p.getStringList(_questionHistory) ?? const <String>[]).toSet();
  }

  static Future<void> rememberQuestions(Iterable<String> prompts) async {
    final p = await _prefs;
    final merged = <String>[
      ...prompts,
      ...(p.getStringList(_questionHistory) ?? const <String>[]),
    ];
    final unique = <String>[];
    for (final q in merged) {
      if (!unique.contains(q)) unique.add(q);
      if (unique.length >= 90) break;
    }
    await p.setStringList(_questionHistory, unique);
  }

  static Future<void> addResult(String line) async {
    final p = await _prefs;
    final current = p.getStringList(_results) ?? <String>[];
    await p.setStringList(_results, [line, ...current].take(8).toList());
  }

  static Future<List<String>> loadResults() async {
    final p = await _prefs;
    return p.getStringList(_results) ?? const <String>[];
  }
}

class SetupSnapshot {
  final GameLevel level;
  final GameMode mode;
  final List<String> players;
  final Set<String> categories;
  final int teamCount;
  final bool soundEnabled;
  const SetupSnapshot({
    required this.level,
    required this.mode,
    required this.players,
    required this.categories,
    required this.teamCount,
    required this.soundEnabled,
  });
}

class SoundFx {
  SoundFx(this.enabled);
  bool enabled;
  final AudioPlayer _player = AudioPlayer();

  Future<void> correct() => _play('sounds/correct.wav', HapticFeedback.mediumImpact);
  Future<void> wrong() => _play('sounds/wrong.wav', HapticFeedback.lightImpact);
  Future<void> timeout() => _play('sounds/timeout.wav', HapticFeedback.heavyImpact);
  Future<void> tap() async {
    if (!enabled) return;
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> _play(String asset, Future<void> Function() haptic) async {
    if (!enabled) return;
    await haptic();
    await _player.stop();
    await _player.play(AssetSource(asset));
  }

  Future<void> dispose() => _player.dispose();
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SetupScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: [cs.primaryContainer, cs.tertiaryContainer],
                    ),
                  ),
                  child: const Icon(Icons.style_rounded, size: 50),
                ),
                const SizedBox(height: 18),
                const Text('خذها أو مرّرها',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('اختَر البطاقة • جاوب • أو مرّرها',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  GameLevel level = GameLevel.normal;
  GameMode mode = GameMode.solo;
  final players = <TextEditingController>[];
  final selected = <String>{};
  int teamCount = 2;
  bool soundEnabled = true;
  bool loading = true;
  List<String> recentResults = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await AppPrefs.loadSetup();
    final results = await AppPrefs.loadResults();
    if (!mounted) return;
    setState(() {
      level = snap.level;
      mode = snap.mode;
      teamCount = snap.teamCount;
      soundEnabled = snap.soundEnabled;
      selected
        ..clear()
        ..addAll(snap.categories);
      for (final p in players) {
        p.dispose();
      }
      players
        ..clear()
        ..addAll(snap.players.map((e) => TextEditingController(text: e)));
      recentResults = results;
      loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in players) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get names => players
      .map((e) => e.text.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void addPlayer() {
    if (players.length >= 12) return;
    setState(() => players.add(
        TextEditingController(text: 'لاعب ${players.length + 1}')));
  }

  void removePlayer(int i) {
    if (players.length <= 2) return;
    players[i].dispose();
    setState(() {
      players.removeAt(i);
      if (players.length < 4) mode = GameMode.solo;
      teamCount = min(teamCount, max(2, players.length ~/ 2));
    });
  }

  Future<void> start() async {
    if (names.length < 2 || selected.isEmpty) return;
    final finalMode = names.length >= 4 ? mode : GameMode.solo;
    final maxTeams = min(4, max(2, names.length ~/ 2));
    final finalTeamCount = teamCount.clamp(2, maxTeams).toInt();
    await AppPrefs.saveSetup(
      level: level,
      mode: finalMode,
      players: names,
      categories: selected,
      teamCount: finalTeamCount,
      soundEnabled: soundEnabled,
    );
    final avoid = await AppPrefs.loadQuestionHistory();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        players: names,
        level: level,
        mode: finalMode,
        teamCount: finalTeamCount,
        selectedCategories: selected,
        avoidPrompts: avoid,
        soundEnabled: soundEnabled,
      ),
    ));
    final results = await AppPrefs.loadResults();
    if (mounted) setState(() => recentResults = results);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final teamAvailable = names.length >= 4;
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('خذها أو مرّرها 🎴'),
          actions: [
            IconButton(
              tooltip: soundEnabled ? 'كتم الأصوات' : 'تشغيل الأصوات',
              onPressed: () => setState(() => soundEnabled = !soundEnabled),
              icon: Icon(soundEnabled ? Icons.volume_up : Icons.volume_off),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [cs.primaryContainer, cs.surfaceContainerHighest],
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.style_rounded, size: 44),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('جهّز الجولة',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text('كل جولة تحاول تتجنب أسئلة الجولة السابقة تلقائيًا.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'مستوى اللعب',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: GameLevel.values
                      .map((l) => ChoiceChip(
                            selected: level == l,
                            avatar: Text(['🟢', '🔵', '🟠', '🔴'][l.index]),
                            label: Text('${l.label} — ${l.subtitle}'),
                            onSelected: (_) => setState(() => level = l),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'اللاعبون',
                trailing: TextButton.icon(
                  onPressed: addPlayer,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('لاعب'),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < players.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: players[i],
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  prefixIcon: i == 0
                                      ? const Icon(Icons.bolt_rounded)
                                      : const Icon(Icons.person_outline),
                                  labelText: i == 0
                                      ? 'سكوربيو'
                                      : 'اللاعب ${i + 1}',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            if (players.length > 2)
                              IconButton(
                                onPressed: () => removePlayer(i),
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (teamAvailable) ...[
                const SizedBox(height: 14),
                _Section(
                  title: 'نمط اللعب',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<GameMode>(
                        segments: const [
                          ButtonSegment(
                              value: GameMode.solo,
                              label: Text('فردي'),
                              icon: Icon(Icons.person)),
                          ButtonSegment(
                              value: GameMode.teams,
                              label: Text('فرق'),
                              icon: Icon(Icons.groups)),
                        ],
                        selected: {mode},
                        onSelectionChanged: (v) =>
                            setState(() => mode = v.first),
                      ),
                      if (mode == GameMode.teams) ...[
                        const SizedBox(height: 14),
                        Text('عدد الفرق: $teamCount',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Slider(
                          value: teamCount
                              .clamp(2, min(4, max(2, names.length ~/ 2)))
                              .toDouble(),
                          min: 2,
                          max: min(4, max(2, names.length ~/ 2)).toDouble(),
                          divisions: max(
                              1,
                              min(4, max(2, names.length ~/ 2)) - 2),
                          label: '$teamCount',
                          onChanged: (v) =>
                              setState(() => teamCount = v.round()),
                        ),
                        Text(
                          'يوزَّع اللاعبون بالتناوب بين الفرق، والنقاط تُحسب للفريق.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _Section(
                title: 'الفئات',
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => setState(() {
                    if (v == 'all') {
                      selected
                        ..clear()
                        ..addAll(categories.map((e) => e.id));
                    } else {
                      selected.clear();
                    }
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'all', child: Text('اختيار الكل')),
                    PopupMenuItem(value: 'none', child: Text('مسح الكل')),
                  ],
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map((c) => FilterChip(
                            selected: selected.contains(c.id),
                            label: Text('${c.emoji} ${c.name}'),
                            onSelected: (v) => setState(() => v
                                ? selected.add(c.id)
                                : selected.remove(c.id)),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                title: const Text('الأصوات والاهتزاز'),
                subtitle: const Text('صوت للإجابة الصحيحة والخطأ وانتهاء الوقت'),
                value: soundEnabled,
                onChanged: (v) => setState(() => soundEnabled = v),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('ابدأ اللعبة',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              if (recentResults.isNotEmpty) ...[
                const SizedBox(height: 18),
                _Section(
                  title: 'آخر النتائج',
                  child: Column(
                    children: recentResults
                        .take(4)
                        .map((r) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.emoji_events_outlined),
                              title: Text(r),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

class GameScreen extends StatefulWidget {
  final List<String> players;
  final GameLevel level;
  final GameMode mode;
  final int teamCount;
  final Set<String> selectedCategories;
  final Set<String> avoidPrompts;
  final bool soundEnabled;
  const GameScreen({
    super.key,
    required this.players,
    required this.level,
    required this.mode,
    required this.teamCount,
    required this.selectedCategories,
    required this.avoidPrompts,
    required this.soundEnabled,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final Map<String, List<RoundQuestion>> round;
  late final List<String> entities;
  late final List<List<String>> teamMembers;
  late final List<int> scores;
  late final SoundFx sound;
  int turn = 0, active = 0, tries = 0, seconds = 60;
  Timer? timer;
  RoundQuestion? current;
  GameCategory? currentCategory;
  final answerController = TextEditingController();
  String feedback = '';
  bool resultSaved = false;

  @override
  void initState() {
    super.initState();
    sound = SoundFx(widget.soundEnabled);
    round = QuestionBank.makeRound(widget.level, widget.selectedCategories,
        avoidPrompts: widget.avoidPrompts);
    if (widget.mode == GameMode.teams && widget.players.length >= 4) {
      entities = List.generate(widget.teamCount, (i) => 'الفريق ${i + 1}');
      teamMembers = List.generate(widget.teamCount, (_) => []);
      for (int i = 0; i < widget.players.length; i++) {
        teamMembers[i % widget.teamCount].add(widget.players[i]);
      }
    } else {
      entities = [...widget.players];
      teamMembers = [];
    }
    scores = List.filled(entities.length, 0);
  }

  @override
  void dispose() {
    timer?.cancel();
    answerController.dispose();
    sound.dispose();
    super.dispose();
  }

  void startTimer() {
    timer?.cancel();
    seconds = 60;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => seconds--);
      if (seconds <= 0) {
        t.cancel();
        sound.timeout();
        pass(fromTimeout: true);
      }
    });
  }

  void openQuestion(GameCategory c, RoundQuestion q) {
    if (current != null || q.used) return;
    sound.tap();
    setState(() {
      current = q;
      currentCategory = c;
      active = turn;
      tries = 0;
      feedback = '';
      answerController.clear();
    });
    startTimer();
  }

  void pass({bool fromTimeout = false}) {
    if (current == null) return;
    tries++;
    if (tries >= entities.length) {
      reveal();
      return;
    }
    if (!fromTimeout) sound.tap();
    setState(() {
      active = (active + 1) % entities.length;
      feedback = fromTimeout ? '⏰ انتهى الوقت — انتقل السؤال' : '';
      answerController.clear();
    });
    startTimer();
  }

  void reveal() {
    if (current == null) return;
    timer?.cancel();
    sound.wrong();
    setState(() => feedback =
        '👁️ الإجابة: ${current!.seed.answer} — انتهت البطاقة بدون نقاط');
    Future.delayed(const Duration(milliseconds: 1500), () => finish(false));
  }

  void submit() {
    if (current == null || answerController.text.trim().isEmpty) return;
    if (answerMatches(answerController.text, current!.seed)) {
      timer?.cancel();
      sound.correct();
      setState(() {
        scores[active] += current!.points;
        feedback = '✅ صحيحة! +${current!.points} لـ ${entities[active]}';
      });
      Future.delayed(const Duration(milliseconds: 1100), () => finish(true));
    } else {
      sound.wrong();
      setState(() => feedback = '❌ غير صحيحة — ينتقل السؤال للي بعده');
      Future.delayed(const Duration(milliseconds: 650), pass);
    }
  }

  Future<void> finish(bool scored) async {
    if (!mounted || current == null) return;
    timer?.cancel();
    setState(() {
      current!.used = true;
      current = null;
      currentCategory = null;
      turn = (turn + 1) % entities.length;
      feedback = '';
      answerController.clear();
      seconds = 60;
    });
    if (remaining == 0) await _saveResult();
  }

  Future<void> _saveResult() async {
    if (resultSaved) return;
    resultSaved = true;
    final ranking = List<int>.generate(entities.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final top = scores[ranking.first];
    final winners = ranking.where((i) => scores[i] == top).map((i) => entities[i]);
    final line = winners.length == 1
        ? '${winners.first} فاز بـ $top نقطة — ${widget.level.label}'
        : 'تعادل ${winners.join(' و ')} بـ $top نقطة — ${widget.level.label}';
    await AppPrefs.addResult(line);
    await AppPrefs.rememberQuestions(
      round.values.expand((e) => e).map((q) => q.seed.prompt),
    );
  }

  int get remaining =>
      round.values.expand((e) => e).where((q) => !q.used).length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('خذها أو مرّرها 🎴'),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Chip(label: Text('${widget.level.label} • $remaining')),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  entities.length,
                  (i) => SizedBox(
                    width: 160,
                    child: Card(
                      color: i == turn ? cs.primaryContainer : null,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Text(entities[i],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            if (teamMembers.isNotEmpty)
                              Text(teamMembers[i].join(' • '),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11)),
                            Text('${scores[i]}',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('الدور: ${entities[turn]}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Text('${widget.level.label} — ${widget.level.subtitle}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 800
                      ? 5
                      : constraints.maxWidth > 500
                          ? 3
                          : 2;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.72,
                    children: categories
                        .where((c) => widget.selectedCategories.contains(c.id))
                        .map(
                          (c) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Text('${c.emoji} ${c.name}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  for (final q in round[c.id]!)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 3),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.tonal(
                                            onPressed:
                                                q.used || current != null
                                                    ? null
                                                    : () => openQuestion(c, q),
                                            child:
                                                Text(q.used ? '✓' : '${q.points}'),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (current != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${currentCategory!.emoji} ${currentCategory!.name}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                            ),
                            Chip(label: Text('${current!.points} نقطة')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (current!.seed.hintStyle)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: cs.surfaceContainerHighest,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تلميح خفيف',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(current!.seed.prompt,
                                    style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                          )
                        else
                          Text(current!.seed.prompt,
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text('الإجابة لـ ${entities[active]}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                            Chip(
                              avatar: const Icon(Icons.timer_outlined, size: 18),
                              label: Text('$seconds',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: seconds <= 10 ? cs.error : null,
                                  )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: answerController,
                          onSubmitted: (_) => submit(),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'اكتب الإجابة...',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: submit,
                              icon: const Icon(Icons.check),
                              label: const Text('تأكيد'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => pass(),
                              icon: const Icon(Icons.skip_next),
                              label: const Text('مرّر'),
                            ),
                            OutlinedButton.icon(
                              onPressed: reveal,
                              icon: const Icon(Icons.visibility),
                              label: const Text('إظهار الإجابة'),
                            ),
                          ],
                        ),
                        if (feedback.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(feedback,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text('البطاقات المتبقية: $remaining',
                  style: TextStyle(color: cs.onSurfaceVariant)),
              if (remaining == 0) ...[
                const SizedBox(height: 14),
                _ResultCard(entities: entities, scores: scores),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.replay),
                  label: const Text('جولة جديدة بإعدادات محفوظة'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final List<String> entities;
  final List<int> scores;
  const _ResultCard({required this.entities, required this.scores});

  @override
  Widget build(BuildContext context) {
    final order = List<int>.generate(entities.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final top = scores[order.first];
    final winners = order.where((i) => scores[i] == top).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(winners.length == 1 ? '🏆 الفائز' : '🏆 تعادل',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(winners.map((i) => entities[i]).join(' و '),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            for (int rank = 0; rank < order.length; rank++)
              ListTile(
                dense: true,
                leading: CircleAvatar(child: Text('${rank + 1}')),
                title: Text(entities[order[rank]]),
                trailing: Text('${scores[order[rank]]} نقطة',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
