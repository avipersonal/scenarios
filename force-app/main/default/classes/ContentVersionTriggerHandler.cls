public with sharing class ContentVersionTriggerHandler extends TriggerHandler {
    List<ContentVersion> contentVersionListNew = (List<ContentVersion>) Trigger.new;
    List<ContentVersion> contentVersionListOld = (List<ContentVersion>) Trigger.old;
    Map<Id, ContentVersion> contentVersionMapOld = (Map<Id, ContentVersion>) Trigger.oldMap;
    
    public ContentVersionTriggerHandler() {
        contentVersionListNew = (List<ContentVersion>) Trigger.new;
        contentVersionListOld = (List<ContentVersion>) Trigger.old;
        Map<Id, ContentVersion> contentVersionMapOld = (Map<Id, ContentVersion>) Trigger.oldMap;
    }

    protected override void afterInsert() {
        insertContentDocLinkToShareWithLib(contentVersionListNew);
    }

    private void insertContentDocLinkToShareWithLib(list<ContentVersion> cvList) {

        Set<Id> conDocId = new Set<Id>();
        Set<Id> cdlCWConDocId = new Set<Id>();
        Set<Id> cdlJAConDocId = new Set<Id>();
        List<ContentDocumentLink> cdLinksToUpd = new List<ContentDocumentLink>();

        for (ContentVersion cv : cvList) {
            if(cv.ContentDocumentId != null) {
                conDocId.add(cv.ContentDocumentId);
            }
        }

        if(conDocId.size() > 0) {
            ContentWorkspace cw = [SELECT Id FROM ContentWorkspace WHERE Name = 'Resume'];
            List<ContentDocumentLink> cdLinks = [SELECT Id, LinkedEntityId, ContentDocumentId From ContentDocumentLink where ContentDocumentId IN :conDocId];
            for (ContentDocumentLink cdl : cdLinks) {
               if(cdl.LinkedEntityId.getSobjectType() == Job_Application__c.sobjectType) {
                  cdlJAConDocId.add(cdl.ContentDocumentId);
               } else if(cdl.LinkedEntityId == cw.Id) {
                  cdlCWConDocId.add(cdl.ContentDocumentId);
               }
            }    
            
            if(cdlJAConDocId.size() > 0) {
               for(Id cdlJa : cdlJAConDocId) {
                   if(!cdlCWConDocId.contains(cdlJa)) {
                      ContentDocumentLink cdl = new ContentDocumentLink();
                      cdl.LinkedEntityId = cw.Id;
                      cdl.shareType = 'I';
                      cdl.Visibility = 'AllUsers';
                      cdl.ContentDocumentId = cdlJa;
                      cdLinksToUpd.add(cdl);
                   }
               }

               if(cdLinksToUpd.size() > 0) {
                   insert cdLinksToUpd;
               }
            }
        }
    }
}

