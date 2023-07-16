import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRelatedApplications from '@salesforce/apex/relatedApplicationController.getRelatedApplications';
import JOBAPPLICATIONMC from '@salesforce/messageChannel/JOBAPPLICATION__c';
import { subscribe, unsubscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';

const ROW_SELECTED = 'Row Selected';

export default class RelatedApplications extends NavigationMixin(LightningElement) {

isSelected = false;
isLoading = false;

subscription = null;
relatedJobApplicationList = [];
isRelatedAppAvailable = false;

@wire(MessageContext) messageContext;

connectedCallback(){
    if(this.subscription) {
        this.unsubscribeMessageChannel();
    }
    this.subscribeMessageChannel();
}

subscribeMessageChannel() {
    this.subscription = subscribe(this.messageContext, JOBAPPLICATIONMC, (jAMessage) => {
        this.handleMessage(jAMessage);
    }, {scope: APPLICATION_SCOPE});
}

unsubscribeMessageChannel() {
    unsubscribe(this.subscription);
    this.subscription = null;
}

handleMessage(jAMessage) {
    console.log('Here', jAMessage);
    const selStatus = jAMessage.status;

    if(selStatus.toLowerCase() === ROW_SELECTED.toLowerCase()) {
       this.isSelected = true;
       this.isLoading = true;
       const jobAppRec = jAMessage.recordData;
       getRelatedApplications({jARec: jobAppRec}).then((result) => {
           console.log(JSON.stringify(result));
           this.relatedJobApplicationList = result;
           if(this.relatedJobApplicationList.length > 0) {
              this.isRelatedAppAvailable = true;
           } else {
              this.isRelatedAppAvailable = false;
           }
           this.isLoading = false;
       }).catch((error) => {
           console.log(JSON.stringify(error));
       })
    } else {
       this.isLoading = false;
       this.isSelected = false;
    }
}

disconnectedCallback(){
    if(this.subscription){
       this.unsubscribeMessageChannel();
    }
}

handleJobAppTileClick(event) {
    const pageRef = {
        type: "standard__recordPage",
        attributes: {
            actionName: "view",
            recordId: event.target.dataset.id,
            objectApiName: "Job_Application__c"
        }
    }

    this[NavigationMixin.Navigate](pageRef);
}

}

/*

1. build Ui for related applications make it responsive from the beginning. (will make keyboard focusable and web accessible later later)
2. send the message from publisher to subscriber
3. call the apex class to get related applications
4. make parent table row focussed to show which row related application are coming. 








*/