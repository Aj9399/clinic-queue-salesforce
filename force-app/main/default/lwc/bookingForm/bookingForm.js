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
            // slotTime is a plain "HH:mm" string from Apex (see TimeUtils) --
            // Apex Time does not round-trip reliably across the wire, so it is
            // never used directly in any @AuraEnabled signature.
            this.slots = result.data.map((s) => ({
                key: s.slotTime,
                label: this.formatTime(s.slotTime),
                value: s.slotTime,
                disabled: !s.isAvailable,
                className: s.isAvailable ? 'slot-btn' : 'slot-btn taken'
            }));
        }
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

    async handleSubmit() {
        this.errorMessage = undefined;
        this.isLoading = true;
        try {
            await bookAppointment({
                doctorId: this.selectedDoctorId,
                apptDate: this.selectedDate,
                slotTime: this.selectedSlot,
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
