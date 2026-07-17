import '../models/skill.dart';

class SkillMatcher {
  static Skill? match(String userMessage, List<Skill> skills,
      {Skill? manualSelection}) {
    if (manualSelection != null && manualSelection.enabled) {
      return manualSelection;
    }

    final enabledSkills = skills.where((s) => s.enabled).toList();
    if (enabledSkills.isEmpty) return null;

    final lowerMessage = userMessage.toLowerCase();

    Skill? bestMatch;
    int bestScore = 0;

    for (final skill in enabledSkills) {
      int score = 0;
      for (final keyword in skill.triggerKeywords) {
        if (keyword.isEmpty) continue;
        final lowerKeyword = keyword.toLowerCase();
        if (lowerMessage.contains(lowerKeyword)) {
          score += lowerKeyword.length;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = skill;
      }
    }

    return bestScore > 0 ? bestMatch : null;
  }

  static Set<String> effectiveTools(
    Set<String> globalEnabled,
    Skill? skill,
  ) {
    if (skill == null || skill.toolAllowlist.isEmpty) {
      return globalEnabled;
    }
    return globalEnabled.intersection(skill.toolAllowlist.toSet());
  }
}
