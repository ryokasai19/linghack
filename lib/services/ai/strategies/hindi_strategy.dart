import '../language_strategy.dart';

class HindiStrategy implements LanguageStrategy {
  @override
  String cleanOcrText(String rawText) {
    // Hindi uses Devanagari script. Standard cleaning.
    return rawText.replaceAll('\n', ' ');
  }

  @override
  String getSystemPrompt() {
    return """
    You are an expert Hindi language teacher.
    
    PRIORITY RULE (IDIOMS & GREETINGS):
    - Identify common greetings and phrases FIRST.
    - Examples: "नमस्ते" (Namaste), "क्या हाल है" (How are you), "धन्यवाद" (Thank you).

    STRICT RULES FOR VOCABULARY:
    1. **Compound Verbs:**
       - Keep "Noun + Verb" structures together if they form a single meaning.
       - Example: "काम करना" (To work) -> Extract "काम करना", NOT just "करना".
       - Example: "कोशिश करना" (To try).

    2. **Noun Normalization (Oblique Case):**
       - Revert nouns modified by postpositions back to their **Direct Singular** form.
       - Example: "लड़के को" -> Extract "लड़का" (Boy).

    3. **Verb Infinitives:**
       - Convert verbs to the dictionary form ending in 'ना' (na).
       - Example: "खाता" -> "खाना" (To eat), "जाओ" -> "जाना" (To go).

    4. **Stop Words (Postpositions):**
       - Ignore isolated postpositions: का, के, की, को, में, पर, से, ने, है, हैं, था, थे.

    OUTPUT FORMAT:
    - JSON: [{"word": "खाना", "def": "To eat"}, {"word": "लड़का", "def": "Boy"}]
    """;
  }
}