import { LightningElement, wire, track } from "lwc";
import getJobApplications from "@salesforce/apex/JobApplicationController.getJobApplications";
import { NavigationMixin } from "lightning/navigation";
import getJobApplicationsBasedOnSearch from "@salesforce/apex/JobApplicationController.getJobApplicationsBasedOnSearch";
import JOBAPPLICATIONMC from "@salesforce/messageChannel/JOBAPPLICATION__c";
import { publish, MessageContext } from "lightning/messageService";

const ERROR_VARIANT = "error";
const ROW_SELECTED = "row selected";
const ROW_NOT_SELECTED = "row not selected";
const ROW_SELECTED_CLASS = "row-selected";

const URL_BASE = "/sfc/servlet.shepherd/document/download/";

export default class JobApplicationList extends NavigationMixin(
  LightningElement
) {
  @track jobApplicationList = [];
  isJobData = false;
  isLoading = false;
  pageRelatedData = {
    pageIndex: 0,
    pageLabel: "start",
    isLast: false,
    isFirst: true
  };
  searchStr;
  showModal = false;
  selectedRow;

  @wire(MessageContext) messageContext;

  handleSearchChange(event) {
    this.searchStr = event.target.value;
    const searchEle = this.template.querySelector("lightning-input");
    if (this.searchStr.length === 1) {
      searchEle.setCustomValidity(
        "The search must contain more than one parameter"
      );
      searchEle.reportValidity();
    } else {
      this.isLoading = true;
      searchEle.setCustomValidity("");
      searchEle.reportValidity();
      if (this.searchStr.length > 1) {
        this.pageRelatedData.pageIndex = 0;
        this.pageRelatedData.pageLabel = "start";
        this.pageRelatedData.isLast = true;
        this.pageRelatedData.isFirst = true;
        this.disableAndEnablingButton();
      } else if (this.searchStr.length === 0) {
        this.pageRelatedData.pageIndex = 0;
        this.pageRelatedData.pageLabel = "start";
        this.pageRelatedData.isLast = false;
        this.pageRelatedData.isFirst = true;
        this.disableAndEnablingButton();
      }
      this.getSearchList(this.searchStr);
    }
  }

  handleApplicationRowClick(event) {
    if (this.selectedRow) {
      this.selectedRow.classList.remove(ROW_SELECTED_CLASS);
    }
    event.currentTarget.classList.add(ROW_SELECTED_CLASS);
    this.selectedRow = event.currentTarget;
    const jobAppId = event.currentTarget.dataset.id;
    const jobApplication = this.jobApplicationList.find(
      (jobAp) => jobAp.Id === jobAppId
    );

    this.publishJobApplicationMessage(jobAppId, jobApplication, ROW_SELECTED);
  }

  publishJobApplicationMessage(jobAppId, jobApplication, rowSelStatus) {
    const recordData =
      rowSelStatus === ROW_SELECTED
        ? JSON.stringify(jobApplication)
        : undefined;
    const Job_Application_message = {
      status: rowSelStatus,
      recordId: jobAppId,
      recordData
    };
    console.log("Message Context -> ", JSON.stringify(this.messageContext));
    console.log("Before Publish");
    publish(this.messageContext, JOBAPPLICATIONMC, Job_Application_message);
  }

  handleModalClose() {
    this.showModal = false;
  }

  handleCreateApplication() {
    this.showModal = true;
  }

  getSearchList(searchValue) {
    getJobApplicationsBasedOnSearch({ searchIndex: searchValue })
      .then((result) => {
        this.jobApplicationList = result;
        if (this.jobApplicationList.length > 0) {
          this.isJobData = true;
        } else {
          this.isJobData = false;
        }
        this.isLoading = false;
      })
      .catch((error) => {
        console.log("error", JSON.stringify(error));
      });
  }

  connectedCallback() {
    getJobApplications({
      i: this.pageRelatedData.pageLabel,
      pc: this.pageRelatedData.pageIndex
    })
      .then((result) => {
        this.handleAndCreateJobApplicationList(result);
      })
      .catch((error) => {
        this.jobApplicationList = undefined;
        this.isJobData = false;
        this.handleNotification(error);
      });
  }

  handleAndCreateJobApplicationList(result) {
    console.log("RESULT -> " + JSON.stringify(result));
    const resultObj = JSON.parse(JSON.stringify(result));
    this.jobApplicationList = resultObj.jobApplicationList;
    const jAIdToCdIdMap = new Map();
    const jAIdToCdIdObj = resultObj.jobAppIdToCdIdMap;
    for (let x in jAIdToCdIdObj) {
      jAIdToCdIdMap.set(x, jAIdToCdIdObj[x]);
    }
    this.jobApplicationList.forEach((jobApplication) => {
      if (jAIdToCdIdMap.has(jobApplication.Id)) {
        jobApplication.url = URL_BASE + jAIdToCdIdMap.get(jobApplication.Id);
      } else {
        jobApplication.url = undefined;
      }
    });
    console.log(
      "JOB APPLICATION -> " + JSON.stringify(this.jobApplicationList)
    );
    if (this.jobApplicationList.length > 0) {
      this.isJobData = true;
    } else {
      this.isJobData = false;
    }
    this.pageRelatedData.pageIndex = resultObj.pageIndex;
    this.pageRelatedData.isLast = resultObj.isLast;
    this.pageRelatedData.isFirst = resultObj.isFirst;
    this.disableAndEnablingButton();
  }

  handleNotification(error) {}

  navigateToJobApplicationPage(event) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        actionName: "view",
        recordId: event.target.dataset.id
      }
    });
  }

  disableAndEnablingButton() {
    const pagButtonElements = this.template.querySelectorAll(
      ".button-groups button"
    );
    if (
      this.pageRelatedData.isFirst === true &&
      this.pageRelatedData.isLast === true
    ) {
      pagButtonElements.forEach((pagBut) => {
        pagBut.disabled = true;
      });
    } else if (
      this.pageRelatedData.isFirst === true &&
      this.pageRelatedData.isLast === false
    ) {
      pagButtonElements.forEach((pagBut) => {
        if (
          pagBut.name.toLowerCase() === "start" ||
          pagBut.name.toLowerCase() === "back"
        ) {
          pagBut.disabled = true;
        } else {
          pagBut.disabled = false;
        }
      });
    } else if (
      this.pageRelatedData.isFirst === false &&
      this.pageRelatedData.isLast === true
    ) {
      pagButtonElements.forEach((pagBut) => {
        if (
          pagBut.name.toLowerCase() === "end" ||
          pagBut.name.toLowerCase() === "forward"
        ) {
          pagBut.disabled = true;
        } else {
          pagBut.disabled = false;
        }
      });
    } else {
      pagButtonElements.forEach((pagBut) => {
        pagBut.disabled = false;
      });
    }
  }

  handlePagination(event) {
    const eleName = event.currentTarget.name;
    this.pageRelatedData.pageLabel = eleName.toLowerCase();
    getJobApplications({
      i: this.pageRelatedData.pageLabel,
      pc: this.pageRelatedData.pageIndex
    })
      .then((result) => {
        this.handleAndCreateJobApplicationList(result);
      })
      .catch((error) => {
        console.log(error);
        this.jobApplicationList = undefined;
        this.isJobData = false;
        const pagButElement = this.template.querySelectorAll(
          ".button-groups button"
        );
        pagButElement.forEach((pb) => {
          pb.disabled = true;
        });
        this.handleNotification(error);
      });
  }
}
