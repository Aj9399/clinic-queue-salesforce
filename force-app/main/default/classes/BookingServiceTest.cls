@isTest
private class BookingServiceTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createDoctor('Dr. Test');
    }

    @isTest
    static void testGetAvailableSlotsReturnsFullGridWhenNoBookings() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];

        Test.startTest();
        List<BookingService.SlotOption> slots = BookingService.getAvailableSlots(doc.Id, Date.today().addDays(1));
        Test.stopTest();

        System.assertEquals(16, slots.size(), 'Expected 16 slots between 17:00 and 21:00 at 15-minute intervals');
        for (BookingService.SlotOption opt : slots) {
            System.assertEquals(true, opt.isAvailable);
        }
    }

    @isTest
    static void testGetAvailableSlotsMarksBookedSlotUnavailable() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Date apptDate = Date.today().addDays(1);
        TestDataFactory.createAppointment(doc.Id, apptDate, Time.newInstance(17, 15, 0, 0), 1, 'Booked');

        Test.startTest();
        List<BookingService.SlotOption> slots = BookingService.getAvailableSlots(doc.Id, apptDate);
        Test.stopTest();

        Boolean foundTakenSlot = false;
        for (BookingService.SlotOption opt : slots) {
            if (opt.slotTime == '17:15') {
                foundTakenSlot = true;
                System.assertEquals(false, opt.isAvailable);
            }
        }
        System.assert(foundTakenSlot, 'Expected the booked slot to be present and marked unavailable');
    }

    @isTest
    static void testBookAppointmentCreatesRecordWithSlotDerivedQueueOrder() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Date apptDate = Date.today().addDays(1);

        Test.startTest();
        Id apptId = BookingService.bookAppointment(
            doc.Id,
            apptDate,
            '17:30',
            'Jane Doe',
            '9876543210'
        );
        Test.stopTest();

        Appointment__c appt = [SELECT Status__c, Queue_Order__c FROM Appointment__c WHERE Id = :apptId];
        System.assertEquals('Booked', appt.Status__c);
        System.assertEquals(2, appt.Queue_Order__c, '17:30 is the third 15-minute slot after a 17:00 start (index 2)');
    }

    @isTest
    static void testBookAppointmentRejectsDoubleBooking() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Date apptDate = Date.today().addDays(1);
        TestDataFactory.createAppointment(doc.Id, apptDate, Time.newInstance(17, 0, 0, 0), 0, 'Booked');

        Test.startTest();
        Boolean threw = false;
        try {
            BookingService.bookAppointment(doc.Id, apptDate, '17:00', 'John Doe', '9998887777');
        } catch (QueueService.QueueException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected booking an already-taken slot to throw');
    }

    @isTest
    static void testBookAppointmentRejectsBlankPatientName() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Date apptDate = Date.today().addDays(1);

        Test.startTest();
        Boolean threw = false;
        try {
            BookingService.bookAppointment(doc.Id, apptDate, '17:00', '', '9998887777');
        } catch (QueueService.QueueException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected booking with a blank patient name to throw');
    }
}
