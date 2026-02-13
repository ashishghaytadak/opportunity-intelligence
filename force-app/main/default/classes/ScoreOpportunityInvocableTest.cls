/**
 * Test class for ScoreOpportunityInvocable
 */
@IsTest
private class ScoreOpportunityInvocableTest {
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Invocable Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Invocable Test Opp',
            AccountId = acc.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(45),
            Amount = 75000
        );
        insert opp;
    }

    @IsTest
    static void testWithValidOpportunityIds() {
        Opportunity opp = [SELECT Id, Opportunity_Score__c, Score_Category__c, Last_Scored_Date__c FROM Opportunity WHERE Name = 'Invocable Test Opp' LIMIT 1];

        System.assertEquals(null, opp.Opportunity_Score__c, 'Score should be null before invocation');

        ScoreOpportunityInvocable.ScoreRequest req = new ScoreOpportunityInvocable.ScoreRequest();
        req.oppId = opp.Id;

        Test.startTest();
        ScoreOpportunityInvocable.score(new List<ScoreOpportunityInvocable.ScoreRequest>{ req });
        Test.stopTest();

        Opportunity updated = [SELECT Id, Opportunity_Score__c, Score_Category__c, Last_Scored_Date__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, updated.Opportunity_Score__c, 'Score should be calculated after invocation');
        System.assertNotEquals(null, updated.Score_Category__c, 'Category should be set');
        System.assertNotEquals(null, updated.Last_Scored_Date__c, 'Last Scored Date should be set');
    }

    @IsTest
    static void testWithEmptyList() {
        Test.startTest();
        ScoreOpportunityInvocable.score(new List<ScoreOpportunityInvocable.ScoreRequest>());
        Test.stopTest();

        System.assert(true, 'Empty list should not throw');
    }

    @IsTest
    static void testWithNull() {
        Test.startTest();
        ScoreOpportunityInvocable.score(null);
        Test.stopTest();

        System.assert(true, 'Null should not throw');
    }

    @IsTest
    static void testWithMultipleOpportunityIds() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp2 = new Opportunity(
            Name = 'Second Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(60),
            Amount = 25000
        );
        insert opp2;

        List<ScoreOpportunityInvocable.ScoreRequest> requests = new List<ScoreOpportunityInvocable.ScoreRequest>();
        for (Opportunity o : [SELECT Id FROM Opportunity]) {
            ScoreOpportunityInvocable.ScoreRequest req = new ScoreOpportunityInvocable.ScoreRequest();
            req.oppId = o.Id;
            requests.add(req);
        }

        Test.startTest();
        ScoreOpportunityInvocable.score(requests);
        Test.stopTest();

        List<Opportunity> updated = [SELECT Id, Opportunity_Score__c FROM Opportunity];
        for (Opportunity o : updated) {
            System.assertNotEquals(null, o.Opportunity_Score__c, 'All opportunities should be scored');
        }
    }
}
