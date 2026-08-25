import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDoctors from '@salesforce/apex/BookingController.getDoctors';
import getAvailableSlots from '@salesforce/apex/BookingController.getAvailableSlots';
import bookAppointment from '@salesforce/apex/BookingController.bookAppointment';

export default class BookingForm extends LightningElement {
    doctorOptions = [];
    selectedDoctorId;
    selectedDate = new Date().toISOString().slice(0, 10);
    rawSlots = [];
    selectedSlot;
    patientName = '';
    patientPhone = '';
    isLoading = false;
    confirmation;
    confirmedAppointmentId;
    errorMessage;

    wiredSlotsResult;

    @wire(getDoctors)
    wiredDoctors({ data, error }) {
        if (data) {
            this.doctorOptions = data.map((d) => ({
                label: d.Clinic_Name__c ? `${d.Name} - ${d.Clinic_Name__c}` : d.Name,
                value: d.Id
            }));
            if (!this.selectedDoctorId && data.length > 0) {
                this.selectedDoctorId = data[0].Id;
            }
        } else if (error) {
            this.errorMessage = 'Could not load doctors.';
        }
    }

    @wire(getAvailableSlots, { doctorId: '$selectedDoctorId', apptDate: '$selectedDate' })
    wiredSlots(result) {
        this.wiredSlotsResult = result;
        if (result.data) {
            // slotTime is a plain "HH:mm" string from Apex (see TimeUtils) --
            // Apex Time does not round-trip reliably across the wire, so it is
            // never used directly in any @AuraEnabled signature.
            this.rawSlots = result.data.map((s) => ({
                key: s.slotTime,
                label: this.formatTime(s.slotTime),
                value: s.slotTime,
                disabled: !s.isAvailable
            }));
        }
    }

    get slots() {
        return this.rawSlots.map((s) => {
            let className = 'cq-slot-btn';
            let style = '';
            if (s.disabled) {
                className += ' taken';
            } else if (s.value === this.selectedSlot) {
                className += ' selected';
                // Inline style as a belt-and-suspenders backstop alongside the
                // .selected class, in case of any CSS cascade surprises.
                style = 'background:#0f766e;border-color:#0f766e;color:#ffffff;';
            }
            return { ...s, className, style };
        });
    }

    formatTime(hhmm) {
        const [hh, mm] = hhmm.split(':');
        const hour = parseInt(hh, 10);
        const period = hour >= 12 ? 'PM' : 'AM';
        const displayHour = ((hour + 11) % 12) + 1;
        return `${displayHour}:${mm} ${period}`;
    }

    handleDoctorChange(event) {
        this.selectedDoctorId = event.detail.value;
        this.selectedSlot = undefined;
    }

    handleDateChange(event) {
        this.selectedDate = event.detail.value;
        this.selectedSlot = undefined;
    }

    handleSlotClick(event) {
        this.selectedSlot = event.currentTarget.dataset.value;
    }

    handleNameChange(event) {
        this.patientName = event.detail.value;
    }

    handlePhoneChange(event) {
        this.patientPhone = event.detail.value;
    }

    get isSubmitDisabled() {
        return !this.selectedSlot || !this.patientName || !this.patientPhone || this.isLoading;
    }

    get selectedSlotLabel() {
        return this.selectedSlot ? this.formatTime(this.selectedSlot) : '';
    }

    get hasSlots() {
        return this.slots && this.slots.length > 0;
    }

    // Apex/Aura errors from an imperative call do not have one consistent
    // shape: AuraHandledException usually surfaces as error.body.message,
    // but validation-style and some other error paths surface as
    // error.body being an array of {message} objects, or a pageErrors
    // array, instead. Handle all of them rather than assuming the happy
    // shape and silently showing nothing when it differs.
    extractErrorMessage(error) {
        const body = error && error.body;
        if (body) {
            if (typeof body.message === 'string' && body.message) {
                return body.message;
            }
            if (Array.isArray(body) && body.length > 0 && body[0].message) {
                return body[0].message;
            }
            if (Array.isArray(body.pageErrors) && body.pageErrors.length > 0 && body.pageErrors[0].message) {
                return body.pageErrors[0].message;
            }
        }
        if (error && typeof error.message === 'string' && error.message) {
            return error.message;
        }
        return 'Could not book that slot. Please try again.';
    }

    async handleSubmit() {
        this.errorMessage = undefined;
        this.isLoading = true;
        try {
            const newAppointmentId = await bookAppointment({
                doctorId: this.selectedDoctorId,
                apptDate: this.selectedDate,
                slotTime: this.selectedSlot,
                patientName: this.patientName,
                patientPhone: this.patientPhone
            });
            this.confirmedAppointmentId = newAppointmentId;
            this.confirmation = `Booked for ${this.formatTime(this.selectedSlot)} on ${this.selectedDate}.`;
            this.patientName = '';
            this.patientPhone = '';
            this.selectedSlot = undefined;
            await refreshApex(this.wiredSlotsResult);
        } catch (error) {
            this.errorMessage = this.extractErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }
}
