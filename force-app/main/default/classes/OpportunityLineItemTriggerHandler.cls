public with sharing class OpportunityLineItemTriggerHandler extends TriggerHandler {
    
    list<OpportunityLineItem> oppLineItemNewList = new list<OpportunityLineItem>(); 
    list<OpportunityLineItem> oppLineItemOldList = new list<OpportunityLineItem>();
    map<Id, OpportunityLineItem> oppLineItemOldMap = new map<Id, OpportunityLineItem>();

    public OpportunityLineItemTriggerHandler(){
       oppLineItemNewList = (list<OpportunityLineItem>) Trigger.new;
       oppLineItemOldList = (list<OpportunityLineItem>) Trigger.old;
       oppLineItemOldMap = (map<Id, OpportunityLineItem>) Trigger.oldMap;
    }

    protected override void afterInsert(){
        updateAccountNumOfProdFieldWithTotalOppLineItems(oppLineItemNewList, oppLineItemOldMap);
        createAssetAndLinkWithAccountOnOppLineItemInsertion(oppLineItemNewList);
        countTotalOppProdWhichGr50KOnAccCustomField(oppLineItemNewList);
        sendEmailToOpportunityAccountClientContact(oppLineItemNewList);
        updateAccountDescriptionWithOppLineItemDes(oppLineItemNewList);
    }

    protected override void afterUpdate(){
        updateAccountDescriptionWithOppLineItemDes(oppLineItemNewList);
    }

    protected override void afterDelete(){
       updateAccountNumOfProdFieldWithTotalOppLineItems(oppLineItemOldList, oppLineItemOldMap);
    }

    private void updateAccountNumOfProdFieldWithTotalOppLineItems(list<OpportunityLineItem> oppLineItemList, map<Id, OpportunityLineItem> oppLineItemOldMap){ //357ms
              
        Set<Id> opportunityIds = getOpportunityIdsFromOpportunityLineItemListForInsOrDelOrUpd(oppLineItemList, null);
        boolean haveOpportunityIds = opportunityIds.size() > 0;
        if(haveOpportunityIds) {
            map<Id, Integer> accountIdProductsMap = createBaseMapOfAccountIdWithProducts(opportunityIds);           
            boolean isAccProdMapHaveData = accountIdProductsMap.size() > 0;
            if(isAccProdMapHaveData) {
                map<Id, Integer> accountIdProductsMapUpd = aggregateTotalNumOfProductsWithAccount(accountIdProductsMap);
                boolean isAccountIdPrdMapUpdated = accountIdProductsMapUpd.size() > 0;
                if(isAccountIdPrdMapUpdated){
                    updateNumberOfProductsFieldOnAccounts(accountIdProductsMapUpd);
                }
            }
        }

    }

    private void createAssetAndLinkWithAccountOnOppLineItemInsertion(list<OpportunityLineItem> oppLineItemNewList){ //257ms // 300 to 320ms after refactoring

       map<Id, list<OpportunityLineItem>> oppIdToListOfOppLineItemMap = new map<Id, list<OpportunityLineItem>>();
       map<Id, list<OpportunityLineItem>> accIdToListOfOppLineItemMap = new map<Id, list<OpportunityLineItem>>();

       oppIdToListOfOppLineItemMap = createMapOfOppIdWithListOfOppLineItems(oppLineItemNewList);

       list<Opportunity> oppList = queryRelatedOpportunities(oppIdToListOfOppLineItemMap.keySet());
       
       accIdToListOfOppLineItemMap = createAccIdWithListOfOppLineItemsMap(oppList, oppIdToListOfOppLineItemMap);

       boolean isAccMapHaveData = accIdToListOfOppLineItemMap.size() > 0;

       if(isAccMapHaveData) {
           insertAssetsForEachOppLineItem(accIdToListOfOppLineItemMap); 
       }
    
    }

    private void sendEmailToOpportunityAccountClientContact(list<OpportunityLineItem> oppLineItems){

       Set<Id> oppIds = new Set<Id>();
       map<Id, Opportunity> oppIdContactMap = new map<Id, Opportunity>();
       
       for(OpportunityLineItem oppLineItem : oppLineItems) {
          oppIds.add(oppLineItem.opportunityId);
       }

       if(oppIds.size() > 0) {
          list<Opportunity> oppList = [Select Id, Account.Client_Contact__r.Email, Account.Client_Contact__r.LastName from Opportunity where Id IN :oppIds];

          for(Opportunity opp : oppList){
             if(opp?.Account.Client_Contact__r != null && opp?.Account.Client_Contact__r.Email != null){
                oppIdContactMap.put(opp.Id, opp);
             }
          }

          if(oppIdContactMap.size() > 0){
            list<Messaging.SingleEmailMessage> emailList = new list<Messaging.SingleEmailMessage>();
            list<ContentVersion> cd = [Select Id from ContentVersion where ContentDocument.title = 'record_locking_cheatsheet' AND isLatest=true];

            for(OpportunityLineItem oppLineItem : oppLineItems){
               if(oppIdContactMap.containskey(oppLineItem.opportunityId)){
                  string lastName = oppIdContactMap.get(oppLineItem.opportunityId).Account.Client_Contact__r.lastName;
                  string emailAdr = oppIdContactMap.get(oppLineItem.opportunityId).Account.Client_Contact__r.Email;
                  Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                  email.setSenderDisplayName('Salesforce');
                  email.setSubject('Order Processing!');
                  email.toaddresses = new list<String>{emailAdr};
                  string body = 'Hi ' + lastName + ',<br/><br/>' +
                                'Your order has been proceeding.<br/>' +
                                'Your order details are as below:<br/>' +
                                'Product Name: ' + oppLineItem.Name + '<br/>' +
                                'Product Code: ' + oppLineItem.ProductCode + '<br/>' +
                                'Unit Price: ' + oppLineItem.UnitPrice + '<br/>' +
                                'List Price: ' + oppLineItem.ListPrice;
                  body += '<br/><br/>Thanks,<br/>' +
                          UserInfo.getFirstName() + ' ' + UserInfo.getLastName();
                  email.setHtmlBody(body);
                  email.setEntityAttachments(new list<string>{cd[0].Id});

                  emailList.add(email);
                }
            }
            
            if(emailList.size() > 0){
                list<Messaging.SendEmailResult> emailResult = Messaging.sendEmail(emailList);

                for(Messaging.SendEmailResult eR : emailResult){
                    if(!(eR.isSuccess())){
                        list<Messaging.SendEmailError> emailErrors = eR.getErrors();
                        System.debug(emailErrors.toString());
                    }
                }
            }
          }

       }

    }

    private Set<Id> getOpportunityIdsFromOpportunityLineItemListForInsOrDelOrUpd(list<OpportunityLineItem> oppLineItemList, string fieldName) {
        
        Set<Id> opportunityIds = new Set<Id>();
        boolean isInsertContext = Trigger.isInsert;
        boolean isDeleteContext = Trigger.isDelete;
        boolean isUpdateContext = Trigger.isUpdate;

        for(OpportunityLineItem oppLItem : oppLineItemList){
            if(isInsertContext){
                if(oppLItem.OpportunityId != null){
                    opportunityIds.add(oppLItem.opportunityId);
                }
            }
            if(isUpdateContext){
                if(oppLItem.get(fieldName) != oppLineItemOldMap.get(oppLItem.Id).get(fieldName)){
                    opportunityIds.add(oppLItem.OpportunityId);
                }
            }
            if(isDeleteContext){
                if(oppLItem.OpportunityId != null){
                    opportunityIds.add(oppLItem.OpportunityId);
                }
            }
        }

        return opportunityIds;
    }

    private map<Id, Integer> createBaseMapOfAccountIdWithProducts(Set<Id> opportunityIds){

        map<Id, Integer> accountIdProductsMap = new map<Id, Integer>();

        list<Opportunity> oppList = [Select Id, AccountId from Opportunity where Id IN :opportunityIds];

        for(Opportunity opp : oppList){
            accountIdProductsMap.put(opp.AccountId, 0);
        }

        return accountIdProductsMap;
    }

    private map<Id, Integer> aggregateTotalNumOfProductsWithAccount(map<Id, Integer> accountIdProductsMap) {
        list<AggregateResult> results = [Select Opportunity.AccountId, Count(Id) from OpportunityLineItem where Opportunity.AccountId IN :accountIdProductsMap.keySet() GROUP BY Opportunity.AccountId];

        for(AggregateResult r : results) {
            accountIdProductsMap.put((Id) r.get('AccountId'), (Integer) r.get('expr0'));
        }

        return accountIdProductsMap;
    }

    private void updateNumberOfProductsFieldOnAccounts(map<Id, Integer> accountIdProductsMap){
        
        list<Account> accToUpd = new list<Account>();

        for(Id accId : accountIdProductsMap.keySet()){
            Account acc = new Account(Id=accId);
            acc.Number_of_Products__c = accountIdProductsMap.get(acc.Id);
            accToUpd.add(acc);
        }

        if(accToUpd.size() > 0) {
            update accToUpd;
        }

    }   

    private map<Id, list<OpportunityLineItem>> createMapOfOppIdWithListOfOppLineItems(list<OpportunityLineItem> oppLineItemList) {

        map<Id, list<OpportunityLineItem>> oppIdToListOfOppLineItemMap = new map<Id, list<OpportunityLineItem>>();

        for(OpportunityLineItem oppLineItem : oppLineItemNewList){
          if(oppIdToListOfOppLineItemMap.containskey(oppLineItem.opportunityId)){
             oppIdToListOfOppLineItemMap.get(oppLineItem.opportunityId).add(oppLineItem);
          } else {
             oppIdToListOfOppLineItemMap.put(oppLineItem.opportunityId, new list<OpportunityLineItem>{oppLineItem});
          }
        }

        return oppIdToListOfOppLineItemMap;
    }

    private list<Opportunity> queryRelatedOpportunities(Set<Id> oppIds) {
        return [Select AccountId from Opportunity where Id IN :oppIds];
    }

    private map<Id, list<OpportunityLineItem>> createAccIdWithListOfOppLineItemsMap(list<Opportunity> oppList, map<Id, list<OpportunityLineItem>> oppIdToListOfOppLineItemMap) {

        map<Id, list<OpportunityLineItem>> accIdToListOfOppLineItemsMap = new map<Id, list<OpportunityLineItem>>();

        for(Opportunity opp : oppList){
          boolean isOppHaveAccount = opp.AccountId != null;
          if(isOppHaveAccount){
            list<OpportunityLineItem> oppItemList = new list<OpportunityLineItem>();

            if(oppIdToListOfOppLineItemMap.containskey(opp.Id)){
               oppItemList = oppIdToListOfOppLineItemMap.get(opp.Id);
            }   

            if(accIdToListOfOppLineItemsMap.containskey(opp.AccountId)){
               accIdToListOfOppLineItemsMap.get(opp.AccountId).addAll(oppItemList);
            } else {
              accIdToListOfOppLineItemsMap.put(opp.AccountId, oppItemList);
            }
          }
       }

       return accIdToListOfOppLineItemsMap;

    }

    private void insertAssetsForEachOppLineItem(map<Id, list<OpportunityLineItem>> accIdToListOfOppLineItemsMap) {
        list<Asset> assetsToInsert = new list<Asset>();

        for(Id accId : accIdToListOfOppLineItemsMap.keySet()){
          for(OpportunityLineItem oppLineItem : accIdToListOfOppLineItemsMap.get(accId)){
               Asset a = new Asset();
               a.Price = oppLineItem.TotalPrice;
               a.Product2Id = opplineItem.Product2Id;
               a.Name = oppLineItem.Name;
               a.Quantity = oppLineItem.Quantity;
               a.Status = 'Purchased';
               a.AccountId = accId;
               assetsToInsert.add(a);
          }
       }

       if(assetsToInsert.size() > 0){
          insert assetsToInsert;
       }
    }
} 
