/**
 * Test class for OpportunityScoreboardController
 */
@IsTest
private class OpportunityScoreboardControllerTest {
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Scoreboard Test Account');
        insert acc;

        Opportunity oppScored = new Opportunity(
            Name = 'Scored Opp',
            AccountId = acc.Id,
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(30),
            Amount = 100000
        );
        insert oppScored;
        OpportunityScoringService.scoreOpportunities(new List<Opportunity>{ oppScored });

        Opportunity oppClosed = new Opportunity(
            Name = 'Closed Opp',
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(-5),
            Amount = 50000
        );
        insert oppClosed;
        OpportunityScoringService.scoreOpportunities(new List<Opportunity>{ oppClosed });

        Opportunity oppNotScored = new Opportunity(
            Name = 'Not Scored Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(60),
            Amount = 15000
        );
        insert oppNotScored;
    }

    @IsTest
    static void testGetOpportunitiesReturnsCorrectRecords() {
        Test.startTest();
        List<Opportunity> result = OpportunityScoreboardController.getOpportunities();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() >= 1, 'Should return at least the scored open opportunity');
        for (Opportunity opp : result) {
            System.assertEquals(false, opp.IsClosed, 'Should only return open opportunities');
            System.assertNotEquals(null, opp.Opportunity_Score__c, 'Should only return scored opportunities');
        }
    }

    @IsTest
    static void testClosedOpportunitiesExcluded() {
        List<Opportunity> result = OpportunityScoreboardController.getOpportunities();

        for (Opportunity opp : result) {
            System.assertNotEquals('Closed Opp', opp.Name, 'Closed opportunities should be excluded');
        }
    }

    @IsTest
    static void testOrderingByScoreDescending() {
        List<Opportunity> result = OpportunityScoreboardController.getOpportunities();

        for (Integer i = 1; i < result.size(); i++) {
            Decimal prev = result[i - 1].Opportunity_Score__c;
            Decimal curr = result[i].Opportunity_Score__c;
            System.assert(prev >= curr, 'Opportunities should be ordered by score descending');
        }
    }

    @IsTest
    static void testUnscoredOpportunitiesExcluded() {
        List<Opportunity> result = OpportunityScoreboardController.getOpportunities();

        for (Opportunity opp : result) {
            System.assertNotEquals('Not Scored Opp', opp.Name, 'Unscored opportunities should be excluded');
        }
    }
}
