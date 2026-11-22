/// 三语文本：传入当前语言代码，返回对应文案。
///
/// 项目里大量文案原本是"中/英"二元（`isEnglish ? ... : ...`），加日语之后
/// 再用三元就会到处嵌套，这里统一收口到一个函数。
String tri(String language, {required String zh, required String en}) =>
    language == 'en' ? en : zh;

/// 带日语的三语文本。
String tri3(
  String language, {
  required String zh,
  required String en,
  required String ja,
}) => switch (language) {
  'en' => en,
  'ja' => ja,
  _ => zh,
};
