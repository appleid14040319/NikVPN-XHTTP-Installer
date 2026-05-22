NikVPN XHTTP Installer
<div align="center"> <h1>🚀 NikVPN XHTTP Installer</h1> <p> <b>نصب خودکار VLESS + XHTTP + TLS پشت CDN فقط در چند دقیقه</b> </p> <p> اسکریپت حرفه‌ای و تمام‌خودکار برای راه‌اندازی <b>Xray</b>، <b>VLESS</b>، <b>XHTTP</b> و <b>3X-UI</b> همراه با SSL خودکار، مدیریت کاربران، محدودیت حجم، پنل تحت وب و مخفی‌سازی IP پشت CDN. </p> <br>










</div>
⚡ نصب سریع (Easy Install)
...bash
فقط این دستور را داخل ترمینال سرور اوبونتو اجرا کنید:

bash <(curl -fsSL https://raw.githubusercontent.com/nikvpn-iran/NikVPN-xhttp-installer/main/install.sh)


✨ امکانات

🚀 نصب کاملاً خودکار

🔒 مخفی شدن IP اصلی سرور پشت CDN

🌐 پشتیبانی از Vercel و Netlify

👥 ساخت چندین کانفیگ هم‌زمان

📊 محدودیت حجم برای هر کاربر

🖥️ پنل حرفه‌ای 3X-UI

🛠️ ابزار مدیریت nikvpn

🔄 تمدید خودکار SSL

🧪 تست کامل اتصال بعد از نصب

⚡ مناسب کاربران مبتدی و حرفه‌ای

🏗️ معماری پروژه
کلاینت (v2rayNG / v2rayN / Streisand)
                │
                ▼
      Vercel / Netlify CDN
                │
                ▼
     سرور شما (Xray + 3X-UI)
                │
                ▼
            اینترنت آزاد
📋 پیش‌نیازها

قبل از نصب، این موارد را آماده کنید:

مورد	توضیح
سرور Ubuntu	نسخه 20.04 یا بالاتر
دامنه یا ساب‌دامین	متصل به IP سرور
پورت‌های باز	80 و 443
ایمیل معتبر	برای SSL
توکن Vercel یا Netlify	برای ساخت Relay
🌐 تنظیم DNS

قبل از اجرای اسکریپت:

یک رکورد A بسازید:

Type	Name	Value
A	@ یا subdomain	IP سرور

مثال:

vpn.example.com -> 1.2.3.4

برای تست:

ping yourdomain.com

اگر IP سرور نمایش داده شد یعنی DNS درست تنظیم شده.

🔑 دریافت توکن‌ها
توکن Vercel

از این صفحه:

Vercel Token Settings

یک Token جدید بسازید.

توکن Netlify

از این صفحه:

Netlify Personal Access Tokens

یک Personal Access Token ایجاد کنید.

🚀 آموزش نصب مرحله‌به‌مرحله
1️⃣ انتخاب پلتفرم

بین این دو انتخاب کنید:

1) Vercel
2) Netlify

پیشنهاد:

✅ Vercel

2️⃣ وارد کردن دامنه

مثال:

vpn.example.com
3️⃣ وارد کردن ایمیل

مثال:

admin@example.com
4️⃣ تعداد کانفیگ‌ها

مثال:

5

یعنی ۵ کانفیگ مختلف ساخته می‌شود.

5️⃣ حجم هر کاربر

مثال:

10

یعنی:

10 گیگ برای هر کاربر

برای حجم نامحدود:

0
6️⃣ مسیر و پورت

اگر نمی‌دانید چیست فقط:

Enter

بزنید تا مقدار پیش‌فرض استفاده شود.

7️⃣ وارد کردن Token

توکن Vercel یا Netlify را Paste کنید.

8️⃣ نصب پنل

پیشنهاد:

YES

تا پنل 3X-UI نصب شود.

📦 خروجی نهایی

بعد از پایان نصب این موارد نمایش داده می‌شود:

✅ لینک تمام کانفیگ‌ها

✅ آدرس پنل

✅ نام کاربری و رمز عبور

✅ وضعیت SSL

✅ نتیجه تست اتصال

نمونه لینک:

vless://uuid@relay.vercel.app:443?security=tls&type=xhttp...
🖥️ پنل مدیریت

آدرس پنل:

https://yourdomain.com:2053

امکانات:

مدیریت کاربران

مشاهده مصرف

محدودیت حجم

تاریخ انقضا

مشاهده لاگ‌ها

تنظیمات Xray

🛠️ دستورات مدیریت

بعد از نصب دستور nikvpn فعال می‌شود.

دستورات:
nikvpn configs
nikvpn panel
nikvpn status
nikvpn restart
nikvpn logs
nikvpn help
📂 فایل‌های مهم
مسیر	توضیح
/etc/nikvpn/configs.txt	لینک کانفیگ‌ها
/etc/nikvpn/state.env	اطلاعات نصب
/usr/local/bin/nikvpn	ابزار مدیریت
/tmp/nikvpn-install.log	لاگ نصب
🔥 تنظیم فایروال

اگر فایروال فعال است:

ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 2053/tcp
ufw reload
⚠️ نکات مهم
کاربران Vercel

حتماً گزینه:

Deployment Protection

را غیرفعال کنید.

وگرنه خطای:

401 Unauthorized

دریافت می‌کنید.

مشکل SSL

اگر SSL صادر نشد:

DNS را بررسی کنید

پورت 80 باز باشد

چند دقیقه صبر کنید

🔧 عیب‌یابی
مشکل	راه‌حل
SSL صادر نشد	بررسی DNS و پورت 80
پنل باز نمی‌شود	باز کردن پورت 2053
اتصال برقرار نمی‌شود	ریستارت Xray
نصب ناموفق بود	بررسی لاگ نصب
🔄 مدیریت سرویس‌ها
ریستارت Xray
systemctl restart xray
ریستارت پنل
systemctl restart x-ui
وضعیت سرویس‌ها
systemctl status xray
systemctl status x-ui
📱 کلاینت‌های پیشنهادی
ویندوز

v2rayN

اندروید

v2rayNG

Nekobox

آیفون

Streisand

Shadowrocket

🙏 اعتبار پروژه

این پروژه بر پایه پروژه زیر توسعه داده شده:

XHTTP-Installer by avacocloud

تغییرات NikVPN:

ساخت چندکاربره

پنل 3X-UI

محدودیت حجم

ابزار مدیریت اختصاصی

رابط کاربری بهتر

نصب آسان‌تر

🤝 مشارکت

برای گزارش باگ یا ارسال Pull Request:

NikVPN GitHub Repository

📢 کامیونیتی
کانال تلگرام

NikVPN Channel

گروه تلگرام

NikVPN Group

⭐ حمایت از پروژه

اگر این پروژه برایتان مفید بود:

⭐ ریپو را Star کنید

🍴 پروژه را Fork کنید

🐛 باگ‌ها را گزارش دهید

💡 پیشنهاد بدهید

<div align="center">
❤️ Made with Love by NikVPN
</div>
