import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getStatus from '@salesforce/apex/PublicStatusController.getStatus';

const CHANNEL = '/event/Queue_Update__e';
const POLL_INTERVAL_MS = 6000;
const TERMINAL_STATUSES = new Set(['Completed', 'Cancelled']);

export default class PatientStatus extends LightningElement {
    appointmentId;
    status;
    errorMessage;
    subscription;
    pollTimer;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        const id = pageRef && pageRef.state && pageRef.state.id;
        if (id && id !== this.appointmentId) {
            this.appointmentId = id;
            this.loadStatus();
        }
    }

    connectedCallback() {
        // CometD/empApi support for anonymous Experience Cloud guest sessions
        // is inconsistent across orgs regardless of the guest profile's API
        // Enabled setting, so this page cannot rely on it alone. Polling is
        // the reliable path for a guest-facing status check; empApi is kept
        // as a bonus for a faster update on orgs where it does work.
        subscribe(CHANNEL, -1, () => this.loadStatus()).then((sub) => {
            this.subscription = sub;
        });
        onError((error) => {
            // eslint-disable-next-line no-console
            console.error('empApi streaming error', JSON.stringify(error));
        });
        this.pollTimer = setInterval(() => this.loadStatus(), POLL_INTERVAL_MS);
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
        }
        if (this.pollTimer) {
            clearInterval(this.pollTimer);
        }
    }

    async loadStatus() {
        if (!this.appointmentId) {
            return;
        }
        try {
            this.status = await getStatus({ appointmentId: this.appointmentId });
            this.errorMessage = undefined;
            if (this.pollTimer && TERMINAL_STATUSES.has(this.status.status)) {
                clearInterval(this.pollTimer);
                this.pollTimer = undefined;
            }
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
