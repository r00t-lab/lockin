# kotlinx.serialization keeps the generated serializers reachable via reflection on the
# companion; without these rules Commitment silently fails to decode in release builds
# and every commitment disappears after an update. That bug is invisible in debug.
-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1> {
    static <1>$Companion Companion;
}
-if @kotlinx.serialization.Serializable class ** {
    static **$* *;
}
-keepclassmembers class <2>$<3> {
    kotlinx.serialization.KSerializer serializer(...);
}
-keepclasseswithmembers class ** {
    @kotlinx.serialization.Serializable <fields>;
}

# ML Kit bundled barcode model.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# RevenueCat ships its own consumer rules; this is belt and braces for the
# Billing Library proxy classes it talks to.
-keep class com.android.billingclient.** { *; }
-dontwarn com.revenuecat.purchases.**
