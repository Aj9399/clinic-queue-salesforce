/**
 * Apex Time does not round-trip reliably across the Aura/LWC wire boundary
 * when used directly as an @AuraEnabled property or method parameter type
 * (observed: inconsistent serialization on the way out, and action
 * parameter coercion rejecting values that match Apex's own JSON.serialize
 * output on the way in). Nothing in this app ever exposes a raw Time in an
 * @AuraEnabled signature -- always a plain "HH:mm" string, converted at the
 * boundary using these helpers.
 */
public class TimeUtils {
    public static String formatHHmm(Time t) {
        return String.valueOf(t.hour()).leftPad(2, '0') + ':' + String.valueOf(t.minute()).leftPad(2, '0');
    }

    public static Time parseHHmm(String hhmm) {
        List<String> parts = hhmm.split(':');
        return Time.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), 0, 0);
    }
}
