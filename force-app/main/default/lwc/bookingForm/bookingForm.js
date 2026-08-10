import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDoctors from '@salesforce/apex/BookingController.getDoctors';
import getAvailableSlots from '@salesforce/apex/BookingController.getAvailableSlots';
import bookAppointment from '@salesforce/apex/BookingController.bookAppointment';

export default class BookingForm extends LightningElement {
    doctorOptions = [];
    selectedDoctorId;
    selectedDate = new Date().toISOString().slice(0, 10);
    slots = [];
    selectedSlot;
    patientName = '';
    patientPhone = '';
    isLoading = false;
    confirmation;
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
            this.slots = result.data.map((s) => {
                // Stash the raw wire value (milliseconds-since-midnight number) as
                // a string, since HTML data-* attributes can only hold strings.
                // It gets converted back to a Number before being sent to Apex.
                const rawValue = String(s.slotTime);
                return {
                    key: rawValue,
                    label: this.formatTime(s.slotTime),
                    value: rawValue,
                    disabled: !s.isAvailable,
                    className: s.isAvailable ? 'slot-btn' : 'slot-btn taken'
                };
            });
        }
    }

    /**
     * Apex Time on a plain @AuraEnabled wrapper (as opposed to a queried
     * SObject field) serializes over the wire as milliseconds-since-midnight,
     * and the same numeric form is what bookAppointment's Time parameter
     * expects back -- an "HH:MM:SS.000Z" string is rejected. This normalizes
     * any of number / digit-string / colon-string form into total seconds for
     * display purposes only.
     */
    toTotalSeconds(rawTime) {
        if (typeof rawTime === 'number') {
            return Math.floor(rawTime / 1000);
        }
        if (typeof rawTime === 'string' && /^\d+$/.test(rawTime)) {
            return Math.floor(Number(rawTime) / 1000);
        }
        if (typeof rawTime === 'string' && rawTime.includes(':')) {
            const [hh, mm, ss] = rawTime.split(':');
            return parseInt(hh, 10) * 3600 + parseInt(mm, 10) * 60 + parseInt(ss || '0', 10);
        }
        return 0;
    }

    formatTime(rawTime) {
        const totalSeconds = this.toTotalSeconds(rawTime);
        const hour = Math.floor(totalSeconds / 3600) % 24;
        const minute = Math.floor((totalSeconds % 3600) / 60);
        const period = hour >= 12 ? 'PM' : 'AM';
        const displayHour = ((hour + 11) % 12) + 1;
        return `${displayHour}:${String(minute).padStart(2, '0')} ${period}`;
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

    async handleSubmit() {
        this.errorMessage = undefined;
        this.isLoading = true;
        try {
            const slotTimeParam = /^\d+$/.test(this.selectedSlot) ? Number(this.selectedSlot) : this.selectedSlot;
            await bookAppointment({
                doctorId: this.selectedDoctorId,
                apptDate: this.selectedDate,
                slotTime: slotTimeParam,
                patientName: this.patientName,
                patientPhone: this.patientPhone
            });
            this.confirmation = `Booked for ${this.formatTime(this.selectedSlot)} on ${this.selectedDate}.`;
            this.patientName = '';
            this.patientPhone = '';
            this.selectedSlot = undefined;
            await refreshApex(this.wiredSlotsResult);
        } catch (error) {
            this.errorMessage = (error && error.body && error.body.message) || 'Could not book that slot.';
        } finally {
            this.isLoading = false;
        }
    }
}
