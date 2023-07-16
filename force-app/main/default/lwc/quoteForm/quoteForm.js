import { LightningElement, track } from 'lwc';
import getAirTypes from '@salesforce/apex/QuoteFormHandler.getAirTypes';

export default class QuoteForm extends LightningElement {

@track airTypes = [];
selectedAirType = ''; //no need
quote = {requester: [], booker: []};
isRenderFirstTime = true;
isLoading = true;
showModal = false;

handlePassengerChange(event){
   const passengerCount = event.target.value;
   if(passengerCount < 20){
      if(this.quote.aircraftTypes && this.quote.aircraftTypes.includes('Group Charter')){
        this.removeAndDeselectFAirType();
      }
   }
   Promise.resolve().then(() => {
      this.toggleGroupCharterAircraftTypeDisAndEna(passengerCount);
   })
//       Promise.resolve().then(() => {
//         this.toggleGroupCharterAircraftTypeDisAndEna();
//       });  
//    } else {
//       this.toggleGroupCharterAircraftTypeDisAndEna();
//    }

   this.quote.flights[0].nbrOfPassengers = passengerCount;
}

removeAndDeselectFAirType(){
   if(this.quote.aircraftTypes.split(';').length > 1){
      let selAirType = this.quote.aircraftTypes.endsWith('Group Charter') ? this.quote.aircraftTypes.replace(';Group Charter', '') : this.quote.aircraftTypes.replace('Group Charter;', '');
      this.quote.aircraftTypes = selAirType;
   } else {
      delete this.quote.aircraftTypes;
   }

   this.airTypes.forEach((airType) => {
      if(airType.label === 'Group Charter' && airType.isSelected === true){
         airType.isSelected = false;
      }
   });
    console.log('AIRCRAFT TYPE IN REMOVE FUNCTION', JSON.stringify(this.aircraftTypes));
    console.log('QUOTE IN REMOVE AIRCRAFT FUNCTION', this.quote);
}

renderedCallback(){
    console.log('INSIDE RENDERED CALLBACK');
    if(this.isRenderFirstTime){ // <--------------- changes
        if(this.quote.flights){
            this.isRenderFirstTime = false;
            this.toggleGroupCharterAircraftTypeDisAndEna(this.quote.flights[0].nbrOfPassengers);
        }
    }
}

toggleGroupCharterAircraftTypeDisAndEna(passengerCount){
    const airButElements = this.template.querySelectorAll('.aircraft-type-button-disabled'); //.aircraft-type-button-disabled

    airButElements.forEach((airButEle) => {
        if(airButEle.innerText.includes('Group Charter')){ //Group Charter
            if(passengerCount < 20){
                airButEle.disabled = true;
            } else {
                airButEle.disabled = false;
            }
        }
    });
}


// makeFAirTypeDisabled(){
//     const airButElements = this.template.querySelectorAll('.aircraft-type-button-disabled'); //.aircraft-type-button-disabled

//     airButElements.forEach((airButEle) => {
//         if(airButEle.innerText.includes('Group Charter')){ //Group Charter
//             airButEle.disabled = true;
//         }
//     });
// }

// makeFAirTypeEnabled(){
//     const airButElements = this.template.querySelectorAll('.aircraft-type-button-disabled'); //.aircraft-type-button-disabled

//     airButElements.forEach((airButEle) => {
//         if(airButEle.innerText.includes('Group Charter')){ //Group Charter
//             airButEle.disabled = false;
//         }
//     });
// }

handleButtonClicked(event){
    this.selectedAirType = this.quote.aircraftTypes || '';
    let index = event.currentTarget.dataset.id;
    this.airTypes.forEach((airType) => {
        if(airType.sortOrder == index){
            airType.isSelected = !airType.isSelected;
            if(airType.isSelected === true && this.selectedAirType === ''){
                this.selectedAirType = airType.label;
            } else if(airType.isSelected === true && this.selectedAirType != ''){
                this.selectedAirType = this.selectedAirType.concat(';', airType.label);
            } else if(airType.isSelected === false && this.selectedAirType.split(';').length === 1){
                this.selectedAirType = '';
            } else if(airType.isSelected === false && this.selectedAirType.split(';').length > 1){
                this.selectedAirType = this.selectedAirType.endsWith(airType.label) ? this.selectedAirType.replace(';'+airType.label, '') : this.selectedAirType.replace(airType.label + ';', '');
            }
        }
    });

    this.quote.aircraftTypes = this.selectedAirType;
    this.selectedAirType = '';

    console.log('QUOTE IN BUTTON', this.quote);
}

connectedCallback(){
    getAirTypes().then((result) => {
        console.log('AIRCRAFT VALUES');
        let i = 0;
        this.airTypes = result.map((each) => {
            let label = each;
            let description;
            if(each === 'A'){
                description = 'Capacity up to 6';
            } else if(each === 'B'){
                description = 'Capacity up to 8';
            } else if(each === 'C'){
                description = 'Capacity up to 10';
            } else if(each === 'D'){
                description = 'Capacity up to 12';
            } else if(each === 'E'){
                description = 'Capacity up to 15';
            } else if(each === 'Group Charter'){
                description = 'Capacity 20+';
            }
            let isSelected = false;
            let sortOrder = i++;
            return {label, description, isSelected, sortOrder};
        })
        Promise.resolve().then(() => {
           console.log('INIT QUOTE');
           this.quote.flights = [{ArrivalAircraft: '', DepartureAircraft: '', nbrOfPassengers: '1'}];
           this.isLoading = false;
        });
        // Promise.resolve().then(() => {
        //     console.log('DISABLE GROUP CHARTER');
        //     if(this.quote.flights && this.quote.flights[0].nbrOfPassengers < 20){
        //        this.makeFAirTypeDisabled();
        //        this.isLoading = false;
        //     }
        // });
    }).catch(error => {
        console.log(error);
    });
}

handleSubmit(){
    this.showModal = true;
}

closeSuccessModal(){
    this.showModal = false;
    this.isLoading = true;
    this.quote = {};
    this.airTypes = [];
    getAirTypes().then((result) => {
        console.log('AIRCRAFT VALUES');
        let i = 0;
        this.airTypes = result.map((each) => {
            let label = each;
            let description;
            if(each === 'A'){
                description = 'Capacity up to 6';
            } else if(each === 'B'){
                description = 'Capacity up to 8';
            } else if(each === 'C'){
                description = 'Capacity up to 10';
            } else if(each === 'D'){
                description = 'Capacity up to 12';
            } else if(each === 'E'){
                description = 'Capacity up to 15';
            } else if(each === 'Group Charter'){
                description = 'Capacity 20+';
            }
            let isSelected = false;
            let sortOrder = i++;
            return {label, description, isSelected, sortOrder};
        })
        Promise.resolve().then(() => {
           console.log('INIT QUOTE');
           this.quote.flights = [{ArrivalAircraft: '', DepartureAircraft: '', nbrOfPassengers: '1'}];
           this.isRenderFirstTime = true;
           this.isLoading = false;
        });
        // Promise.resolve().then(() => {
        //     console.log('DISABLE GROUP CHARTER');
        //     if(this.quote.flights && this.quote.flights[0].nbrOfPassengers < 20){
        //        this.makeFAirTypeDisabled();
        //        this.isLoading = false;
        //     }
        // });
    }).catch(error => {
        console.log(error);
    });
}

}



