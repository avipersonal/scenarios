public with sharing class ContactTriggerHandler extends TriggerHandler {
  private list<Contact> conListNew;
  private list<Contact> conListOld;
  private map<Id, Contact> conIdOldMap;

  public ContactTriggerHandler() {
    conListNew = (list<Contact>) Trigger.new;
    conListOld = (list<Contact>) Trigger.old;
    conIdOldMap = (map<Id, Contact>) Trigger.oldMap;
  }

  protected override void beforeInsert() {
    updateAccountRecTypeToContactAndCheckValOnMod(
      this.conListNew,
      this.conIdOldMap
    );
    preventContactDuplicationBasedOnEmPh(this.conListNew);
    preventContactInsertIfMorThan2OnAcc(this.conListNew);
    enforceOnePrimaryContactPerAccount(this.conListNew);
  }

  protected override void beforeUpdate() {
    updateAccountRecTypeToContactAndCheckValOnMod(
      this.conListNew,
      this.conIdOldMap
    );
    preventContactDuplicationBasedOnEmPh(this.conListNew);
    preventContactInsertIfMorThan2OnAcc(this.conListNew);
    enforceOnePrimaryContactPerAccount(this.conListNew);
  }

  protected override void afterInsert() {
    countTotalContactsAndUpdateOnAccount(this.conListNew, this.conIdOldMap);
  }

  protected override void afterUpdate() {
    preventContactInsertIfMorThan2OnAcc(this.conListNew);
    updateDescriptionOfAccountByConDescription(
      this.conListNew,
      this.conIdOldMap
    );
    countTotalContactsAndUpdateOnAccount(this.conListNew, this.conIdOldMap);
  }

  protected override void afterDelete() {
    countTotalContactsAndUpdateOnAccount(this.conListOld, this.conIdOldMap);
  }

  protected override void afterUnDelete() {
    countTotalContactsAndUpdateOnAccount(this.conListNew, this.conIdOldMap);
  }

  private void updateAccountRecTypeToContactAndCheckValOnMod(
    List<Contact> conListNew,
    Map<Id, Contact> conIdOldMap
  ) {
    Set<Id> accountIds = getAccountIds(conListNew, conIdOldMap);
    Map<Id, string> accIdToRecordTypeNameMap = createMapOfAccountIdAndRecordTypeName(
      accountIds
    );

    if (Trigger.isInsert) {
      insertAccountRecordTypeToContactType(
        conListNew,
        accIdToRecordTypeNameMap
      );
    } else if (Trigger.isUpdate) {
      validateAccountTypeWithContactType(conListNew, accIdToRecordTypeNameMap);
    }
  }

  private void countTotalContactsAndUpdateOnAccount(
    list<Contact> conListTrContext,
    map<Id, Contact> conOldMap
  ) {
    Set<Id> accIds = new Set<Id>();
    map<Id, integer> accIdTotalContactsMap = new Map<Id, integer>();
    list<Account> accListToUpd = new List<Account>();

    for (Contact con : conListTrContext) {
      if (Trigger.isInsert) {
        if (con.accountId != null) {
          accIds.add(con.accountId);
        }
      }
      if (Trigger.isUpdate) {
        Id accOldId = conOldMap.get(con.Id).AccountId;
        if (con.AccountId != accOldId) {
          if (con.AccountId != null) {
            accIds.add(con.AccountId);
          }
          if (accOldId != null) {
            accIds.add(accOldId);
          }
        }
      }
      if (Trigger.isDelete) {
        if (con.AccountId != null) {
          accIds.add(con.AccountId);
        }
      }
      if (Trigger.isUndelete) {
        if (con.AccountId != null) {
          accIds.add(con.AccountId);
        }
      }
    }

    if (accIds.size() > 0) {
      list<AggregateResult> result = [
        SELECT Count(Id), AccountId
        FROM Contact
        WHERE AccountId IN :accIds
        GROUP BY AccountId
      ];

      if (result.size() > 0) {
        Set<Id> accIdsInAgrCheck = new Set<Id>();
        for (AggregateResult ar : result) {
          accIdTotalContactsMap.put(
            (Id) aR.get('AccountId'),
            ((Double) (aR.get('expr0'))).intValue()
          );
          accIdsInAgrCheck.add((Id) aR.get('AccountId'));
        }
        for (Id accId : accIds) {
          if (!(accIdsInAgrCheck.contains(accId))) {
            accIdTotalContactsMap.put(accId, 0);
          }
        }
      } else {
        for (Id accId : accIds) {
          accIdTotalContactsMap.put(accId, 0);
        }
      }

      if (accIdTotalContactsMap.size() > 0) {
        for (Id accId : accIds) {
          if (accIdTotalContactsMap.containsKey(accId)) {
            Account acc = new Account(Id = accId);
            acc.Total_Contacts__c = accIdTotalContactsMap.get(accId);
            accListToUpd.add(acc);
          }
        }

        if (accListToUpd.size() > 0) {
          update accListToUpd;
        }
      }
    }
  }

  private void updateDescriptionOfAccountByConDescription(
    list<Contact> conListNew,
    map<Id, Contact> conIdOldMap
  ) {
    Set<Id> accIds = new Set<Id>();
    Map<Id, Account> accMap = new Map<Id, Account>();

    for (Contact con : conListNew) {
      if (
        con.AccountId != null &&
        con.Description != conIdOldMap.get(con.Id).Description
      ) {
        if (accMap.containsKey(con.AccountId)) {
          Account acc = accMap.get(con.AccountId);
          acc.Description = con.Description;
        } else {
          Account acc = new Account(Id = con.AccountId);
          acc.Description = con.Description;
          accMap.put(con.accountId, acc);
        }
      }
    }

    if (accMap.size() > 0) {
      update accMap.values();
    }
  }

  private void preventContactInsertIfMorThan2OnAcc(list<Contact> contacts) {
    Set<Id> accountIds = new Set<Id>();
    Set<Id> accConGr2 = new Set<Id>();
    for (Contact con : contacts) {
      if (Trigger.isInsert) {
        if (con.AccountId != null) {
          accountIds.add(con.AccountId);
        }
      }
    }
    if (accountIds.size() > 0) {
      list<Account> accInterest = [
        SELECT Id, (SELECT Id FROM Contacts)
        FROM Account
        WHERE Id IN :accountIds
      ];
      for (Account aI : accInterest) {
        if (aI.Contacts.size() >= 2) {
          accConGr2.add(aI.Id);
        }
      }
      for (Contact con : contacts) {
        if (con.AccountId != null && accConGr2.contains(con.AccountId)) {
          con.addError('The Account can\'t have more than two contacts');
        }
      }
    }
  }

  private void preventContactDuplicationBasedOnEmPh(list<Contact> contacts) {
    map<Id, string> conIdEmailMap = new Map<Id, string>();
    map<Id, string> conIdPhoneMap = new Map<Id, string>();
    list<Contact> conListOfInterest = new List<Contact>();
    string errorMessage = '';
    for (Contact c : contacts) {
      if (c.Email != null) {
        conIdEmailMap.put(c.Id, c.Email);
      }
      if (c.Phone != null) {
        conIdPhoneMap.put(c.Id, c.Phone);
      }
    }
    map<Id, Contact> dupContacts = new Map<Id, Contact>(
      [
        SELECT Email, Phone
        FROM Contact
        WHERE
          Email IN :conIdEmailMap.values()
          OR Phone IN :conIdPhoneMap.values()
      ]
    );
    if (dupContacts.size() > 0) {
      for (Contact c : contacts) {
        Contact cRefChange = new Contact(Id = c.Id);
        if (dupContacts.containskey(cRefChange.Id)) {
          if (dupContacts.get(cRefChange.Id).Email != null) {
            errorMessage = 'There is the record with the same email';
          }
          if (dupContacts.get(cRefChange.Id).Phone != null) {
            errorMessage = errorMessage != null
              ? 'and Phone found in the system'
              : 'There is the record with the same phone found in the system';      
          } else {
            errorMessage += ' found in the system';
          }
        }
        if (errorMessage != '') {
          conListOfInterest.add(cRefChange);
        }
      }
      if (conListOfInterest.size() > 0) {
        contacts[0].addError(errorMessage);
      }
    }
  }

  private void enforceOnePrimaryContactPerAccount(list<Contact> conList) {
    Set<Id> accountIds = new Set<Id>();
    integer primConOnAcc = 0;

    for (Contact con : conList) {
      if (con.Primary_Contact__c == true && con.AccountId != null) {
        if (Trigger.isInsert) {
          accountIds.add(con.AccountId);
        }
        if (Trigger.isUpdate) {
          if (
            (con.Primary_Contact__c !=
            conIdOldMap.get(con.Id).Primary_Contact__c) ||
            (con.AccountId != conIdOldMap.get(con.Id).AccountId)
          ) {
            accountIds.add(con.AccountId);
          }
        }
      }
    }

    if (accountIds.size() > 0) {
      list<AggregateResult> results = [
        SELECT Count(Id), AccountId
        FROM Contact
        WHERE Primary_Contact__c = TRUE AND AccountId IN :accountIds
        GROUP BY AccountId
      ];

      if (results.size() > 0) {
        for (AggregateResult r : results) {
          primConOnAcc = (integer) r.get('expr0');
          if (primConOnAcc > 0) {
            conList[0]
              .addError(
                'One Account can have only one Primary Account please untick the primary contact checkbox to make this as primary contact'
              );
          }
        }
      }
    }
  }

  private Set<Id> getAccountIds(
    List<Contact> conListNew,
    Map<Id, Contact> conIdOldMap
  ) {
    Set<Id> accountIds = new Set<Id>();

    for (Contact con : conListNew) {
      if (Trigger.isInsert) {
        if (con.AccountId != null) {
          accountIds.add(con.AccountId);
        }
      } else if (Trigger.isUpdate) {
        if (
          con.AccountId != null &&
          (con.Contact_Type__c != conIdOldMap.get(con.Id).Contact_Type__c)
        ) {
          accountIds.add(con.AccountId);
        }
        if (
          con.AccountId != null &&
          (con.AccountId != conIdOldMap.get(con.Id).AccountId)
        ) {
          accountIds.add(con.AccountId);
        }
      }
    }

    return accountIds;
  }

  private Map<Id, string> createMapOfAccountIdAndRecordTypeName(
    Set<Id> accountIds
  ) {
    Map<Id, string> accIdToRecordTypeNameMap = new Map<Id, string>();

    List<Account> accList = [
      SELECT RecordType.Name, Id
      FROM Account
      WHERE Id IN :accountIds
    ];

    for (Account acc : accList) {
      accIdToRecordTypeNameMap.put(acc.Id, acc.RecordType.Name);
    }

    return accIdToRecordTypeNameMap;
  }

  private void insertAccountRecordTypeToContactType(
    List<Contact> conListNew,
    Map<Id, string> accIdRecordTypeMap
  ) {
    for (Contact con : conListNew) {
      if (
        con.AccountId != null && accIdRecordTypeMap.containsKey(con.AccountId)
      ) {
        con.Contact_Type__c = accIdRecordTypeMap.get(con.AccountId);
      }
    }
  }

  private void validateAccountTypeWithContactType(
    List<Contact> conListNew,
    Map<Id, string> accIdRecordTypeMap
  ) {
    for (Contact con : conListNew) {
      if (
        con.AccountId != null &&
        (con.Contact_Type__c != conIdOldMap.get(con.Id).Contact_Type__c) &&
        (con.AccountId == conIdOldMap.get(con.Id).AccountId) &&
        accIdRecordTypeMap.containsKey(con.AccountId)
      ) {
        if (con.Contact_Type__c != accIdRecordTypeMap.get(con.AccountId)) {
          con.addError(
            'The contact type must have the same value as the account record type.'
          );
        }
      } else if (
        con.AccountId != null &&
        (con.AccountId != conIdOldMap.get(con.Id).AccountId) &&
        accIdRecordTypeMap.containsKey(con.AccountId)
      ) {
        con.Contact_Type__c = accIdRecordTypeMap.get(con.AccountId);
      } else if (con.AccountId == null) {
        con.Contact_Type__c = null;
      }
    }
  }
}
