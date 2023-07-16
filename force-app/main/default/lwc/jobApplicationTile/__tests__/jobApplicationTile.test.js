import { createElement } from "lwc";
import JobApplicationTile from "c/jobApplicationTile";

const JOB_APPLICATION = {
  Name: "JA-000001",
  Applicant_Name__c: "Avi Jain",
  Application_Date__c: "2023-05-04",
  Position_Name__c: "Salesforce Developer Role"
};

describe("c-job-application-tile test suite", () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("Test when no data is given from the parent component", () => {
    // Arrange
    const element = createElement("c-job-application-tile", {
      is: JobApplicationTile
    });

    // Act
    document.body.appendChild(element);

    const ulElement = element.shadowRoot.querySelector("ul.job-tile");
    expect(ulElement).toBeNull();
  });

  it("Test when data is given from the parent component", () => {
    const element = createElement("c-job-application-tile", {
      is: JobApplicationTile
    });

    element.jobApplication = JOB_APPLICATION;
    // Act
    document.body.appendChild(element);

    const ulElement = element.shadowRoot.querySelector("ul.job-tile");
    expect(ulElement).not.toBeNull();

    const articleElement = ulElement.querySelector("article");
    expect(articleElement.textContent).toMatch(/JA-000001/i);
    expect(articleElement.textContent).toMatch(/Avi Jain/i);
    expect(articleElement.textContent).toMatch(/Salesforce Developer Role/i);
    expect(articleElement.textContent).toMatch(/2023-05-04/i);

    const h3Ele = articleElement.querySelector("h3");
    expect(h3Ele.textContent).toBe(JOB_APPLICATION.Name);

    const pElementsList = Array.from(
      articleElement.querySelectorAll(".slds-tile__detail p")
    );

    expect(pElementsList[0].textContent).toBe(
      JOB_APPLICATION.Applicant_Name__c
    );
    expect(pElementsList[1].textContent).toBe(JOB_APPLICATION.Position_Name__c);
    expect(pElementsList[2].textContent).toBe(
      JOB_APPLICATION.Application_Date__c
    );
  });
});
