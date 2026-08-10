import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDoctors from '@salesforce/apex/BookingController.getDoctors';
import getQueue from '@salesforce/apex/QueueController.getQueue';
import checkIn from '@salesforce/apex/QueueController.checkIn';
import checkOut from '@salesforce/apex/QueueController.checkOut';
import skipAppointment from '@salesforce/apex/QueueController.skipAppointment';

const CHANNEL = '/event/Queue_Update__e';

export default class QueueConsole extends LightningElement {
    doctorOptions = [];
    selectedDoctorId;
    selectedDate = new Date().toISOString().slice(0, 10);
    queueItems = [];
    isLoading = false;

    subscription;
    wiredQueueResult;

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
            this.notifyError('Could not load doctors', error);
        }
    }

    @wire(getQueue, { doctorId: '$selectedDoctorId', apptDate: '$selectedDate' })
    wiredQueue(result) {
        this.wiredQueueResult = result;
        if (result.data) {
            this.queueItems = result.data.map((item) => ({
                ...item,
                isBooked: item.status === 'Booked',
                isCheckedIn: item.status === 'Checked In',
                statusClass: `badge badge-${item.status.replace(' ', '-').toLowerCase()}`
            }));
        } else if (result.error) {
            this.notifyError('Could not load queue', result.error);
        }
    }

    connectedCallback() {
        subscribe(CHANNEL, -1, (message) => this.handleQueueUpdate(message)).then((sub) => {
            this.subscription = sub;
        });
        onError((error) => {
            // eslint-disable-next-line no-console
            console.error('empApi streaming error', JSON.stringify(error));
        });
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
        }
    }

    handleQueueUpdate(message) {
        const payload = message && message.data && message.data.payload;
        if (!payload) {
            return;
        }
        if (payload.Doctor_Id__c === this.selectedDoctorId && payload.Appointment_Date__c === this.selectedDate) {
            refreshApex(this.wiredQueueResult);
        }
    }

    handleDoctorChange(event) {
        this.selectedDoctorId = event.detail.value;
    }

    handleDateChange(event) {
        this.selectedDate = event.detail.value;
    }

    handleCheckIn(event) {
        this.runAction(checkIn, event.currentTarget.dataset.id, 'Checked in');
    }

    handleCheckOut(event) {
        this.runAction(checkOut, event.currentTarget.dataset.id, 'Checked out');
    }

    handleSkip(event) {
        this.runAction(skipAppointment, event.currentTarget.dataset.id, 'Moved to end of queue');
    }

    async runAction(apexMethod, appointmentId, successMessage) {
        this.isLoading = true;
        try {
            await apexMethod({ appointmentId });
            await refreshApex(this.wiredQueueResult);
            this.dispatchEvent(new ShowToastEvent({ title: successMessage, variant: 'success' }));
        } catch (error) {
            this.notifyError('Action failed', error);
        } finally {
            this.isLoading = false;
        }
    }

    notifyError(title, error) {
        const message = (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }

    get hasQueueItems() {
        return this.queueItems && this.queueItems.length > 0;
    }
}
