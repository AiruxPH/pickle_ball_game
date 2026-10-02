import '../models/usap_rule_models.dart';

/// Comprehensive repository of official USA Pickleball (USAP) rules, citations,
/// and gameplay mechanics.
class UsapRulebookData {
  static const List<UsapRuleItem> rules = [
    // --- SECTION 2: COURT & DIMENSIONS ---
    UsapRuleItem(
      id: 'court_size',
      ruleNumber: 'Rule 2.A',
      title: 'Court Dimensions',
      summary: 'Standard rectangular court measuring 20 feet wide by 44 feet long.',
      fullExplanation:
          'The pickleball court is a rectangle 20 feet (6.10 m) wide and 44 feet (13.41 m) long '
          'for both singles and doubles play. The court is divided into two equal 22-foot halves by the net.',
      officialCitation: 'USAP Section 2.A - Court Specifications',
      keyTakeaway: 'Total court footprint is 20 x 44 ft. Same court is used for singles and doubles.',
      category: RuleCategory.courtAndDimensions,
    ),
    UsapRuleItem(
      id: 'net_height',
      ruleNumber: 'Rule 2.C',
      title: 'Net Height & Center Strap',
      summary: '36 inches at the sidelines, suspended to 34 inches at the center.',
      fullExplanation:
          'The net shall be 36 inches (0.91 m) high at the sidelines and 34 inches (0.86 m) high '
          'at the center of the court. A center strap holds the net firmly at the regulation 34-inch height.',
      officialCitation: 'USAP Section 2.C.2 - Net Specifications',
      keyTakeaway: 'Aiming toward the center provides 2 extra inches of net clearance.',
      category: RuleCategory.courtAndDimensions,
    ),
    UsapRuleItem(
      id: 'court_lines',
      ruleNumber: 'Rule 2.B',
      title: 'Court Lines & Boundaries',
      summary: 'All lines are 2 inches wide and are considered IN bounds, except the NVZ line on serves.',
      fullExplanation:
          'All court lines must be 2 inches (5.1 cm) wide. The baseline, sidelines, and centerline '
          'are inside the court boundaries. If a ball touches any part of the perimeter line, it is IN.',
      officialCitation: 'USAP Section 2.B - Court Lines',
      keyTakeaway: 'Line contact is IN during rallies. However, the NVZ line is OUT on a serve.',
      category: RuleCategory.courtAndDimensions,
    ),

    // --- SECTION 4: SERVICE RULES ---
    UsapRuleItem(
      id: 'serve_motion',
      ruleNumber: 'Rule 4.A',
      title: 'Service Execution & Motion',
      summary: 'The serve must be hit underhand with an upward swinging arc.',
      fullExplanation:
          'During a volley serve: 1) The arm must move in an upward arc. 2) The paddle head must be below '
          'the highest part of the wrist at contact. 3) Contact with the ball must not be made above the waist.',
      officialCitation: 'USAP Rule 4.A.4 - Volley Serve Mechanics',
      keyTakeaway: 'Keep paddle contact below the navel with an upward paddle motion.',
      category: RuleCategory.serviceRules,
    ),
    UsapRuleItem(
      id: 'crosscourt_serve',
      ruleNumber: 'Rule 4.A.4',
      title: 'Diagonal Crosscourt Requirement',
      summary: 'The serve must clear the NVZ and land in the diagonal opponent service box.',
      fullExplanation:
          'The serve must travel diagonally across the net and land within the diagonal service court. '
          'It must clear the 7-foot non-volley zone on the receiver side without touching the NVZ line.',
      officialCitation: 'USAP Rule 4.A.5 & 4.B - Service Court Selection',
      keyTakeaway: 'Serves landing in the kitchen or on the kitchen line are immediate faults.',
      isFault: true,
      category: RuleCategory.serviceRules,
    ),
    UsapRuleItem(
      id: 'singles_server_position',
      ruleNumber: 'Rule 4.B',
      title: 'Singles Service Position by Score',
      summary: 'Serve from the Right when your score is Even; from the Left when Odd.',
      fullExplanation:
          'In singles play: If the server score is 0, 2, 4, 6, 8, etc. (Even), the server serves from the Right '
          'service court into the receiver right service court. If the score is 1, 3, 5, etc. (Odd), the serve '
          'originates from the Left service court.',
      officialCitation: 'USAP Rule 4.B.5 - Singles Service Court',
      keyTakeaway: 'Even score = Right side. Odd score = Left side.',
      category: RuleCategory.serviceRules,
    ),
    UsapRuleItem(
      id: 'serve_foot_fault',
      ruleNumber: 'Rule 4.A.7',
      title: 'Service Foot Faults',
      summary: 'Feet must be behind baseline and within imaginary sideline extensions.',
      fullExplanation:
          'At the moment of ball contact, neither foot may touch the baseline or the court inside. At least '
          'one foot must be on the ground behind the baseline, within the extensions of centerline and sideline.',
      officialCitation: 'USAP Rule 4.A.7 - Service Foot Faults',
      keyTakeaway: 'Never step on or over the baseline before striking the serve.',
      isFault: true,
      category: RuleCategory.serviceRules,
    ),

    // --- SECTION 4.N: TWO-BOUNCE RULE ---
    UsapRuleItem(
      id: 'two_bounce_rule',
      ruleNumber: 'Rule 4.N',
      title: 'The Two-Bounce (Double-Bounce) Rule',
      summary: 'Both the serve and the return of serve MUST bounce before being struck.',
      fullExplanation:
          'After the ball is served, the receiving team must let the ball bounce before hitting it. '
          'Similarly, the serving team must let the returned ball bounce before hitting it. Once each team '
          'has played their first shot off the bounce (total of two bounces), either team may volley or play off the bounce.',
      officialCitation: 'USAP Rule 4.N - Two-Bounce Rule',
      keyTakeaway: 'No volleys on Shot 1 (return) or Shot 2 (third shot). Volleys unlock on Shot 3 onwards.',
      category: RuleCategory.twoBounceRule,
    ),
    UsapRuleItem(
      id: 'two_bounce_violation',
      ruleNumber: 'Rule 7.C',
      title: 'Two-Bounce Fault Penalty',
      summary: 'Volleying the return of serve or the third shot results in an immediate fault.',
      fullExplanation:
          'If either player hits the ball out of the air (volley) before the required bounce on their side '
          'during the first two shots of the rally, a fault is immediately committed and the rally ends.',
      officialCitation: 'USAP Rule 7.C - Two-Bounce Faults',
      keyTakeaway: 'Wait for the ball to bounce on the first return and third shot!',
      isFault: true,
      category: RuleCategory.twoBounceRule,
    ),

    // --- SECTION 9: NON-VOLLEY ZONE (KITCHEN) ---
    UsapRuleItem(
      id: 'kitchen_nvz_definition',
      ruleNumber: 'Rule 9.A',
      title: 'Non-Volley Zone (NVZ) Specifications',
      summary: 'The 7-foot area on both sides of the net where air volleys are strictly forbidden.',
      fullExplanation:
          'The Non-Volley Zone extends 7 feet (2.13 m) from the net on both sides, stretching from sideline '
          'to sideline. All lines bounding the NVZ (the kitchen line and side edges) are legally part of the NVZ.',
      officialCitation: 'USAP Section 9.A - Non-Volley Zone Regulations',
      keyTakeaway: 'The NVZ line itself is part of the kitchen. Touching it is touching the kitchen.',
      category: RuleCategory.kitchenRules,
    ),
    UsapRuleItem(
      id: 'kitchen_volley_fault',
      ruleNumber: 'Rule 9.B',
      title: 'Kitchen Volley Fault',
      summary: 'Striking a ball out of the air while touching the NVZ or its line is a fault.',
      fullExplanation:
          'A player may not volley a ball while standing in or touching the NVZ or any of its boundary lines. '
          'It is a fault if any part of the player, paddle, clothing, or gear touches the NVZ during the hit.',
      officialCitation: 'USAP Rule 9.B - NVZ Volley Faults',
      keyTakeaway: 'Step back behind the line before hitting an airborne volley.',
      isFault: true,
      category: RuleCategory.kitchenRules,
    ),
    UsapRuleItem(
      id: 'kitchen_momentum_rule',
      ruleNumber: 'Rule 9.C & 9.D',
      title: 'Momentum Carryover Rule',
      summary: 'If momentum carries you into the kitchen after a volley, it is a fault even if the point was won.',
      fullExplanation:
          'If a player executes a legal volley outside the NVZ, but their swing momentum causes them (or their paddle/cap) '
          'to step onto or into the NVZ afterwards, it is a fault—even if the ball bounced twice on the opponent side first!',
      officialCitation: 'USAP Rule 9.D - Subsequent Momentum Faults',
      keyTakeaway: 'Establish full balance outside the kitchen before and after hitting volleys.',
      isFault: true,
      category: RuleCategory.kitchenRules,
    ),
    UsapRuleItem(
      id: 'kitchen_bounce_legal',
      ruleNumber: 'Rule 9.G',
      title: 'Legal Entry on Bounced Balls',
      summary: 'You may enter the kitchen at any time to hit a ball that has already bounced.',
      fullExplanation:
          'Players are completely permitted to stand in the Non-Volley Zone at any time, provided they do NOT '
          'hit the ball in the air. When an opponent dinks or drops a ball that bounces inside the kitchen, you can '
          'freely step in and return it.',
      officialCitation: 'USAP Rule 9.G - Legal Entry on Bounced Balls',
      keyTakeaway: 'If the ball bounces inside the kitchen first, you may step in and hit it cleanly.',
      category: RuleCategory.kitchenRules,
    ),

    // --- SECTION 7: FAULTS ---
    UsapRuleItem(
      id: 'out_of_bounds',
      ruleNumber: 'Rule 7.B',
      title: 'Out of Bounds Ball',
      summary: 'A ball landing completely outside the perimeter lines is out.',
      fullExplanation:
          'If a ball lands outside the sideline, baseline, or net post, it is out of bounds. If any part of the '
          'ball touches any boundary line, the ball is deemed IN.',
      officialCitation: 'USAP Rule 7.B & Section 6 - Line Calls',
      keyTakeaway: 'Line contact counts as IN during regular rally play.',
      isFault: true,
      category: RuleCategory.faults,
    ),
    UsapRuleItem(
      id: 'double_bounce',
      ruleNumber: 'Rule 7.D',
      title: 'Double Bounce Fault',
      summary: 'Allowing the ball to bounce more than once on your side is a fault.',
      fullExplanation:
          'The ball must be returned before it bounces a second time on the player court surface.',
      officialCitation: 'USAP Rule 7.D - Double Bounce',
      keyTakeaway: 'Always strike the ball on or before its first bounce.',
      isFault: true,
      category: RuleCategory.faults,
    ),
    UsapRuleItem(
      id: 'net_touch_fault',
      ruleNumber: 'Rule 7.F',
      title: 'Touching the Net or Post',
      summary: 'Touching the net, posts, or center strap while the ball is live is a fault.',
      fullExplanation:
          'A player, their paddle, or anything they wear or carry must not touch the net system, posts, ropes, '
          'or crossbars while the ball is in play.',
      officialCitation: 'USAP Rule 7.F & 11.L - Net Contact',
      keyTakeaway: 'Keep your paddle and body completely off the net during active rallies.',
      isFault: true,
      category: RuleCategory.faults,
    ),

    // --- SECTION 12: SCORING ---
    UsapRuleItem(
      id: 'side_out_scoring',
      ruleNumber: 'Rule 12.A',
      title: 'Side-Out Scoring System',
      summary: 'Points can ONLY be scored by the serving player or team.',
      fullExplanation:
          'In traditional pickleball, points are scored exclusively when serving. If the receiver wins the rally, '
          'no point is awarded; instead, a "Side-Out" occurs, and service passes to the other player.',
      officialCitation: 'USAP Section 12.A - Scoring Fundamentals',
      keyTakeaway: 'Winning a rally as the receiver grants you the serve (Side-Out), not a point.',
      category: RuleCategory.scoring,
    ),
    UsapRuleItem(
      id: 'win_by_two',
      ruleNumber: 'Rule 12.B',
      title: 'Game to 11, Win by Two',
      summary: 'Standard match is played to 11 points, requiring a 2-point margin of victory.',
      fullExplanation:
          'The first player to reach at least 11 points with a lead of 2 or more points wins the match. '
          'If the score reaches 10-10, play continues until one player achieves a 2-point lead (e.g. 12-10, 13-11).',
      officialCitation: 'USAP Section 12.B - Game and Match Formats',
      keyTakeaway: 'At 10-10, you must win two consecutive points to claim victory.',
      category: RuleCategory.scoring,
    ),
  ];

  static const List<GlossaryTerm> glossary = [
    GlossaryTerm(
      term: 'Dink',
      categoryTag: 'Shot Type',
      definition:
          'A soft, controlled shot hit out of the kitchen that arcs gently over the net and lands in the opponent non-volley zone.',
      ruleReference: 'USAP Section 3.A.8',
    ),
    GlossaryTerm(
      term: 'Kitchen (NVZ)',
      categoryTag: 'Court Area',
      definition:
          'Colloquial term for the 7-foot Non-Volley Zone adjacent to the net on both sides where air volleys are forbidden.',
      ruleReference: 'USAP Section 2.B.3',
    ),
    GlossaryTerm(
      term: 'Erne',
      categoryTag: 'Advanced Technique',
      definition:
          'An aggressive shot where a player leaps from outside the sideline over the kitchen corner to smash a ball out of the air without touching the NVZ.',
      ruleReference: 'USAP Rule 9.B Exception',
    ),
    GlossaryTerm(
      term: 'ATP (Around the Post)',
      categoryTag: 'Advanced Technique',
      definition:
          'A legal shot hit outside the net post below net height that lands in the opponent court without passing directly over the net crossbar.',
      ruleReference: 'USAP Rule 11.M',
    ),
    GlossaryTerm(
      term: 'Third Shot Drop',
      categoryTag: 'Strategy',
      definition:
          'A delicate unattackable shot hit from the baseline on the third shot of a rally that softly drops into the opponent kitchen, allowing players to transition forward.',
      ruleReference: 'USAP Rule 4.N Strategy',
    ),
    GlossaryTerm(
      term: 'Side-Out',
      categoryTag: 'Scoring',
      definition:
          'When the serving player or team loses the rally, causing service to transfer to the opponent.',
      ruleReference: 'USAP Rule 12.A',
    ),
    GlossaryTerm(
      term: 'Two-Bounce Rule',
      categoryTag: 'Core Rule',
      definition:
          'The requirement that the ball must bounce once on the receiver side and once on the server side before either team can volley.',
      ruleReference: 'USAP Rule 4.N',
    ),
    GlossaryTerm(
      term: 'Bert',
      categoryTag: 'Advanced Technique',
      definition:
          'An Erne executed across your partner court to strike the ball on their sideline.',
      ruleReference: 'USAP Rule 9.B',
    ),
  ];
}
