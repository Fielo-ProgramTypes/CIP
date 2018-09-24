trigger Members on FieloPLT__Member__c (before update, after update){

    if(Trigger.isBefore){
        for(FieloPLT__Member__c m : Trigger.new){
            if (Trigger.oldMap.get(m.Id).FieloPLT__Agreement__c != m.FieloPLT__Agreement__c) {
              if (Trigger.oldMap.get(m.Id).FieloPLT__Agreement__c == null && m.FieloPLT__Agreement__c != null) {
                m.Date_of_First_Access__c = Date.today();
              }
            }
        }
    }else{
        List<FieloPLT__Event__c> registrationEvents = new List<FieloPLT__Event__c>();
    
        for(FieloPLT__Member__c m : Trigger.new){
            if (Trigger.oldMap.get(m.Id).FieloPLT__Agreement__c != m.FieloPLT__Agreement__c) {
              if (Trigger.oldMap.get(m.Id).FieloPLT__Agreement__c == null && m.FieloPLT__Agreement__c != null) {
                registrationEvents.add( new FieloPLT__Event__c(FieloPLT__Member__c = m.Id, FieloPLT__Type__c = 'Registration') );
              }
            }
        }
    
        insert registrationEvents;
    }
}