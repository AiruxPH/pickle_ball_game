/// Official USA Pickleball (USAP) Rule Categories.
enum RuleCategory {
  courtAndDimensions,
  serviceRules,
  twoBounceRule,
  kitchenRules,
  faults,
  scoring,
  glossary,
}

/// A specific rule entry grounded in the official USAP Rulebook.
class UsapRuleItem {
  final String id;
  final String ruleNumber;
  final String title;
  final String summary;
  final String fullExplanation;
  final String officialCitation;
  final String keyTakeaway;
  final bool isFault;
  final RuleCategory category;

  const UsapRuleItem({
    required this.id,
    required this.ruleNumber,
    required this.title,
    required this.summary,
    required this.fullExplanation,
    required this.officialCitation,
    required this.keyTakeaway,
    this.isFault = false,
    required this.category,
  });
}

/// Official pickleball terminology glossary term.
class GlossaryTerm {
  final String term;
  final String categoryTag;
  final String definition;
  final String? ruleReference;

  const GlossaryTerm({
    required this.term,
    required this.categoryTag,
    required this.definition,
    this.ruleReference,
  });
}
