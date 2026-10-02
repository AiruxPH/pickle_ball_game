import 'package:flutter/material.dart';

import '../data/usap_rulebook_data.dart';
import '../models/usap_rule_models.dart';
import '../widgets/rulebook/court_diagram_widget.dart';
import '../widgets/rulebook/glossary_card_widget.dart';
import '../widgets/rulebook/rule_card_widget.dart';
import '../widgets/rulebook/rule_category_pill.dart';
import '../widgets/rulebook/rulebook_search_bar.dart';

/// Full-screen official USA Pickleball (USAP) Rules and Guidebook viewer.
class RulebookScreen extends StatefulWidget {
  const RulebookScreen({super.key});

  @override
  State<RulebookScreen> createState() => _RulebookScreenState();
}

class _RulebookScreenState extends State<RulebookScreen> {
  final TextEditingController _searchController = TextEditingController();
  RuleCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();

    // Filter rules
    final filteredRules = UsapRulebookData.rules.where((rule) {
      if (_selectedCategory != null &&
          _selectedCategory != RuleCategory.glossary &&
          rule.category != _selectedCategory) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesTitle = rule.title.toLowerCase().contains(query);
        final matchesNumber = rule.ruleNumber.toLowerCase().contains(query);
        final matchesSummary = rule.summary.toLowerCase().contains(query);
        final matchesTakeaway = rule.keyTakeaway.toLowerCase().contains(query);
        return matchesTitle || matchesNumber || matchesSummary || matchesTakeaway;
      }
      return true;
    }).toList();

    // Filter glossary
    final filteredGlossary = UsapRulebookData.glossary.where((term) {
      if (_selectedCategory != null &&
          _selectedCategory != RuleCategory.glossary) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesTerm = term.term.toLowerCase().contains(query);
        final matchesDef = term.definition.toLowerCase().contains(query);
        final matchesTag = term.categoryTag.toLowerCase().contains(query);
        return matchesTerm || matchesDef || matchesTag;
      }
      return true;
    }).toList();

    final isGlossaryActive = _selectedCategory == RuleCategory.glossary;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Navigation Bar
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book, color: Color(0xFF00E5FF), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'OFFICIAL USAP RULEBOOK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'USA Pickleball Regulation Standards & Gameplay Guide',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Search Bar in Top Bar
                  SizedBox(
                    width: 250,
                    child: RulebookSearchBar(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Category Pills Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    RuleCategoryPill(
                      category: RuleCategory.courtAndDimensions,
                      label: 'All Rules',
                      icon: Icons.all_inclusive,
                      isSelected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    const SizedBox(width: 8),
                    RuleCategoryPill(
                      category: RuleCategory.courtAndDimensions,
                      label: 'Court (Sec. 2)',
                      icon: Icons.crop_square,
                      isSelected: _selectedCategory == RuleCategory.courtAndDimensions,
                      onTap: () => setState(() => _selectedCategory = RuleCategory.courtAndDimensions),
                    ),
                    const SizedBox(width: 8),
                    RuleCategoryPill(
                      category: RuleCategory.serviceRules,
                      label: 'Serving (Rule 4)',
                      icon: Icons.sports_tennis,
                      isSelected: _selectedCategory == RuleCategory.serviceRules,
                      onTap: () => setState(() => _selectedCategory = RuleCategory.serviceRules),
                    ),
                    const SizedBox(width: 8),
                    RuleCategoryPill(
                      category: RuleCategory.twoBounceRule,
                      label: 'Two-Bounce (4.N)',
                      icon: Icons.looks_two,
                      isSelected: _selectedCategory == RuleCategory.twoBounceRule,
                      onTap: () => setState(() => _selectedCategory = RuleCategory.twoBounceRule),
                    ),
                    const SizedBox(width: 8),
                    RuleCategoryPill(
                      category: RuleCategory.kitchenRules,
                      label: 'Kitchen / NVZ (Rule 9)',
                      icon: Icons.warning_amber,
                      isSelected: _selectedCategory == RuleCategory.kitchenRules,
                      onTap: () => setState(() => _selectedCategory = RuleCategory.kitchenRules),
                    ),
                    const SizedBox(width: 8),
                    RuleCategoryPill(
                      category: RuleCategory.faults,
                      label: 'Faults (Rule 7)',
                      icon: Icons.report_problem,
                      isSelected: _selectedCategory == RuleCategory.faults,
                      onTap: () => setState(() => _selectedCategory = RuleCategory.faults),
                    ),
                    const SizedBox(width: 8),
                    RuleCategoryPill(
                      category: RuleCategory.scoring,
                      label: 'Scoring (Rule 12)',
                      icon: Icons.scoreboard,
                      isSelected: _selectedCategory == RuleCategory.scoring,
                      onTap: () => setState(() => _selectedCategory = RuleCategory.scoring),
                    ),
                    const SizedBox(width: 8),
                    RuleCategoryPill(
                      category: RuleCategory.glossary,
                      label: 'Glossary',
                      icon: Icons.library_books,
                      isSelected: _selectedCategory == RuleCategory.glossary,
                      onTap: () => setState(() => _selectedCategory = RuleCategory.glossary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Main Content: Court Blueprint + Scrollable Rule List
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Interactive Court Diagram (hidden if glossary or compact)
                    if (!isGlossaryActive)
                      const SizedBox(
                        width: 320,
                        child: SingleChildScrollView(
                          child: CourtDiagramWidget(height: 170),
                        ),
                      ),
                    if (!isGlossaryActive) const SizedBox(width: 14),

                    // Right Column: Rules & Glossary List
                    Expanded(
                      child: (filteredRules.isEmpty && filteredGlossary.isEmpty)
                          ? const Center(
                              child: Text(
                                'No matching rules or glossary terms found.',
                                style: TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.only(bottom: 20),
                              children: [
                                // Show rules
                                for (final rule in filteredRules)
                                  RuleCardWidget(rule: rule),

                                // Show glossary if on All Rules or Glossary category
                                if (_selectedCategory == null ||
                                    _selectedCategory == RuleCategory.glossary) ...[
                                  if (filteredGlossary.isNotEmpty &&
                                      _selectedCategory == null) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.bookmark, color: Color(0xFFF59E0B), size: 16),
                                          SizedBox(width: 6),
                                          Text(
                                            'OFFICIAL TERMINOLOGY GLOSSARY',
                                            style: TextStyle(
                                              color: Color(0xFFF59E0B),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  for (final term in filteredGlossary)
                                    GlossaryCardWidget(term: term),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
