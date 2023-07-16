import { LightningElement, api } from 'lwc';

export default class CustomModal extends LightningElement {

@api showFooter = false;

handleModalClose() {
    this.dispatchEvent(new CustomEvent('close'));
}

}