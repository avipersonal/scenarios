import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class JobApplicationTile extends NavigationMixin(LightningElement) {

@api jobApplication;

}