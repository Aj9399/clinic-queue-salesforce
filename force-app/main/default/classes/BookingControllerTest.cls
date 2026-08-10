@isTest
private class BookingControllerTest {
    @TestSetup
    static void setup() {
        TestDataFactory.createDoctor('Dr. Test');
    }

    @isTest
    static void testGetDoctorsReturnsSeededDoctor() {
        Test.startTest();
        List<Doctor__c> doctors = BookingController.getDoctors();
        Test.stopTest();

        System.assertEquals(1, doctors.size());
    }

    @isTest
    static void testGetAvailableSlotsReturnsFullGridWhenNoBookings() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];

        Test.startTest();
        List<BookingService.SlotOption> slots = BookingController.getAvailableSlots(doc.Id, Date.today().addDays(1));
        Test.stopTest();

        System.assertEquals(16, slots.size());
    }

    @isTest
    static void testBookAppointmentHappyPath() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];

        Test.startTest();
        Id apptId = BookingController.bookAppointment(
            doc.Id,
            Date.today().addDays(1),
            Time.newInstance(17, 0, 0, 0),
            'Jane Doe',
            '9876543210'
        );
        Test.stopTest();

        System.assertNotEquals(null, apptId);
    }

    @isTest
    static void testBookAppointmentThrowsAuraHandledExceptionOnDoubleBooking() {
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Date apptDate = Date.today().addDays(1);
        TestDataFactory.createAppointment(doc.Id, apptDate, Time.newInstance(17, 0, 0, 0), 0, 'Booked');

        Test.startTest();
        Boolean threw = false;
        try {
            BookingController.bookAppointment(doc.Id, apptDate, Time.newInstance(17, 0, 0, 0), 'John', '9990001111');
        } catch (AuraHandledException e) {
            threw = true;
            System.assertNotEquals(null, e.getMessage(), 'AuraHandledException message must survive the client boundary');
        }
        Test.stopTest();

        System.assert(threw);
    }
}
