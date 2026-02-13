/**
 * OpportunityScoringService - Core scoring engine for Opportunity Intelligence System
 * Calculates predictive scores (0-100) based on multiple factors and categorizes as Hot/Warm/Cold
 */
public with sharing class OpportunityScoringService {
    // Stage name to weight mapping (standard Opportunity stages)
    private static final Map<String, Integer> STAGE_WEIGHTS = new Map<String, Integer>{
        'Prospecting' => 5,
        'Qualification' => 10,
        'Needs Analysis' => 20,
        'Value Proposition' => 30,
        'Id. Decision Makers' => 40,
        'Perception Analysis' => 50,
        'Proposal/Price Quote' => 65,
        'Negotiation/Review' => 80,
        'Closed Won' => 100,
        'Closed Lost' => 0
    };

    /**
     * Calculates predictive score for a single Opportunity (0-100)
     * @param opp Opportunity record with Amount, StageName, CloseDate, LastActivityDate
     * @param hasContactRoles Whether the opportunity has associated contact roles
     * @return Decimal score clamped between 0 and 100
     */
    public static Decimal calculateScore(Opportunity opp, Boolean hasContactRoles) {
        Decimal score = 0;

        // Factor 1: Amount - Higher value deals get more points
        // >100k = +30, >50k = +20, >10k = +10, else +5
        Decimal amount = opp.Amount != null ? opp.Amount : 0;
        if (amount > 100000) {
            score += 30;
        } else if (amount > 50000) {
            score += 20;
        } else if (amount > 10000) {
            score += 10;
        } else {
            score += 5;
        }

        // Factor 2: Stage - Later stages indicate higher probability
        Integer stageWeight = STAGE_WEIGHTS.containsKey(opp.StageName) ? STAGE_WEIGHTS.get(opp.StageName) : 10;
        score += stageWeight;

        // Factor 3: Days since last activity - Recent engagement is positive
        // <7 days = +20, <30 = +10, <60 = 0, 60+ = -10
        Integer daysSinceActivity = getDaysSinceLastActivity(opp.LastActivityDate);
        if (daysSinceActivity < 7) {
            score += 20;
        } else if (daysSinceActivity < 30) {
            score += 10;
        } else if (daysSinceActivity < 60) {
            score += 0;
        } else {
            score += -10;
        }

        // Factor 4: Close date - Future close dates are positive, past is negative
        // Close date in future = +10, past = -5
        if (opp.CloseDate != null) {
            if (opp.CloseDate >= Date.today()) {
                score += 10;
            } else {
                score += -5;
            }
        }

        // Factor 5: Has contact roles - Engagement indicator
        if (hasContactRoles) {
            score += 10;
        }

        // Clamp score between 0 and 100
        return Math.max(0, Math.min(100, score));
    }

    /**
     * Overload for calculateScore without contact roles (defaults to false)
     */
    public static Decimal calculateScore(Opportunity opp) {
        return calculateScore(opp, false);
    }

    /**
     * Categorizes a score into Hot, Warm, or Cold
     * @param score Decimal score (0-100)
     * @return 'Hot' (>=70), 'Warm' (>=40), or 'Cold' (<40)
     */
    public static String categorize(Decimal score) {
        if (score == null) {
            return 'Cold';
        }
        if (score >= 70) {
            return 'Hot';
        }
        if (score >= 40) {
            return 'Warm';
        }
        return 'Cold';
    }

    /**
     * Scores a list of opportunities and updates them
     * Queries contact role counts and updates Opportunity_Score__c, Score_Category__c, Last_Scored_Date__c
     * @param opps List of Opportunities to score
     */
    public static void scoreOpportunities(List<Opportunity> opps) {
        if (opps == null || opps.isEmpty()) {
            return;
        }

        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : opps) {
            oppIds.add(opp.Id);
        }

        // Query opportunities with contact roles count
        Map<Id, Integer> oppContactRoleCount = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT OpportunityId oppId, COUNT(Id) cnt
            FROM OpportunityContactRole
            WHERE OpportunityId IN :oppIds
            GROUP BY OpportunityId
        ]) {
            oppContactRoleCount.put((Id) ar.get('oppId'), (Integer) ar.get('cnt'));
        }

        Datetime scoredNow = Datetime.now();
        for (Opportunity opp : opps) {
            Boolean hasContactRoles = oppContactRoleCount.containsKey(opp.Id) && oppContactRoleCount.get(opp.Id) > 0;
            Decimal score = calculateScore(opp, hasContactRoles);
            opp.Opportunity_Score__c = score;
            opp.Score_Category__c = categorize(score);
            opp.Last_Scored_Date__c = scoredNow;
        }

        update opps;
    }

    /**
     * Helper to get days since last activity. Returns 999 if null (treat as stale).
     */
    private static Integer getDaysSinceLastActivity(Datetime lastActivityDate) {
        if (lastActivityDate == null) {
            return 999;
        }
        return Math.abs(lastActivityDate.date().daysBetween(Date.today()));
    }
}
