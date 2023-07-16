public with sharing class AccountTriggerHandler extends TriggerHandler {
  list<Account> accListNew;
  Map<Id, Account> accOldMap;
  list<Account> accListOld;

  public AccountTriggerHandler() {
    accListNew = (list<Account>) Trigger.New;a
    accOldMap = (map<Id, Account>) Trigger.oldMap;
    accListOld = (list<Account>) Trigger.Old;
  }

  protected override void beforeInsert() {
    preventDuplicationOfAccountBasedOnName(accListNew, accOldMap);
  }

  protected override void beforeUpdate() {
    preventDuplicationOfAccountBasedOnName(accListNew, accOldMap);
  }

  protected override void afterInsert() {
    createRelContactOnAccCustomChkboxChecked(accListNew, null);
    closeAllOppWhenAccountCheckboxTicked(accListNew);
    createContactAndUpdateClientContactOnAccount(accListNew);
  }

  protected override void afterUpdate() {
    createRelContactOnAccCustomChkboxChecked(accListNew, accOldMap);
    updGr30DayOppsToCloseLostOnAccUpd(accListNew, accOldMap);
    sendEmailToRelatedContactOfAccWhenTypeUpd(accListNew);
    closeAllOppWhenAccountCheckboxTicked(accListNew);
    updateRelatedContactPhoneFieldWithAccountPhone(accListNew, accOldMap);
    deleteRelOppsAndCheckDoNotContactOnConWhenAccInactive(
      accListNew,
      accOldMap
    );
  }

  private void updGr30DayOppsToCloseLostOnAccUpd(
    List<Account> accList,
    Map<Id, Account> accMapOld
  ) {
    Set<Id> accIds = new Set<Id>();
    List<Opportunity> oppListToUpd = new List<Opportunity>();

    for (Account acc : accList) {
      accIds.add(acc.Id);
    }

    List<Opportunity> oppList = [
      SELECT StageName, CloseDate
      FROM Opportunity
      WHERE
        AccountId IN :accIds
        AND StageName != 'Closed Won'
        AND CreatedDate < LAST_N_DAYS:30
    ];

    for (Opportunity opp : oppList) {
      opp.StageName = 'Closed Lost';
      opp.CloseDate = Date.today();
      oppListToUpd.add(opp);
    }

    if (oppListToUpd.size() > 0) {
      update oppListToUpd;
    }
  }

  private void createRelContactOnAccCustomChkboxChecked(
    List<Account> accListNew,
    Map<Id, Account> accMapOld
  ) {
    List<Contact> conListToUpd = new List<Contact>();
    List<Account> filAccounts = new List<Account>();

    for (Account acc : accListNew) {
      if (Trigger.isInsert) {
        if (acc.Create_Related_Contact__c == true) {
          filAccounts.add(acc);
        }
      } else if (Trigger.isUpdate) {
        if (
          acc.Create_Related_Contact__c == true &&
          acc.Create_Related_Contact__c !=
          accOldMap.get(acc.Id).Create_Related_Contact__c
        ) {
          filAccounts.add(acc);
        }
      }
    }

    for (Account acc : filAccounts) {
      Contact c = new Contact(
        LastName = acc.Name,
        AccountId = acc.Id,
        Phone = acc.Phone
      );
      conListToUpd.add(c);
    }

    if (conListToUpd.size() > 0) {
      insert conListToUpd;
    }
  }

  private void deleteRelOppsAndCheckDoNotContactOnConWhenAccInactive(
    List<Account> accListNew,
    Map<Id, Account> accMapOld
  ) {

    List<Contact> conList = new List<Contact>();
    List<Opportunity> oppListToDelete = new List<Opportunity>();
    Set<Id> accIds = new Set<Id>();
    List<Account> accListOfInterest = new List<Account>();

    for (Account acc : accListNew) {
      if (
        (acc.Active__c == 'No') &&
        (acc.Active__c != accMapOld.get(acc.Id).Active__c)
      ) {
        accIds.add(acc.Id);
      }
    }

    accListOfInterest = [
      SELECT
        Id,
        (SELECT Id, Do_not_Contact__c FROM Contacts),
        (SELECT Id FROM Opportunities)
      FROM Account
      WHERE Id IN :accIds
    ];

    boolean isAccountListFilled = accListOfInterest.size() > 0;

    if (isAccountListFilled) {
      for (Account acc : accListOfInterest) {
        conList.addAll(acc.Contacts);
        oppListToDelete.addAll(acc.Opportunities);
      }
    }

    boolean isOppListToDelFilled = oppListToDelete.size() > 0;
    boolean isConListFilled = conList.size() > 0;

    if (isOppListToDelFilled) {
      delete oppListToDelete;
    }

    if (isConListFilled) {
      for (Contact con : conList) {
        con.Do_not_Contact__c = true;
      }

      update conList;
    }
  }

  private void preventDuplicationOfAccountBasedOnName(
    list<Account> accListNew,
    map<Id, Account> accOldMap
  ) {
    list<String> accNames = new List<String>();

    for (Account acc : accListNew) {
      if (Trigger.isInsert) {
        accNames.add(acc.Name);
      }
      if (Trigger.isUpdate) {
        if (acc.Name != accOldMap.get(acc.Id).Name) {
          accNames.add(acc.Name);
        }
      }
    }

    if (accNames.size() > 0) {
      integer dupAccounts = [
        SELECT COUNT()
        FROM Account
        WHERE Account.Name IN :accNames
      ];

      if (dupAccounts > 0) {
        accListNew[0]
          .addError(
            'You can not create or update accounts with duplicate names. Please remove all duplicate Accounts.'
          );
      }
    }
  }

  private void updateRelatedContactPhoneFieldWithAccountPhone(
    list<Account> accListNew,
    map<Id, Account> accOldMap
  ) {
    Set<Id> accIds = new Set<Id>();

    for (Account acc : accListNew) {
      if (acc.Phone != null && acc.Phone != accOldMap.get(acc.Id).Phone) {
        accIds.add(acc.Id);
      }
    }

    list<Contact> conList = [
      SELECT Id, Phone, Account.Phone
      FROM Contact
      WHERE AccountId IN :accIds
    ];

    for (Contact con : conList) {
      con.Phone = con.Account.Phone;
    }

    if (conList.size() > 0) {
      update conList;
    }
  }

  private void sendEmailToRelatedContactOfAccWhenTypeUpd(
    list<Account> accList
  ) {
    Set<Id> accountIds = new Set<Id>();
    for (Account a : accList) {
      if (a.Type != accOldMap.get(a.Id).Type) {
        accountIds.add(a.Id);
      }
    }
    if (accountIds.size() > 0) {
      list<Messaging.SingleEmailMessage> emList = new List<Messaging.SingleEmailMessage>();
      list<Contact> conList = [
        SELECT Id, Email, LastName, AccountId
        FROM Contact
        WHERE AccountId IN :accountIds
      ];
      if (conList.size() > 0) {
        for (contact c : conList) {
          if (c.Email != null) {
            Messaging.SingleEmailMessage em = new Messaging.SingleEmailMessage();
            em.setSenderDisplayName('Salesforce');
            em.setSubject('Account Updated');
            em.setToAddresses(new List<String>{ c.Email });
            string body = 'Hello ' + c.LastName + '<br/> <br/>';
            body += 'Your Account is updated in our database.';
            em.setHtmlBody(body);
            emList.add(em);
          }
        }
      }
      if (emList.size() > 0) {
        list<Messaging.SendEmailResult> emResults = Messaging.sendEmail(emList);
      }
    }
  }

  private void closeAllOppWhenAccountCheckboxTicked(list<Account> accList) {
    Set<Id> accountIdsTicked = new Set<Id>();
    list<Opportunity> oppListToUpd = new List<Opportunity>();
    list<Opportunity> oppListOfInterest = new List<Opportunity>();

    for (Account acc : accList) {
      if (Trigger.isInsert) {
        if (acc.Auto_close_opp_if_prob_Gr_70__c == true) {
          accountIdsTicked.add(acc.Id);
        }
      }
      if (Trigger.isUpdate) {
        if (
          acc.Auto_close_opp_if_prob_Gr_70__c == true &&
          acc.Auto_close_opp_if_prob_Gr_70__c !=
          accOldMap.get(acc.Id).Auto_close_opp_if_prob_Gr_70__c
        ) {
          accountIdsTicked.add(acc.Id);
        }
      }
    }

    if (accountIdsTicked.size() > 0) {
      oppListOfInterest = [
        SELECT Probability, StageName
        FROM Opportunity
        WHERE AccountId IN :accountIdsTicked
      ];
      if (oppListOfInterest.size() > 0) {
        for (Opportunity opp : oppListOfInterest) {
          if (opp.Probability != null && opp.Probability > 70) {
            opp.StageName = 'Closed Won';
            oppListToUpd.add(opp);
          }
        }
        if (oppListToUpd.size() > 0) {
          update oppListToUpd;
        }
      }
    }
  }

  private void createContactAndUpdateClientContactOnAccount(
    list<Account> insertAccountList
  ) {
    list<Account> accForClientContactUpdation = new List<Account>();

    map<Id, Contact> accountIdContactMap = createRelatedContactWithAccount(
      insertAccountList
    );

    Boolean isAccConMapHaveData = accountIdContactMap.size() > 0;

    if (isAccConMapHaveData) {
      accForClientContactUpdation = queryAccountsForClientContactUpdation(
        accountIdContactMap
      );

      boolean isAccountsInList = accForClientContactUpdation.size() > 0;
      if (isAccountsInList) {
        updateClientContactInAccount(
          accForClientContactUpdation,
          accountIdContactMap
        );
      }
    }
  }

  private map<Id, Contact> createRelatedContactWithAccount(
    list<Account> accountList
  ) {
    map<Id, Contact> accountIdContactMap = new Map<Id, Contact>();
    for (Account acc : accountList) {
      Contact con = new Contact(LastName = acc.Name, AccountId = acc.Id);
      accountIdContactMap.put(acc.Id, con);
    }
    boolean isMapAccWithConHaveData = accountIdContactMap.size() > 0;
    if (isMapAccWithConHaveData) {
      insert accountIdContactMap.values();
    }
    return accountIdContactMap;
  }

  private list<Account> queryAccountsForClientContactUpdation(
    map<Id, Contact> accIdConMap
  ) {
    return [
      SELECT Id, Client_Contact__c
      FROM Account
      WHERE Id IN :accIdConMap.keySet()
    ];
  }

  private void updateClientContactInAccount(
    list<Account> accountsToBeUpdWithClientContact,
    map<Id, Contact> accountIdContactMap
  ) {
    list<Account> accountsToBeUpd = new List<Account>();
    for (Account acc : accountsToBeUpdWithClientContact) {
      if (accountIdContactMap.containsKey(acc.Id)) {
        acc.Client_Contact__c = accountIdContactMap.get(acc.Id).Id;
        accountsToBeUpd.add(acc);
      }
    }
    if (accountsToBeUpd.size() > 0) {
      update accountsToBeUpd;
    }
  }
}
