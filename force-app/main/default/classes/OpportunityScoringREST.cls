/**
 * REST API for Opportunity Intelligence System
 * URL: /services/apexrest/opportunity-score/*
 */
@RestResource(urlMapping='/opportunity-score/*')
global with sharing class OpportunityScoringREST {
    /**
     * GET - Retrieve score details for a single opportunity by Id from URL path
     * URL: /services/apexrest/opportunity-score/{opportunityId}
     */
    @HttpGet
    global static void getOpportunityScore() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String path = req.requestURI != null ? req.requestURI : '';
            String oppId = path.substringAfterLast('/');

            if (String.isBlank(oppId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'error' => 'Opportunity Id is required',
                    'success' => false
                }));
                return;
            }

            List<Opportunity> opps = [
                SELECT Id, Name, Amount, StageName, CloseDate, LastActivityDate,
                       Opportunity_Score__c, Score_Category__c
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];

            if (opps.isEmpty()) {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'error' => 'Opportunity not found: ' + oppId,
                    'success' => false
                }));
                return;
            }

            Opportunity opp = opps[0];
            Integer daysSinceLastActivity = null;
            if (opp.LastActivityDate != null) {
                daysSinceLastActivity = opp.LastActivityDate.daysBetween(Date.today());
            }
            Map<String, Object> result = new Map<String, Object>{
                'opportunityId' => opp.Id,
                'name' => opp.Name,
                'score' => opp.Opportunity_Score__c,
                'category' => opp.Score_Category__c,
                'stageName' => opp.StageName,
                'amount' => opp.Amount,
                'closeDate' => opp.CloseDate != null ? opp.CloseDate.format() : null,
                'daysSinceLastActivity' => daysSinceLastActivity
            };

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(result));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'error' => e.getMessage(),
                'success' => false
            }));
        }
    }

    /**
     * POST - Score ALL open opportunities (IsClosed = false)
     */
    @HttpPost
    global static void scoreAllOpenOpportunities() {
        RestResponse res = RestContext.response;

        try {
            List<Opportunity> openOpps = [
                SELECT Id, Name, Amount, StageName, CloseDate, LastActivityDate,
                       Opportunity_Score__c, Score_Category__c, Last_Scored_Date__c
                FROM Opportunity
                WHERE IsClosed = false
            ];

            OpportunityScoringService.scoreOpportunities(openOpps);

            Map<String, Object> result = new Map<String, Object>{
                'scored' => openOpps.size(),
                'status' => 'success',
                'timestamp' => Datetime.now().format()
            };

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(result));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'error' => e.getMessage(),
                'success' => false
            }));
        }
    }

    /**
     * PATCH - Score specific opportunities by IDs from JSON body
     * Body: { "opportunityIds": ["006xxx", "006yyy"] }
     */
    @HttpPatch
    global static void scoreOpportunitiesById() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            if (req.requestBody == null || req.requestBody.size() == 0) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'error' => 'Request body with opportunityIds array is required',
                    'success' => false
                }));
                return;
            }

            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            List<Object> idList = (List<Object>) body.get('opportunityIds');

            if (idList == null || idList.isEmpty()) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'error' => 'opportunityIds array cannot be empty',
                    'success' => false
                }));
                return;
            }

            Set<Id> oppIds = new Set<Id>();
            for (Object o : idList) {
                oppIds.add((Id) String.valueOf(o));
            }

            List<Opportunity> opps = [
                SELECT Id, Name, Amount, StageName, CloseDate, LastActivityDate,
                       Opportunity_Score__c, Score_Category__c, Last_Scored_Date__c
                FROM Opportunity
                WHERE Id IN :oppIds
            ];

            OpportunityScoringService.scoreOpportunities(opps);

            List<Map<String, Object>> scoredDetails = new List<Map<String, Object>>();
            for (Opportunity opp : opps) {
                scoredDetails.add(new Map<String, Object>{
                    'opportunityId' => opp.Id,
                    'name' => opp.Name,
                    'score' => opp.Opportunity_Score__c,
                    'category' => opp.Score_Category__c,
                    'stageName' => opp.StageName
                });
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(scoredDetails));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'error' => e.getMessage(),
                'success' => false
            }));
        }
    }
}
