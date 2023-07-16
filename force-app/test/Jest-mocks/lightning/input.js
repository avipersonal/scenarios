import { LightningElement, api } from "lwc";

export default class Input extends LightningElement {
  @api accept;
  @api autocomplete;
  @api checked;
  @api dateAriaControls;
  @api dateAriaDescribedBy;
  @api dateAriaLabel;
  @api dateAriaLabelledBy;
  @api dateStyle;
  @api disabled;
  @api fieldLevelHelp;
  @api files;
  @api formatFractionDigits;
  @api formatter;
  @api isLoading;
  @api label;
  @api max;
  @api maxLength;
  @api messageToggleActive;
  @api messageToggleInactive;
  @api messageWhenBadInput;
  @api messageWhenPatternMismatch;
  @api messageWhenRangeOverflow;
  @api messageWhenRangeUnderflow;
  @api messageWhenStepMismatch;
  @api messageWhenTooLong;
  @api messageWhenTooShort;
  @api messageWhenTypeMismatch;
  @api messageWhenValueMissing;
  @api min;
  @api minLength;
  @api multiple;
  @api name;
  @api pattern;
  @api placeholder;
  @api readOnly;
  @api required;
  @api selectionEnd;
  @api selectionStart;
  @api step;
  @api timeAriaControls;
  @api timeAriaDescribedBy;
  @api timeAriaLabelledBy;
  @api timeStyle;
  @api timezone;
  @api type;
  @api validity;
  @api value;
  @api variant;
  @api checkValidity() {
    if (this.isValid === true) {
      return true;
    } else {
      return false;
    }
  }
  @api reportValidity() {
    if (this.isValid === true) {
      return true;
    } else {
      return false;
    }
  }

  @api setCustomValidity(value) {
    if (value != null && value.length > 1) {
      this.isValid = false;
    }
  }

  @api showHelpMessageIfInvalid() {}

  isValid = true;
}
