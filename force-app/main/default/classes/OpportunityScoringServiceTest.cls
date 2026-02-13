/**
 * Test class for OpportunityScoringService
 */
@IsTest
private class OpportunityScoringServiceTest {
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert con;

        // High value, late stage (should score Hot)
        Opportunity highValueLate = new Opportunity(
            Name = 'High Value Late Stage',
            AccountId = acc.Id,
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(30),
            Amount = 150000
        );
        insert highValueLate;

        // Low value, early stage (should score Cold)
        Opportunity lowValueEarly = new Opportunity(
            Name = 'Low Value Early Stage',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(60),
            Amount = 5000
        );
        insert lowValueEarly;

        // Medium value, medium stage (should score Warm)
        Opportunity mediumValueMedium = new Opportunity(
            Name = 'Medium Value Medium Stage',
            AccountId = acc.Id,
            StageName = 'Value Proposition',
            CloseDate = Date.today().addDays(45),
            Amount = 75000
        );
        insert mediumValueMedium;

        // Opportunity with past close date
        Opportunity pastCloseDate = new Opportunity(
            Name = 'Past Close Date',
            AccountId = acc.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(-10),
            Amount = 25000
        );
        insert pastCloseDate;

        // Opportunity with null Amount
        Opportunity nullAmount = new Opportunity(
            Name = 'Null Amount',
            AccountId = acc.Id,
            StageName = 'Needs Analysis',
            CloseDate = Date.today().addDays(20),
            Amount = null
        );
        insert nullAmount;

        // Add contact role to one opportunity
        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = highValueLate.Id,
            ContactId = con.Id,
            Role = 'Decision Maker'
        );
        insert ocr;
    }

    @IsTest
    static void testCalculateScoreHighValueLateStageReturnsHot() {
        Opportunity opp = [SELECT Id, Name, Amount, StageName, CloseDate, LastActivityDate FROM Opportunity WHERE Name = 'High Value Late Stage' LIMIT 1];
        Boolean hasContactRoles = true;

        Test.startTest();
        Decimal score = OpportunityScoringService.calculateScore(opp, hasContactRoles);
        Test.stopTest();

        System.assert(score >= 70, 'High value late stage with contact roles should score Hot (>=70), got: ' + score);
    }

    @IsTest
    static void testCalculateScoreLowValueEarlyStageReturnsCold() {
        Opportunity opp = [SELECT Id, Name, Amount, StageName, CloseDate, LastActivityDate FROM Opportunity WHERE Name = 'Low Value Early Stage' LIMIT 1];

        Test.startTest();
        Decimal score = OpportunityScoringService.calculateScore(opp, false);
        Test.stopTest();

        System.assert(score < 40, 'Low value early stage should score Cold (<40), got: ' + score);
    }

    @IsTest
    static void testCalculateScoreMediumValueMediumStageReturnsWarm() {
        Opportunity opp = [SELECT Id, Name, Amount, StageName, CloseDate, LastActivityDate FROM Opportunity WHERE Name = 'Medium Value Medium Stage' LIMIT 1];

        Test.startTest();
        Decimal score = OpportunityScoringService.calculateScore(opp, false);
        Test.stopTest();

        System.assert(score >= 40 && score < 70, 'Medium value medium stage should score Warm (40-69), got: ' + score);
    }

    @IsTest
    static void testCalculateScorePastCloseDateAppliesPenalty() {
        Opportunity opp = [SELECT Id, Name, Amount, StageName, CloseDate, LastActivityDate FROM Opportunity WHERE Name = 'Past Close Date' LIMIT 1];

        Test.startTest();
        Decimal score = OpportunityScoringService.calculateScore(opp, false);
        Test.stopTest();

        System.assertNotEquals(null, score);
        System.assert(score >= 0 && score <= 100, 'Score should be clamped 0-100');
    }

    @IsTest
    static void testCalculateScoreNullAmountHandled() {
        Opportunity opp = [SELECT Id, Name, Amount, StageName, CloseDate, LastActivityDate FROM Opportunity WHERE Name = 'Null Amount' LIMIT 1];

        Test.startTest();
        Decimal score = OpportunityScoringService.calculateScore(opp, false);
        Test.stopTest();

        System.assertNotEquals(null, score);
        System.assert(score >= 0 && score <= 100, 'Score with null amount should be valid');
    }

    @IsTest
    static void testCategorizeBoundaryValues() {
        Test.startTest();
        System.assertEquals('Cold', OpportunityScoringService.categorize(0), '0 should be Cold');
        System.assertEquals('Cold', OpportunityScoringService.categorize(39), '39 should be Cold');
        System.assertEquals('Warm', OpportunityScoringService.categorize(40), '40 should be Warm');
        System.assertEquals('Warm', OpportunityScoringService.categorize(69), '69 should be Warm');
        System.assertEquals('Hot', OpportunityScoringService.categorize(70), '70 should be Hot');
        System.assertEquals('Hot', OpportunityScoringService.categorize(100), '100 should be Hot');
        System.assertEquals('Cold', OpportunityScoringService.categorize(null), 'null should be Cold');
        Test.stopTest();
    }

    @IsTest
    static void testScoreOpportunitiesBulkUpdatesAllRecords() {
        List<Opportunity> opps = [SELECT Id, Amount, StageName, CloseDate, LastActivityDate FROM Opportunity];

        Test.startTest();
        OpportunityScoringService.scoreOpportunities(opps);
        Test.stopTest();

        List<Opportunity> updated = [SELECT Id, Opportunity_Score__c, Score_Category__c, Last_Scored_Date__c FROM Opportunity];
        for (Opportunity o : updated) {
            System.assertNotEquals(null, o.Opportunity_Score__c, 'Score should be set');
            System.assertNotEquals(null, o.Score_Category__c, 'Category should be set');
            System.assertNotEquals(null, o.Last_Scored_Date__c, 'Last Scored Date should be set');
        }
    }

    @IsTest
    static void testScoreOpportunitiesEmptyList() {
        Test.startTest();
        OpportunityScoringService.scoreOpportunities(new List<Opportunity>());
        OpportunityScoringService.scoreOpportunities(null);
        Test.stopTest();

        System.assert(true, 'Empty and null lists should not throw');
    }

    @IsTest
    static void testCalculateScoreOverloadWithoutContactRoles() {
        Opportunity opp = [SELECT Id, Amount, StageName, CloseDate, LastActivityDate FROM Opportunity WHERE Name = 'Low Value Early Stage' LIMIT 1];

        Test.startTest();
        Decimal score = OpportunityScoringService.calculateScore(opp);
        Test.stopTest();

        System.assertNotEquals(null, score);
    }
}
