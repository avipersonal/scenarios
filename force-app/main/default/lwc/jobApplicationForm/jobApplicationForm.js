import { LightningElement } from "lwc";
import { deleteRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createJobApplicationWithDocumentShare from "@salesforce/apex/JobApplicationController.createJobApplicationWithDocumentShare";

const ERROR_VARIANT = "error";
const SUCCESS_VARIANT = "success";

export default class JobApplicationForm extends LightningElement {
  acceptedFormats = [".pdf", ".doc"];
  docId;
  isLoading = false;

  handleFormSubmit(event) {
    event.preventDefault();
    this.isLoading = true;
    const fields = event.detail.fields;
    this.createJobApplication(fields);
  }

  handleFormCancel() {
    this.dispatchEvent(new CustomEvent("close"));
    if (this.docId) {
      deleteRecord(this.docId)
        .then(() => {
          console.log("deleted");
        })
        .catch((error) => {
          console.log(error);
        });
    }
  }

  handleFormSuccess() {
    this.dispatchEvent(new CustomEvent("complete"));
  }

  createJobApplication(fields) {
    createJobApplicationWithDocumentShare({
      fields: JSON.stringify(fields),
      cdId: this.docId
    })
      .then((result) => {
        this.isLoading = false;
        this.handleNotification(
          SUCCESS_VARIANT,
          `Job Application ${result} successfully created!!`,
          "Success"
        );
        this.docId = undefined;
        this.handleFormSuccess();
      })
      .catch((error) => {
        this.isLoading = false;
        this.handleNotification(
          ERROR_VARIANT,
          `Some Error has occured`,
          "Error"
        );
      });
  }

  handleNotification(variant, message, title) {
    this.dispatchEvent(
      new ShowToastEvent({
        variant: variant,
        message: message,
        title: title
      })
    );
  }

  handleUploadFinished(event) {
    const fileData = event.detail.files;
    this.docId = fileData[0].documentId ? fileData[0].documentId : null;
    console.log(JSON.stringify(fileData));
  }
}
