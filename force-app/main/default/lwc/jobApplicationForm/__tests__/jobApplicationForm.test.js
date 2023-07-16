import { createElement } from "lwc";
import JobApplicationForm from "c/jobApplicationForm";
import createJobApplicationWithDocumentShare from "@salesforce/apex/JobApplicationController.createJobApplicationWithDocumentShare";
import { ShowToastEventName } from "lightning/platformShowToastEvent";
import { deleteRecord } from "lightning/uiRecordApi";

const inputFieldsValue = {
  Applicant_Name__c: "Avi Jain",
  Position_Name__c: "Salesforce Developer Role",
  Application_Date__c: "2022-05-09"
};

const errorFile = require("./data/errorFile.json");
const JOB_APPLICATION_ID = "a0A2w00000l72jNEAQ";

const ERROR_OBJECT = {
  variant: "error",
  message: "Some Error has occured",
  title: "Error"
};

const SUCCESS_OBJECT = {
  variant: "success",
  message: "Job Application " + JOB_APPLICATION_ID + " successfully created!!",
  title: "Success"
};

jest.mock("lightning/uiRecordApi", () => {
  return {
    deleteRecord: jest.fn()
  };
});

jest.mock(
  "@salesforce/apex/JobApplicationController.createJobApplicationWithDocumentShare",
  () => {
    return {
      default: jest.fn()
    };
  },
  { virtual: true }
);

describe("c-job-application-form test suite", () => {
  // function flushPromises() {
  //   return new Promise(setImmediate);
  // }

  beforeEach(() => {
    const element = createElement("c-job-application-form", {
      is: JobApplicationForm
    });

    document.body.appendChild(element);
  });

  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }

    jest.clearAllMocks();
  });

  it("Test Initial page rendering", () => {
    const element = document.querySelector("c-job-application-form");

    const spinnerEle = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinnerEle).toBeNull();

    const recEditForm = element.shadowRoot.querySelector(
      "lightning-record-edit-form"
    );
    expect(recEditForm).not.toBeNull();
    expect(recEditForm.objectApiName).toBe("Job_Application__c");

    const inputElements = recEditForm.querySelectorAll("lightning-input-field");
    expect(inputElements.length).toBe(3);
    expect(inputElements[0].fieldName).toBe("Applicant_Name__c");
    expect(inputElements[1].fieldName).toBe("Position_Name__c");
    expect(inputElements[2].fieldName).toBe("Application_Date__c");

    const butElements = recEditForm.querySelectorAll("lightning-button");
    expect(butElements.length).toBe(2);
  });

  it("Test handle form submit with success", () => {
    const element = document.querySelector("c-job-application-form");
    const recEditEle = element.shadowRoot.querySelector(
      "lightning-record-edit-form"
    );

    recEditEle.submit = jest.fn();

    createJobApplicationWithDocumentShare.mockResolvedValue(JOB_APPLICATION_ID);

    const handler1 = jest.fn();
    const handler2 = jest.fn(() => "Form Success");

    element.addEventListener(ShowToastEventName, handler1);
    element.addEventListener("complete", handler2);

    recEditEle.dispatchEvent(
      new CustomEvent("submit", {
        detail: {
          fields: inputFieldsValue
        }
      })
    );

    return new Promise(setTimeout).then(() => {
      expect(handler1.mock.calls.length).toBe(1);
      expect(handler1.mock.calls[0][0].detail.variant).toBe(
        SUCCESS_OBJECT.variant
      );
      expect(handler1.mock.calls[0][0].detail.message).toBe(
        SUCCESS_OBJECT.message
      );
      expect(handler1.mock.calls[0][0].detail.title).toBe(SUCCESS_OBJECT.title);

      expect(handler2.mock.results[0].value).toBe("Form Success");
    });
  });

  it("handle Form Submit with Error", () => {
    const element = document.querySelector("c-job-application-form");

    const recordEditElement = element.shadowRoot.querySelector(
      "lightning-record-edit-form"
    );

    createJobApplicationWithDocumentShare.mockRejectedValue(errorFile);

    recordEditElement.submit = jest.fn();

    const handler = jest.fn();

    element.addEventListener(ShowToastEventName, handler);

    recordEditElement.dispatchEvent(
      new CustomEvent("submit", {
        detail: {
          fields: inputFieldsValue
        }
      })
    );

    return new Promise(setTimeout).then(() => {
      expect(handler.mock.calls.length).toBe(1);
      expect(handler.mock.calls[0][0].detail.variant).toBe(
        ERROR_OBJECT.variant
      );
      expect(handler.mock.calls[0][0].detail.message).toBe(
        ERROR_OBJECT.message
      );
      expect(handler.mock.calls[0][0].detail.title).toBe(ERROR_OBJECT.title);
    });

    // const inputFields = recordEditElement.querySelectorAll(
    //   "lightning-input-field"
    // );

    // inputFields[0].value = INPUT_VALUES.Applicant_Name__c;
    // inputFields[1].value = INPUT_VALUES.Position_Name__c;
    // inputFields[2].value = INPUT_VALUES.Application_Date__c;
  });

  it("Test file upload functionality with no file given and cancel form functionality", () => {
    const ACCEPTED_FORMAT = [".pdf", ".doc"];

    const element = document.querySelector("c-job-application-form");

    const fileUplEle = element.shadowRoot.querySelector(
      "lightning-file-upload"
    );

    expect(fileUplEle).not.toBeUndefined();
    expect(fileUplEle.accept).toEqual(ACCEPTED_FORMAT);

    fileUplEle.dispatchEvent(new CustomEvent("onuploadfinished"));

    const cancelButElement = element.shadowRoot.querySelector(
      'lightning-button[title="Cancel Form Creation"]'
    );

    const handler = jest.fn();

    element.addEventListener("close", handler);

    deleteRecord.mockResolvedValue("SUCCESSFULLY DELETED!!");

    cancelButElement.click();

    return Promise.resolve().then(() => {
      expect(handler).toHaveBeenCalled();
      expect(deleteRecord).not.toHaveBeenCalled();
    });
  });

  it("Test file upload functionality with file given and cancel form functionality", () => {
    const ACCEPTED_FORMAT = [".pdf", ".doc"];

    const element = document.querySelector("c-job-application-form");

    const fileUplEle = element.shadowRoot.querySelector(
      "lightning-file-upload"
    );

    expect(fileUplEle).not.toBeUndefined();
    expect(fileUplEle.accept).toEqual(ACCEPTED_FORMAT);

    fileUplEle.dispatchEvent(
      new CustomEvent("uploadfinished", {
        detail: {
          files: [
            {
              name: "salesforce_content_implementation_guide.pdf",
              documentId: "0692w00000RMamEAAT"
            }
          ]
        }
      })
    );

    const cancelButElement = element.shadowRoot.querySelector(
      'lightning-button[title="Cancel Form Creation"]'
    );

    const handler = jest.fn();

    element.addEventListener("close", handler);

    deleteRecord.mockImplementation(() => Promise.resolve("SUCCESSFULL!!"));

    cancelButElement.click();

    return Promise.resolve().then(() => {
      expect(handler).toHaveBeenCalled();
      expect(deleteRecord).toHaveBeenCalled();
      expect(deleteRecord).toHaveBeenCalledWith("0692w00000RMamEAAT");
    });
  });
});
