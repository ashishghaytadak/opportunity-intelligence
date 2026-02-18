/**
 * Apex controller for Opportunity Intelligence Scoreboard LWC
 */
public with sharing class OpportunityScoreboardController {
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities() {
        return [
            SELECT Id, Name, Amount, StageName, CloseDate, Opportunity_Score__c,
                   Score_Category__c, LastActivityDate, Last_Scored_Date__c, IsClosed
            FROM Opportunity
            WHERE IsClosed = false
            AND Opportunity_Score__c != null
            ORDER BY Opportunity_Score__c DESC
            LIMIT 50
        ];
    }
}
