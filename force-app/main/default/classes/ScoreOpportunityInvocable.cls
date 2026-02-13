/**
 * Invocable action for Record-Triggered Flows
 * Calculates predictive opportunity score based on multiple factors
 */
public with sharing class ScoreOpportunityInvocable {

    public class ScoreRequest {
        @InvocableVariable(required=true description='Opportunity Record Id')
        public Id oppId;
    }

    @InvocableMethod(label='Score Opportunity' description='Calculates predictive opportunity score')
    public static void score(List<ScoreRequest> requests) {
        List<Id> oppIds = new List<Id>();
        for (ScoreRequest req : requests) {
            oppIds.add(req.oppId);
        }

        if (oppIds.isEmpty()) return;

        List<Opportunity> opps = [
            SELECT Id, Amount, StageName, CloseDate, LastActivityDate,
                   Opportunity_Score__c, Score_Category__c
            FROM Opportunity
            WHERE Id IN :oppIds
        ];
        OpportunityScoringService.scoreOpportunities(opps);
    }
}
