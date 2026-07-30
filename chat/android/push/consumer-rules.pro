# 厂商推送 SDK 的混淆规则。作为 consumerProguardFiles 自动传递给 app 模块，
# app 开了 minifyEnabled，缺这些规则会导致 SDK 反射失败、收不到推送。

-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# 本模块的 receiver / service 由 manifest 引用，且厂商 SDK 会反射构造
-keep class cn.wildfirechat.push.** { *; }

# 华为
-dontwarn com.huawei.**
-keep class com.hianalytics.android.**{*;}
-keep class com.huawei.updatesdk.**{*;}
-keep class com.huawei.hms.**{*;}
-keep class com.huawei.agconnect.**{*;}

# 荣耀
-dontwarn com.hihonor.**
-keep class com.hihonor.push.**{*;}

# 小米
-dontwarn com.xiaomi.push.**
-keep class com.xiaomi.push.** { *; }
-keep class com.xiaomi.mipush.sdk.** { *; }

# vivo
-dontwarn com.vivo.push.**
-keep class com.vivo.push.**{*; }
-keep class com.vivo.vms.**{*; }

# OPPO
-dontwarn com.coloros.mcsdk.**
-keep class com.coloros.mcsdk.** { *; }
-dontwarn com.heytap.**
-keep class com.heytap.** { *; }
-dontwarn com.mcs.**
-keep class com.mcs.** { *; }

# FCM
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
