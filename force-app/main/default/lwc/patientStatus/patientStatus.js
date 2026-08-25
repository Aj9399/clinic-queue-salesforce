import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getStatus from '@salesforce/apex/PublicStatusController.getStatus';

const CHANNEL = '/event/Queue_Update__e';

export default class PatientStatus extends LightningElement {
    appointmentId;
    status;
    errorMessage;
    subscription;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        const id = pageRef && pageRef.state && pageRef.state.id;
        if (id && id !== this.appointmentId) {
            this.appointmentId = id;
            this.loadStatus();
        }
    }

    connectedCallback() {
        subscribe(CHANNEL, -1, () => this.loadStatus()).then((sub) => {
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

    async loadStatus() {
        if (!this.appointmentId) {
            return;
        }
        try {
            this.status = await getStatus({ appointmentId: this.appointmentId });
            this.errorMessage = undefined;
        } catch (error) {
            this.errorMessage = (error && error.body && error.body.message) || 'Could not load status.';
        }
    }

    get hasStatus() {
        return !!this.status;
    }

    get hasPosition() {
        return !!this.status && this.status.positionInQueue !== null && this.status.positionInQueue !== undefined;
    }

    get formattedSlotTime() {
        if (!this.status || !this.status.slotTime) {
            return '';
        }
        const [hh, mm] = this.status.slotTime.split(':');
        const hour = parseInt(hh, 10);
        const period = hour >= 12 ? 'PM' : 'AM';
        const displayHour = ((hour + 11) % 12) + 1;
        return `${displayHour}:${mm} ${period}`;
    }

    get noAppointmentId() {
        return !this.appointmentId;
    }

    get statusBadgeClass() {
        const key = (this.status && this.status.status ? this.status.status : '').replace(' ', '-').toLowerCase();
        return `cq-badge cq-badge-${key}`;
    }
}
