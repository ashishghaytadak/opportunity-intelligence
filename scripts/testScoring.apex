// Simple test script - scores opportunities without querying custom fields
// Check results in Setup > Opportunities > Fields or via SOQL in Developer Console

List<Opportunity> opps = [
    SELECT Id, Name, Amount, StageName, CloseDate, LastActivityDate
    FROM Opportunity
    WHERE IsClosed = false
    LIMIT 1
];

if (opps.isEmpty()) {
    List<Account> accs = [SELECT Id FROM Account LIMIT 1];
    if (accs.isEmpty()) {
        Account a = new Account(Name = 'Test Account for Scoring');
        insert a;
        accs.add(a);
    }
    Opportunity opp = new Opportunity(
        Name = 'Test Opportunity',
        AccountId = accs[0].Id,
        Amount = 75000,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30)
    );
    insert opp;
    opps.add(opp);
}

System.debug('Scoring opportunity: ' + opps[0].Name + ' (ID: ' + opps[0].Id + ')');

// Run the scoring service
OpportunityScoringService.scoreOpportunities(opps);

System.debug('Scoring completed! Check the Opportunity record in Setup or run:');
System.debug('SELECT Id, Name, Opportunity_Score__c, Score_Category__c, Last_Scored_Date__c FROM Opportunity WHERE Id = \'' + opps[0].Id + '\'');
