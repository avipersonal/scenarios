import { createElement } from "lwc";
import JobApplicationList from "c/jobApplicationList";
import getJobApplications from "@salesforce/apex/JobApplicationController.getJobApplications";
import getJobApplicationsBasedOnSearch from "@salesforce/apex/JobApplicationController.getJobApplicationsBasedOnSearch";
import { publish, MessageContext } from "lightning/messageService";
import JOBAPPLICATIONMC from "@salesforce/messageChannel/JOBAPPLICATION__c";
import { getNavigateCalledWith } from "lightning/navigation";

const SERVER_DATA = {
  isFirst: true,
  isLast: false,
  jobAppIdToCdIdMap: {},
  jobApplicationList: [],
  pageIndex: 0
};

const JOB_APPLICATION_LIST = require("./data/JobApplicationListFilled.json");
const JOB_APPLICATION_ERROR = require("./data/JobApplicationListError.json");
const JOB_APPLICATION_LIST_EMPTY = require("./data/JobApplicationListEmpty.json");

const getDisableButtonsName = (buttonList) => {
  let x = "";
  buttonList.forEach((bE, index) => {
    if (bE.disabled === true) {
      if (index !== buttonList.length - 1) {
        x += bE.name + ";";
      } else {
        x += bE.name;
      }
    }
  });

  return x;
};

// these array functions work on only array type not on iterable so we have first comverted them to array type.
function getDisabledDownloadButtons(dBList) {
  const disabledButtons = Array.from(dBList).filter(
    (db) => db.disabled === true
  );

  return disabledButtons;
}

jest.mock(
  "@salesforce/apex/JobApplicationController.getJobApplications",
  () => {
    return {
      default: jest.fn()
    };
  },
  {
    virtual: true
  }
);

jest.mock(
  "@salesforce/apex/JobApplicationController.getJobApplicationsBasedOnSearch",
  () => {
    return {
      default: jest.fn()
    };
  },
  {
    virtual: true
  }
);

afterEach(() => {
  // The jsdom instance is shared across test cases in a single file so reset the DOM
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }

  SERVER_DATA.jobAppIdToCdIdMap = {};
  SERVER_DATA.jobApplicationList = [];
  SERVER_DATA.pageIndex = 0;
  SERVER_DATA.isFirst = true;
  SERVER_DATA.isLast = false;

  jest.clearAllMocks();
});

describe("Loading Job Application functionality Test suite", () => {
  test("Test No Job application in list", () => {
    const element = createElement("c-job-application-list", {
      is: JobApplicationList
    });

    getJobApplications.mockResolvedValue(SERVER_DATA);
    document.body.appendChild(element);

    const tableRowElement = element.shadowRoot.querySelectorAll("tbody tr");
    expect(tableRowElement.length).toBe(1);

    const isNoDataAvailableRow = Array.from(tableRowElement).some(
      (tr) => tr.className === "no-data-row"
    );
    expect(isNoDataAvailableRow).toBeTruthy();

    return new Promise(setTimeout).then(() => {
      const tableRowElementAfWireData =
        element.shadowRoot.querySelectorAll("tbody tr");
      expect(tableRowElementAfWireData.length).toBe(1);

      const isNoDataAvailableRowAfWireData = Array.from(tableRowElement).some(
        (tr) => tr.className === "no-data-row"
      );
      expect(isNoDataAvailableRowAfWireData).toBeTruthy();

      const buttonList = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );

      expect(getDisableButtonsName(buttonList)).toBe("start;back;");
    });
  });

  test("Test When Job application in list", () => {
    const element = createElement("c-job-application-list", {
      is: JobApplicationList
    });

    SERVER_DATA.jobApplicationList = JOB_APPLICATION_LIST;

    getJobApplications.mockResolvedValue(SERVER_DATA);
    document.body.appendChild(element);

    const tableRowElement = element.shadowRoot.querySelectorAll("tbody tr");
    expect(tableRowElement.length).toBe(1);

    const isNoDataAvailableRow = Array.from(tableRowElement).some(
      (tr) => tr.className === "no-data-row"
    );
    expect(isNoDataAvailableRow).toBeTruthy();

    return new Promise(setTimeout).then(() => {
      const tableRowElementAfWireData =
        element.shadowRoot.querySelectorAll("tbody tr");
      expect(tableRowElementAfWireData.length).toBe(10);

      const isNoDataAvailableRowAfWireData = Array.from(
        tableRowElementAfWireData
      ).some((tr) => tr.className === "no-data-row");
      expect(isNoDataAvailableRowAfWireData).toBeFalsy();

      const downloadResButtons = element.shadowRoot.querySelectorAll(
        'lightning-button[title="Download Resume"]'
      );
      expect(downloadResButtons.length).toBe(10);
      expect(getDisabledDownloadButtons(downloadResButtons).length).toBe(10);

      const buttonList = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );

      expect(getDisableButtonsName(buttonList)).toBe("start;back;");
    });
  });

  test("Test When Job application in list which also contains document ids", () => {
    const element = createElement("c-job-application-list", {
      is: JobApplicationList
    });

    SERVER_DATA.jobApplicationList = JOB_APPLICATION_LIST;

    // To check for download buttons which are enabled, we need to give some application Id as keys. Here two keys are given so two download buttons will be enabled.
    SERVER_DATA.jobAppIdToCdIdMap = {
      a0A2w00000l72jNEAQ: "0692w00000RLTEdAAP",
      a0A2w00000l74LDEAY: "0692w00000RLTEdAAP"
    };

    getJobApplications.mockResolvedValue(SERVER_DATA);
    document.body.appendChild(element);

    return new Promise(setTimeout).then(() => {
      const tableRowElementAfWireData =
        element.shadowRoot.querySelectorAll("tbody tr");
      expect(tableRowElementAfWireData.length).toBe(10);

      const isNoDataAvailableRowAfWireData = Array.from(
        tableRowElementAfWireData
      ).some((tr) => tr.className === "no-data-row");
      expect(isNoDataAvailableRowAfWireData).toBeFalsy();

      const downloadResButtons = element.shadowRoot.querySelectorAll(
        'lightning-button[title="Download Resume"]'
      );
      expect(downloadResButtons.length).toBe(10);
      expect(getDisabledDownloadButtons(downloadResButtons).length).toBe(8);

      const buttonList = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );

      expect(getDisableButtonsName(buttonList)).toBe("start;back;");
    });
  });

  test("Test when get error in getting job application list", () => {
    const element = createElement("c-job-application-list", {
      is: JobApplicationList
    });

    getJobApplications.mockRejectedValue(JOB_APPLICATION_ERROR);
    document.body.appendChild(element);

    return new Promise(setTimeout).then(() => {
      const tableRowElementAfWireData =
        element.shadowRoot.querySelectorAll("tbody tr");
      expect(tableRowElementAfWireData.length).toBe(1);

      const isNoDataAvailableRowAfWireData = Array.from(
        tableRowElementAfWireData
      ).some((tr) => tr.className === "no-data-row");
      expect(isNoDataAvailableRowAfWireData).toBeTruthy();

      const downloadResButtons = element.shadowRoot.querySelectorAll(
        'lightning-button[title="Download Resume"]'
      );
      expect(downloadResButtons.length).toBe(0);
      expect(getDisabledDownloadButtons(downloadResButtons).length).toBe(0);

      const buttonList = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );

      expect(getDisableButtonsName(buttonList)).toBe("");
    });
  });
});

describe("Pagination functionality Test suite", () => {
  beforeEach(() => {
    const element = createElement("c-job-application-list", {
      is: JobApplicationList
    });

    getJobApplications.mockResolvedValue(SERVER_DATA);
    document.body.appendChild(element);
  });

  test("test when end button is clicked", () => {
    SERVER_DATA.isFirst = false;
    SERVER_DATA.isLast = true;
    SERVER_DATA.pageIndex = 2;

    const element = document.querySelector("c-job-application-list");
    const pagEndButtonElement = element.shadowRoot.querySelector(".button-end");

    pagEndButtonElement.dispatchEvent(new CustomEvent("click"));

    return new Promise(setTimeout).then(() => {
      const pagButtonElements = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );

      expect(getDisableButtonsName(pagButtonElements)).toBe("forward;end");
    });
  });

  test("test when start button is clicked", () => {
    SERVER_DATA.isFirst = true;
    SERVER_DATA.isLast = false;
    SERVER_DATA.pageIndex = 0;

    const element = document.querySelector("c-job-application-list");
    const pagStartButtonElement =
      element.shadowRoot.querySelector(".button-start");

    pagStartButtonElement.dispatchEvent(new CustomEvent("click"));

    return new Promise(setTimeout).then(() => {
      const pagButtonElements = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );

      expect(getDisableButtonsName(pagButtonElements)).toBe("start;back;");
    });
  });

  test("test when forward button is clicked and the page is not last", () => {
    SERVER_DATA.isFirst = false;
    SERVER_DATA.isLast = false;
    SERVER_DATA.pageIndex = 1;

    const element = document.querySelector("c-job-application-list");
    const pagForButtonElement =
      element.shadowRoot.querySelector(".button-forward");

    pagForButtonElement.dispatchEvent(new CustomEvent("click"));

    return new Promise(setTimeout).then(() => {
      const pagButtonElements = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );

      expect(getDisableButtonsName(pagButtonElements)).toBe("");
    });
  });

  test("test when get error while pagination", () => {
    getJobApplications.mockRejectedValue(JOB_APPLICATION_ERROR);

    const element = document.querySelector("c-job-application-list");
    const pagForButtonElement =
      element.shadowRoot.querySelector(".button-forward");

    pagForButtonElement.dispatchEvent(new CustomEvent("click"));

    return new Promise(setTimeout).then(() => {
      const pagButtonElements = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );

      expect(getDisableButtonsName(pagButtonElements)).toBe(
        "start;back;forward;end"
      );
    });
  });
});

describe("Search functionality Test suite", () => {
  beforeEach(() => {
    const element = createElement("c-job-application-list", {
      is: JobApplicationList
    });

    getJobApplications.mockResolvedValue(SERVER_DATA);
    document.body.appendChild(element);
  });

  test("When the search keyword is invalid", () => {
    const element = document.querySelector("c-job-application-list");

    const searchElement = element.shadowRoot.querySelector("lightning-input");
    searchElement.value = "s";

    searchElement.dispatchEvent(new CustomEvent("change"));

    expect(searchElement.reportValidity()).toBeFalsy();
    expect(searchElement.checkValidity()).toBeFalsy();
  });

  test("When the search keyword is valid and data is coming", () => {
    const element = document.querySelector("c-job-application-list");

    getJobApplicationsBasedOnSearch.mockResolvedValue(JOB_APPLICATION_LIST);

    const searchElement = element.shadowRoot.querySelector("lightning-input");
    searchElement.value = "sohan";

    searchElement.dispatchEvent(new CustomEvent("change"));

    expect(searchElement.reportValidity()).toBeTruthy();
    expect(searchElement.checkValidity()).toBeTruthy();

    return new Promise(setTimeout).then(() => {
      const jAElementList = element.shadowRoot.querySelectorAll("tbody tr");

      expect(jAElementList.length).toBe(10);

      const noDataRowElement = Array.from(jAElementList).find(
        (rE) => rE.className === "no-data-row"
      );
      expect(noDataRowElement).toBeUndefined();

      const butElements = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );
      expect(getDisableButtonsName(butElements)).toBe("start;back;forward;end");

      const downloadResumesEle = element.shadowRoot.querySelectorAll(
        'lightning-button[title="Download Resume"]'
      );

      expect(getDisabledDownloadButtons(downloadResumesEle).length).toBe(10);
    });
  });

  test("When the search keyword is valid but no data is coming", () => {
    const element = document.querySelector("c-job-application-list");

    getJobApplicationsBasedOnSearch.mockResolvedValue(
      JOB_APPLICATION_LIST_EMPTY
    );

    const searchElement = element.shadowRoot.querySelector("lightning-input");
    searchElement.value = "sohan";

    searchElement.dispatchEvent(new CustomEvent("change"));

    expect(searchElement.reportValidity()).toBeTruthy();
    expect(searchElement.checkValidity()).toBeTruthy();

    return new Promise(setTimeout).then(() => {
      const jAElementList = element.shadowRoot.querySelectorAll("tbody tr");

      expect(jAElementList.length).toBe(1);

      const noDataRowElement = Array.from(jAElementList).find(
        (rE) => rE.className === "no-data-row"
      );
      expect(noDataRowElement).toBeDefined();

      const butElements = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );
      expect(getDisableButtonsName(butElements)).toBe("start;back;forward;end");

      const downloadResumesEle = element.shadowRoot.querySelectorAll(
        'lightning-button[title="Download Resume"]'
      );

      expect(getDisabledDownloadButtons(downloadResumesEle).length).toBe(0);
    });
  });

  test("When the search keyword is empty", () => {
    const element = document.querySelector("c-job-application-list");

    getJobApplicationsBasedOnSearch.mockResolvedValue(JOB_APPLICATION_LIST);

    const searchElement = element.shadowRoot.querySelector("lightning-input");
    searchElement.value = "";

    searchElement.dispatchEvent(new CustomEvent("change"));

    expect(searchElement.reportValidity()).toBeTruthy();
    expect(searchElement.checkValidity()).toBeTruthy();

    return new Promise(setTimeout).then(() => {
      const jAElementList = element.shadowRoot.querySelectorAll("tbody tr");

      expect(jAElementList.length).toBe(10);

      const noDataRowElement = Array.from(jAElementList).find(
        (rE) => rE.className === "no-data-row"
      );
      expect(noDataRowElement).toBeUndefined();

      const butElements = element.shadowRoot.querySelectorAll(
        ".button-groups button"
      );
      expect(getDisableButtonsName(butElements)).toBe("start;back;");

      const downloadResumesEle = element.shadowRoot.querySelectorAll(
        'lightning-button[title="Download Resume"]'
      );

      expect(getDisabledDownloadButtons(downloadResumesEle).length).toBe(10);
    });
  });
});

describe("Publish subscribe functionality Test suite", () => {
  beforeEach(() => {
    const element = createElement("c-job-application-list", {
      is: JobApplicationList
    });

    SERVER_DATA.jobApplicationList = JOB_APPLICATION_LIST;

    getJobApplications.mockResolvedValue(SERVER_DATA);
    document.body.appendChild(element);
  });

  test("Test Publish functionality", () => {
    const element = document.querySelector("c-job-application-list");

    const jobApplication = {
      Name: "JA - 0001",
      Applicant_Name__c: "Avi Jain",
      Position_Name__c: "Salesforce Developer",
      Application_Date__c: "2023-05-12",
      Id: "a0A2w00000l72jNEAQ"
    };

    const firstRow = element.shadowRoot.querySelector("tbody tr");

    firstRow.dispatchEvent(new CustomEvent("click"));

    return Promise.resolve().then(() => {
      // expect(publish.mock.calls[0][0]).toBe();
      expect(publish.mock.calls[0][1]).toBe(JOBAPPLICATIONMC);
      expect(publish.mock.calls[0][2].status).toBe("row selected");
      expect(publish.mock.calls[0][2].recordId).toBe(jobApplication.Id);
      expect(publish.mock.calls[0][2].recordData).toMatch(
        JSON.stringify(jobApplication)
      );

      expect(firstRow.classList.contains("row-selected")).toBeTruthy();
    });
  });
});

describe("Modal and navigation test suite", () => {
  beforeEach(() => {
    const element = createElement("c-job-application-list", {
      is: JobApplicationList
    });

    SERVER_DATA.jobApplicationList = JOB_APPLICATION_LIST;

    getJobApplications.mockResolvedValue(SERVER_DATA);
    document.body.appendChild(element);
  });

  test("Test if modal displayed initially", () => {
    const element = document.querySelector("c-job-application-list");

    const modalElement = element.shadowRoot.querySelector("c-custom-modal");

    expect(modalElement).toBeNull();
  });

  test("Test create Job Application and close Modal handler", () => {
    const element = document.querySelector("c-job-application-list");

    const createApplButton = element.shadowRoot.querySelector(
      ".create-application"
    );

    createApplButton.click();

    return Promise.resolve()
      .then(() => {
        const modalElement = element.shadowRoot.querySelector("c-custom-modal");
        expect(modalElement).not.toBeNull();

        const jobApplicationFormElement = element.shadowRoot.querySelector(
          "c-job-application-form"
        );
        jobApplicationFormElement.dispatchEvent(new CustomEvent("close"));
      })
      .then(() => {
        const modalElementAfMCloseClick =
          element.shadowRoot.querySelector("c-custom-modal");
        expect(modalElementAfMCloseClick).toBeNull();
      });
  });

  test("Navigation functionality testing", () => {
    const element = document.querySelector("c-job-application-list");

    const rowAnchorClickElement = element.shadowRoot.querySelector(
      "tbody tr:first-child a"
    );

    const NAVIGATE_RECORD_ID = "a0A2w00000l72jNEAQ";
    const NAVIGATE_ACTION_NAME = "view";
    const NAVIGATE_TYPE = "standard__recordPage";

    // rowAnchorClickElement.dispatchEvent(new CustomEvent("click"));
    rowAnchorClickElement.click();

    const { pageReference } = getNavigateCalledWith();

    expect(pageReference.type).toBe(NAVIGATE_TYPE);
    expect(pageReference.attributes.recordId).toBe(NAVIGATE_RECORD_ID);
    expect(pageReference.attributes.actionName).toBe(NAVIGATE_ACTION_NAME);
  });
});
