# Tivan ONT Bootstrapper iOS

این نسخه برای تست داخلی تیوان ساخته شده و فقط روی ONTهایی استفاده شود که مجوز پیکربندی آن‌ها را دارید.

## هدف برنامه

نسخه iOS تلاش می‌کند رفتار ابزار ویندوزی `Tivan-ONT-Bootstrapper-v1.0.5` را در حالت **ONT Direct** پیاده کند. در این مدل بخش Switch Mode، تغییر IP کارت شبکه ویندوز، Cisco/Switch و PowerShell وجود ندارد.

## تنظیمات ثابت داخل برنامه

### Web Login

```text
telecomadmin / admintelecom
```

### WAN پیش‌فرض

```text
Connection Type: PPPoE
PPPoE Username: yaraacs
PPPoE Password: yaraacs
VLAN ID: 800
Service Type: TR069_VOIP_INTERNET
LAN/WLAN Binding: LAN1..LAN8 و SSID1..SSID8
```

### ACS / TR-069

```text
ACS URL: https://yaraacs.tci.ir
ACS Username: yaraacs
ACS Password: yaraacs
ACS Inform Interval: 30
```

### Telnet

برنامه بعد از Web Provisioning این Credentialها را تست می‌کند:

```text
root / admin
root / adminHW
```

و سپس این دستورات را اجرا می‌کند:

```sh
su
shell
cd /mnt/jffs2
cp -f hw_ctree.xml hw_default_ctree.xml
chmod 644 hw_default_ctree.xml
sync
cmp /mnt/jffs2/hw_ctree.xml /mnt/jffs2/hw_default_ctree.xml
echo $?
```

## نکته‌های مهم تست

1. آیفون باید به WiFi/LAN همان ONT وصل باشد.
2. وقتی iOS سؤال Local Network را نشان داد، حتماً Allow بزنید.
3. برنامه اول `192.168.100.1` و سپس چند Gateway رایج را تست می‌کند.
4. این نسخه از `WKWebView` و JavaScript Automation برای صفحات Huawei استفاده می‌کند.
5. برای بعضی Firmwareها ممکن است ID/نام فیلدهای Huawei کمی فرق کند. در این حالت Log برنامه را Export کنید تا Selector اصلاح شود.
6. گزینه «پاک‌سازی WAN/ACS تکراری» فقط برای موارد تکراری مرتبط با `yaraacs`، `VLAN 800` یا `TR069` طراحی شده و قرار نیست سرویس‌های بی‌ربط را حذف کند.

## ساخت IPA با GitHub Actions

1. محتویات همین پوشه را در ریشه Repository آپلود کنید.
2. پوشه `.github` هم باید آپلود شود.
3. وارد تب **Actions** شوید.
4. گردش‌کار **Build unsigned IPA** را اجرا کنید.
5. پس از موفقیت، Artifact با نام زیر دانلود می‌شود:

```text
TivanONTBootstrapper-unsigned-ipa
```

داخل ZIP دانلودی فایل زیر است:

```text
TivanONTBootstrapper-unsigned.ipa
```

## نصب با 3uTools

1. فایل IPA unsigned را در 3uTools امضا کنید.
2. فایل امضاشده را از بخش Apps → Import & Install IPA نصب کنید.
3. در صورت نیاز Developer Mode و Trust پروفایل را فعال کنید.

## محدودیت

این نسخه پروژه کامل و یک‌جای iOS است، اما چون به فرم‌های Web UI مختلف Huawei وابسته است، اولین تست واقعی روی ONT ممکن است نیاز به اصلاح Selector داشته باشد. Log برنامه برای همین داخل UI قرار داده شده است.
