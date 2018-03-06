global class EmailStatusReportCip implements FieloPLT.EmailDataInterface{
    
    public Map<Id,Map<String,String>> getTransactionalData(Set<Id> emailAlertIds){
        return null;
    }

    public Map<Id,Map<String,String>> getCampaignData(Id campaignId, Set<Id> memberIds){
        Set<Id> idSet = new Set<Id>{campaignId};
        FieloPLT__EmailCampaign__c emailCampaign = ((List<FieloPLT__EmailCampaign__c>) Database.query('SELECT FieloPLT__Date__c FROM FieloPLT__EmailCampaign__c WHERE id in :idSet ORDER BY Name'))[0];

        Integer lastMonth = emailCampaign.FieloPLT__Date__c.addMonths(-1).month();
        Integer lastYear = emailCampaign.FieloPLT__Date__c.addMonths(-1).year();
        Integer year = emailCampaign.FieloPLT__Date__c.year();
        Integer month = emailCampaign.FieloPLT__Date__c.month();
        Integer nextMonth = emailCampaign.FieloPLT__Date__c.addMonths(1).month();
        Integer nextYear = emailCampaign.FieloPLT__Date__c.addMonths(1).year();
        DateTime firstDate = DateTime.newInstance(emailCampaign.FieloPLT__Date__c.year(), emailCampaign.FieloPLT__Date__c.month(), 1, 0, 0, 0);
        DateTime lastDate = firstDate.addMonths(1);
        
        Map<Id,FieloPLT__Member__c> membersMap = new Map<Id,FieloPLT__Member__c>((List<FieloPLT__Member__c >) Database.query('SELECT Name, FieloPLT__Points__c, FieloPLT__Program__c, (SELECT FieloPLT__Level__r.FieloPLT__Order__c FROM FieloPLT__LevelsMembers__r ORDER BY CreatedDate DESC LIMIT 1) FROM FieloPLT__Member__c WHERE id in :memberIds ORDER BY Name'));
              
        Map<Id,Map<String,String>> valuesByMember = new Map<Id,Map<String,String>>();
        Map<Id,Decimal> orderByMember = new Map<Id,Decimal>();
        Set<Id> programIds = new Set<Id>();
        
        for(FieloPLT__Member__c member : membersMap.values()){
            Map<String,String> values = new Map<String,String>();
            values.put('lastMonth', getMonthName(lastMonth));
            values.put('lastYear', String.valueOf(lastYear));
            values.put('month', getMonthName(month));
            values.put('year', String.valueOf(year));
            values.put('nextMonth', getMonthName(nextMonth));
            values.put('nextYear', String.valueOf(nextYear));                            
            values.put('name', member.Name);
            values.put('points', String.valueOf(member.FieloPLT__Points__c));
            values.put('pointsGenerated', '0');
            values.put('pointsRedeemed', '0');
            values.put('pointsExpired', '0');
            values.put('pointsToExpire', '0');
            values.put('currentLevel', '');
            values.put('pointsToNextLevel', '0');            
            values.put('coursesCompleted', '0'); 
            values.put('coursesToComplete', '0'); 
            values.put('uploadedInvoices', '0');            
            valuesByMember.put(member.Id, values);
            orderByMember.put(member.Id, member.FieloPLT__LevelsMembers__r[0].FieloPLT__Level__r.FieloPLT__Order__c);
            programIds.add(member.FieloPLT__Program__c);
        }
        
        //points generated
        for(AggregateResult ar : [SELECT SUM(FieloPLT__Points__c) points, FieloPLT__Member__c member FROM FieloPLT__Transaction__c WHERE FieloPLT__Member__c in : memberIds AND FieloPLT__Points__c > 0 AND CALENDAR_MONTH(FieloPLT__Date__c) =: month AND CALENDAR_YEAR(FieloPLT__Date__c) =: year GROUP BY FieloPLT__Member__c]){
            system.debug((Id)ar.get('member'));
            system.debug((Decimal)ar.get('points'));
            valuesByMember.get((Id)ar.get('member')).put('pointsGenerated', String.valueOf((Decimal)ar.get('points')));
        }

        //points redeemed
        for(AggregateResult ar : [SELECT SUM(FieloPLT__Points__c) points, FieloPLT__Member__c member FROM FieloPLT__Redemption__c WHERE FieloPLT__Member__c in : memberIds AND FieloPLT__Status__c = 'Closed' AND CALENDAR_MONTH(CreatedDate) =: month AND CALENDAR_YEAR(CreatedDate) =: year GROUP BY FieloPLT__Member__c]){
            valuesByMember.get((Id)ar.get('member')).put('pointsRedeemed', String.valueOf((Decimal)ar.get('points')));
        }

        //points expired
        for(AggregateResult ar : [SELECT SUM(FieloPLT__ExpiredPoints__c) points, FieloPLT__Member__c member FROM FieloPLT__Point__c WHERE FieloPLT__Member__c in : memberIds AND FieloPLT__ExpiredPoints__c > 0 AND CALENDAR_MONTH(FieloPLT__ExpirationDate__c) =: month AND CALENDAR_YEAR(FieloPLT__ExpirationDate__c) =: year GROUP BY FieloPLT__Member__c]){
            valuesByMember.get((Id)ar.get('member')).put('pointsExpired', String.valueOf((Decimal)ar.get('points')));
        }

        //points to expire
        for(AggregateResult ar : [SELECT SUM(FieloPLT__Balance__c) points, FieloPLT__Member__c member FROM FieloPLT__Point__c WHERE FieloPLT__Member__c in : memberIds AND FieloPLT__Balance__c > 0 AND CALENDAR_MONTH(FieloPLT__ExpirationDate__c) =: nextMonth AND CALENDAR_YEAR(FieloPLT__ExpirationDate__c) =: nextYear GROUP BY FieloPLT__Member__c]){
            valuesByMember.get((Id)ar.get('member')).put('pointsToExpire', String.valueOf((Decimal)ar.get('points')));
        }

        //current level
        for(FieloPLT__Member__c member : [SELECT FieloPLT__CurrentLevelMember__r.FieloPLT__Level__r.Name, Id FROM FieloPLT__Member__c WHERE Id in : memberIds]){
            valuesByMember.get(member.Id).put('currentLevel', member.FieloPLT__CurrentLevelMember__r.FieloPLT__Level__r.Name);
        }   
                
        //progress to next level
        Map<Decimal, Decimal> levelLimits = new Map<Decimal, Decimal>();
        Decimal lowerLimit;
        for(FieloPLT__Criterion__c criterion : [SELECT FieloPLT__Level__r.FieloPLT__Program__c, FieloPLT__Level__r.FieloPLT__Order__c, FieloPLT__NumberValue__c, FieloPLT__Operator__c FROM FieloPLT__Criterion__c WHERE FieloPLT__Level__c != null ANd FieloPLT__FieldName__c = 'FieloPLT__Points__c' AND FieloPLT__Operator__c LIKE 'greater%' AND FieloPLT__Level__r.FieloPLT__Program__c IN : programIds]){
            lowerLimit = (criterion.FieloPLT__Operator__c == 'greater than' ? criterion.FieloPLT__NumberValue__c + 1 : criterion.FieloPLT__NumberValue__c);
            levelLimits.put(criterion.FieloPLT__Level__r.FieloPLT__Order__c, lowerLimit);
        }
        Decimal pointsToNextLevel;
        for(Id memberId : orderByMember.KeySet()) {
            pointsToNextLevel = (levelLimits.get(orderByMember.get(memberId)-1) == null ? 0 : levelLimits.get(orderByMember.get(memberId)-1) - Decimal.ValueOf(valuesByMember.get(memberId).get('points')));
            valuesByMember.get(memberId).put('pointsToNextLevel', String.valueOf(pointsToNextLevel));    
        }
                
       //courses completed
        for(AggregateResult ar : [SELECT COUNT(Id) courses, FieloELR__Member__c member FROM FieloELR__ModuleResponse__c WHERE FieloELR__Member__c in : memberIds AND FieloELR__NumberofApprove__c = 1 AND FieloELR__SubmitDate__c != null AND FieloELR__CourseStatus__r.FieloELR__Course__r.FieloELR__Status__c = 'Active' AND FieloELR__CourseStatus__r.FieloELR__Progress__c = 100 GROUP BY FieloELR__Member__c HAVING MAX(FieloELR__SubmitDate__c) >=: firstDate  AND MAX(FieloELR__SubmitDate__c) <: lastDate]){
            valuesByMember.get((Id)ar.get('member')).put('coursesCompleted', String.valueOf((Decimal)ar.get('courses')));
        }

       //courses to be completed
        for(AggregateResult ar : [SELECT COUNT(Id) courses, FieloELR__Member__c member FROM FieloELR__CourseStatus__c WHERE FieloELR__Member__c in : memberIds AND FieloELR__Course__r.FieloELR__Status__c = 'Active' AND FieloELR__Progress__c < 100  GROUP BY FieloELR__Member__c]){
            valuesByMember.get((Id)ar.get('member')).put('coursesToComplete', String.valueOf((Decimal)ar.get('courses')));
        }

        //uploaded invoices
        for(AggregateResult ar : [SELECT COUNT(Id) invoices, FieloPRP__Member__c member FROM FieloPRP__Invoice__c WHERE FieloPRP__Member__c in : memberIds AND CALENDAR_MONTH(CreatedDate ) =: month AND CALENDAR_YEAR(CreatedDate ) =: year GROUP BY FieloPRP__Member__c]){
            valuesByMember.get((Id)ar.get('member')).put('uploadedInvoices', String.valueOf((Decimal)ar.get('invoices')));
        }
        System.debug('valuesByMember = ' + valuesByMember);
        return valuesByMember;
    }

    private String getMonthName(Integer month) {
        if (month == 1) {
            return 'January'; 
        } else if (month == 2) {
            return 'February'; 
        } else if (month == 3) {
            return 'March'; 
        } else if (month == 4) {
            return 'April'; 
        } else if (month == 5) {
            return 'May'; 
        } else if (month == 6) {
            return 'June'; 
        } else if (month == 7) {
            return 'July'; 
        } else if (month == 8) {
            return 'August'; 
        } else if (month == 9) {
            return 'September'; 
        } else if (month == 10) {
            return 'October'; 
        } else if (month == 11) {
            return 'November'; 
        } else if (month == 12) {
            return 'December'; 
        } else {
            return 'None';
        }
    }
    
    public List<FieloPLT__EmailCampaign__c> selectById(Set<ID> idSet){               
        return (List<FieloPLT__EmailCampaign__c>) Database.query('SELECT Date__c FROM FieloPLT__EmailCampaign__c WHERE id in :idSet ORDER BY Name');
    }
}