# 🔐 GitHub Secrets Setup Guide — Lifetime Stable Signing

এই guide-টা ফলো করে ৫টা GitHub Secret add করলেই — এরপর থেকে **প্রতিটা GitHub Actions build একই official keystore দিয়ে sign হবে**, আর কোনোদিন মোবাইলে "package conflicts with an existing package" error আসবে না।

---

## ⚡ সমস্যাটা কী ছিল

আগের workflow-এ একটা ভয়ানক bug ছিল — যদি `KEYSTORE_BASE64` secret set করা না থাকে, তবে সে **প্রতি build-এ নতুন random keystore বানিয়ে ফেলত**। ফলে:
- Build #1 → Key A দিয়ে sign → মোবাইলে install
- Build #2 → Key B দিয়ে sign → update করতে গেলে `package conflicts` ❌

নতুন workflow-এ এই fallback সরিয়ে দেওয়া হয়েছে। এখন নিয়ম — **সঠিক keystore না থাকলে build fail হবে, কখনো random key দিয়ে build হবে না।**

---

## 📋 যে ৫টা Secret বসাতে হবে

আপনার GitHub repo-তে যান:
**Settings → Secrets and variables → Actions → New repository secret**

নিচের ৫টা secret এক এক করে add করুন:

### Secret 1: `KEYSTORE_BASE64`
- **Value**: `KEYSTORE_BASE64.txt` file-এর পুরো content (এক লাইন)
- এই file-টা project root-এ আছে, এটা `.gitignore`-এ রয়েছে তাই কখনো GitHub-এ push হবে না
- local মেশিনে খুলে পুরো content copy করে এখানে paste করুন
- ⚠️ এটাই আপনার ** signing identity** — এটা হারালে আর কোনোদিন recover করা যাবে না

### Secret 2: `KEYSTORE_PASSWORD`
```
ExamVault2026!
```

### Secret 3: `KEY_PASSWORD`
```
ExamVault2026!
```

### Secret 4: `KEY_ALIAS`
```
examvault
```

### Secret 5: `EXPECTED_SHA1`
```
BA:56:A6:05:A0:D8:A3:E1:81:75:C7:33:98:31:74:EF:C4:71:6A:6E
```
এটা আপনার official keystore-এর SHA1 fingerprint। Workflow প্রতি বার এটা verify করবে — যদি কোনোভাবে ভুল keystore বসে যায়, build fail হয়ে যাবে (সেইফটি নেট)।

---

## 🚀 Secret বসানোর পর

এরপর থেকে যতবার `main` বা `master` branch-এ push হবে (অথবা আপনি manually "Run workflow" চালাবেন), workflow-টা:

1. ✅ Real keystore decode করবে GitHub Secret থেকে
2. ✅ SHA1 fingerprint verify করবে (safety net)
3. ✅ APK + AAB build করবে একই key দিয়ে
4. ✅ Built APK-টা আবার verify করবে যে সঠিক key দিয়ে sign হয়েছে
5. ✅ Version সহ artifact upload করবে (৯০ দিন থাকবে)

---

## 🛡️ কী কী guarantee পাচ্ছেন

| Guarantee | কীভাবে |
|-----------|--------|
| প্রতি build একই key দিয়ে sign হবে | `KEYSTORE_BASE64` secret থেকে decode |
| ভুল key বসলে build fail | `EXPECTED_SHA1` fingerprint check |
| Built APK সঠিক key দিয়ে sign হয়েছে কিনা | `apksigner verify` step |
| Random keystore দিয়ে build হবে না | Temp fallback সরানো হয়েছে |
| মোবাইলে update কাজ করবে | সব build একই SHA1 → update smoothly |

---

## 🧪 Verify করার উপায়

Build হওয়ার পর GitHub Actions-এর **Summary** page-এ দেখবেন:
```
============================================
  ExamVault Build Summary
============================================
Version : 1.18.0+22
SHA1    : BA:56:A6:05:A0:D8:A3:E1:81:75:C7:33:98:31:74:EF:C4:71:6A:6E
SHA256  : <apk hash>
APK     : examvault-1.18.0+22.apk
Status  : ✅ Signed with official keystore (updates work)
============================================
```

যদি SHA1 এইটা না হয় — তার মানে কিছু ভুল হয়েছে। Build log-এ `Verify Keystore Fingerprint` step fail হয়ে যাবে।

---

## ❓ FAQ

**প্রশ্ন: একবার secret বসানোর পর আবার কি বসাতে হবে?**
উত্তর: না। একবার বসালেই lifetime চলবে। যতবার code push করবেন, সব build এই একই key দিয়ে হবে।

**প্রশ্ন: যদি নতুন কম্পিউটার থেকে build করি?**
উত্তর: GitHub Actions থেকেই build করুন (সবচেয়ে নিরাপদ)। local এ build করতে চাইলে এই ৩টা file দরকার — `android/app/examvault-release.keystore`, `android/key.properties`, `KEYSTORE_BASE64.txt` — এগুলো safe জায়গায় backup রাখা আছে কিনা নিশ্চিত করুন।

**প্রশ্ন: কেউ আমার keystore চুরি করলে?**
উত্তর: যেহেতু keystore password আলাদা secret (`KEYSTORE_PASSWORD`), শুধু keystore থাকলেও কাজ হবে না। তবুও keystore file কখনো GitHub repo-এ commit করবেন না — `.gitignore`-এ ইতিমধ্যে রয়েছে।

**প্রশ্ন: ভবিষ্যতে keystore পাল্টাতে চাইলে?**
উত্তর: সেটা করবেন না যতক্ষণ না দরকার না কারণ — পাল্টালে সব existing user কে uninstall করে নতুন করে install করতে হবে। যদি সত্যিই দরকার হয়, নতুন keystore বানিয়ে `KEYSTORE_BASE64` আর `EXPECTED_SHA1` দুটোই update করতে হবে।
