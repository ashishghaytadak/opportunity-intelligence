/**
 * Test class for OpportunityScoringREST
 */
@IsTest
private class OpportunityScoringRESTTest {
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'REST Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'REST Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount = 50000
        );
        insert opp;

        OpportunityScoringService.scoreOpportunities(new List<Opportunity>{ opp });
    }

    @IsTest
    static void testHttpGetWithValidOpportunityId() {
        Opportunity opp = [SELECT Id, Name, Amount, StageName, CloseDate, Opportunity_Score__c, Score_Category__c FROM Opportunity WHERE Name = 'REST Test Opp' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/opportunity-score/' + opp.Id;
        req.httpMethod = 'GET';
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OpportunityScoringREST.getOpportunityScore();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(opp.Id, body.get('opportunityId'));
        System.assertEquals(opp.Name, body.get('name'));
        System.assertNotEquals(null, body.get('score'));
        System.assertNotEquals(null, body.get('category'));
    }

    @IsTest
    static void testHttpGetWithInvalidId() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/opportunity-score/006000000000000AAA';
        req.httpMethod = 'GET';
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OpportunityScoringREST.getOpportunityScore();
        Test.stopTest();

        System.assertEquals(404, res.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(false, body.get('success'));
    }

    @IsTest
    static void testHttpPostScoresAllOpenOpportunities() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/opportunity-score/';
        req.httpMethod = 'POST';
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OpportunityScoringREST.scoreAllOpenOpportunities();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', body.get('status'));
        System.assertNotEquals(null, body.get('scored'));
        System.assertNotEquals(null, body.get('timestamp'));
    }

    @IsTest
    static void testHttpPatchWithSpecificOpportunityIds() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'REST Test Opp' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/opportunity-score/';
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{ 'opportunityIds' => new List<String>{ opp.Id } }));
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OpportunityScoringREST.scoreOpportunitiesById();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        List<Object> scoredDetails = (List<Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assert(!scoredDetails.isEmpty(), 'Should return scored opportunity details');
    }

    @IsTest
    static void testHttpPatchWithEmptyBody() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/opportunity-score/';
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf('{}');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OpportunityScoringREST.scoreOpportunitiesById();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}
