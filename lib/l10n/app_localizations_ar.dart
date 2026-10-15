// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'دكان';

  @override
  String get setupTitle => 'الإعداد الأولي';

  @override
  String get baseCurrency => 'العملة الأساسية';

  @override
  String get currencyUsd => 'دولار (USD)';

  @override
  String get currencySyp => 'ليرة (SYP)';

  @override
  String get exchangeRateLabel => 'سعر الصرف (ليرة مقابل 1 دولار)';

  @override
  String get roundingStepLabel => 'تقريب أسعار البيع بالليرة للأعلى';

  @override
  String get noRounding => 'بدون تقريب';

  @override
  String get startUsing => 'ابدأ الاستخدام';

  @override
  String get invalidRate => 'أدخل سعر صرف صحيحاً أكبر من صفر';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get currentRate => 'سعر الصرف الحالي';

  @override
  String get updateRate => 'تحديث سعر الصرف';

  @override
  String get edit => 'تعديل';

  @override
  String get rateUpdated => 'تم تحديث سعر الصرف';

  @override
  String get largeChangeTitle => 'تغيّر كبير في السعر';

  @override
  String largeChangeMessage(String newRate, String oldRate) {
    return 'السعر الجديد ($newRate) يختلف كثيراً عن السعر الحالي ($oldRate). هل أنت متأكد؟';
  }

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get save => 'حفظ';

  @override
  String get showDualCurrency => 'عرض الأسعار بالعملتين';

  @override
  String get digitStyle => 'أسلوب الأرقام';

  @override
  String get digitsWestern => '0-9';

  @override
  String get digitsArabicIndic => '٠-٩';

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get homePlaceholder =>
      'الشاشات القادمة: المنتجات، نقطة البيع، الزبائن';

  @override
  String get homeDemoTitle => 'مثال على التحويل بسعر الصرف الحالي';

  @override
  String get products => 'المنتجات';

  @override
  String get categories => 'الفئات';

  @override
  String get lowStock => 'المخزون المنخفض';

  @override
  String get searchProducts => 'ابحث بالاسم أو الباركود';

  @override
  String get allCategories => 'الكل';

  @override
  String get uncategorized => 'بدون فئة';

  @override
  String get noProducts => 'لا توجد منتجات';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get editProduct => 'تعديل المنتج';

  @override
  String get productName => 'اسم المنتج';

  @override
  String get category => 'الفئة';

  @override
  String get barcode => 'الباركود';

  @override
  String get costPrice => 'سعر التكلفة';

  @override
  String get salePrice => 'سعر البيع';

  @override
  String get lowStockThresholdLabel => 'حد تنبيه المخزون (اختياري)';

  @override
  String get initialQuantity => 'الكمية الافتتاحية (اختياري)';

  @override
  String get adjustStock => 'تعديل المخزون';

  @override
  String get addStock => 'إضافة مخزون';

  @override
  String get reduceStock => 'إنقاص / تصحيح';

  @override
  String get quantityField => 'الكمية';

  @override
  String get note => 'ملاحظة (اختياري)';

  @override
  String currentQuantity(String qty) {
    return 'الكمية الحالية: $qty';
  }

  @override
  String quantityShort(String qty) {
    return 'الكمية: $qty';
  }

  @override
  String thresholdValue(String threshold) {
    return 'الحد: $threshold';
  }

  @override
  String get lowStockBadge => 'مخزون منخفض';

  @override
  String get deactivate => 'إخفاء المنتج';

  @override
  String get deactivateConfirm =>
      'سيختفي هذا المنتج من القوائم والبيع، وتبقى فواتيره القديمة كما هي.';

  @override
  String profitMargin(String percent) {
    return 'هامش الربح التقريبي: $percent';
  }

  @override
  String get newCategory => 'فئة جديدة';

  @override
  String get categoryName => 'اسم الفئة';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get delete => 'حذف';

  @override
  String get deleteCategoryConfirm => 'حذف هذه الفئة؟ ستصبح منتجاتها بدون فئة.';

  @override
  String get noCategories => 'لا توجد فئات';

  @override
  String get noLowStock => 'لا توجد منتجات منخفضة المخزون';

  @override
  String get errInvalidName => 'أدخل اسماً صحيحاً';

  @override
  String get errInvalidPrice => 'أدخل سعراً صحيحاً';

  @override
  String get errInvalidQuantity => 'أدخل كمية صحيحة';

  @override
  String get errDuplicateBarcode => 'هذا الباركود مستخدم لمنتج آخر';

  @override
  String get errDuplicateCategory => 'اسم الفئة موجود مسبقاً';

  @override
  String get errNegativeStock => 'لا يمكن أن تصبح الكمية أقل من صفر';

  @override
  String get errNotFound => 'العنصر غير موجود';

  @override
  String get scanBarcode => 'مسح الباركود';

  @override
  String get scanHint => 'وجّه الكاميرا نحو الباركود';

  @override
  String get enterManually => 'إدخال يدوي';

  @override
  String get torch => 'الفلاش';

  @override
  String get switchCamera => 'تبديل الكاميرا';

  @override
  String get cameraPermissionDenied =>
      'لم يُسمح للتطبيق باستخدام الكاميرا. فعّل صلاحية الكاميرا من إعدادات الجهاز ثم أعد المحاولة، أو أدخل الباركود يدوياً.';

  @override
  String get cameraUnavailable =>
      'الكاميرا غير متوفرة على هذا الجهاز. أدخل الباركود يدوياً.';

  @override
  String get cameraError => 'تعذّر تشغيل الكاميرا. أدخل الباركود يدوياً.';

  @override
  String barcodeUsedBy(String name) {
    return 'هذا الباركود مسجّل للمنتج: $name';
  }

  @override
  String barcodeUsedByHidden(String name) {
    return 'هذا الباركود محجوز لمنتج مخفي: $name';
  }

  @override
  String get openProduct => 'فتح المنتج';

  @override
  String get pos => 'نقطة البيع';

  @override
  String get salesHistory => 'سجل المبيعات';

  @override
  String get searchOrScan => 'ابحث بالاسم أو امسح الباركود';

  @override
  String get cartEmpty => 'السلة فارغة';

  @override
  String get clearCart => 'تفريغ السلة';

  @override
  String get clearCartConfirm => 'تفريغ السلة من كل المنتجات؟';

  @override
  String scanAdded(String name) {
    return 'أُضيف: $name';
  }

  @override
  String scanNotFound(String code) {
    return 'لا يوجد منتج بهذا الباركود: $code';
  }

  @override
  String get continuousScanHint => 'امسح المنتجات تباعاً، ثم ارجع لإتمام البيع';

  @override
  String get quantityEdit => 'تعديل الكمية';

  @override
  String get setDiscount => 'تحديد الخصم';

  @override
  String get discount => 'الخصم';

  @override
  String get subtotal => 'المجموع';

  @override
  String get total => 'الإجمالي';

  @override
  String get invoiceCurrency => 'عملة الفاتورة';

  @override
  String get checkout => 'إتمام البيع';

  @override
  String get exceedsStock => 'الكمية أكبر من المتوفر في المخزون';

  @override
  String get exceedsStockWarning =>
      'بعض المنتجات تتجاوز الكمية المتوفرة في المخزون، وسيصبح مخزونها بالسالب. هل تريد المتابعة؟';

  @override
  String get received => 'المبلغ المستلم';

  @override
  String get receivedLessThanTotal => 'المبلغ المستلم أقل من الإجمالي';

  @override
  String get change => 'الباقي';

  @override
  String get confirmSale => 'تأكيد البيع';

  @override
  String get saleDone => 'تمت عملية البيع';

  @override
  String invoiceNumberLabel(String number) {
    return 'فاتورة رقم $number';
  }

  @override
  String get newInvoice => 'فاتورة جديدة';

  @override
  String get invoiceDetails => 'تفاصيل الفاتورة';

  @override
  String get today => 'اليوم';

  @override
  String salesCount(String count) {
    return 'عدد الفواتير: $count';
  }

  @override
  String get totalSalesBase => 'إجمالي المبيعات (بالعملة الأساسية)';

  @override
  String get profit => 'الربح';

  @override
  String get cost => 'التكلفة';

  @override
  String get noInvoices => 'لا توجد فواتير في هذا اليوم';

  @override
  String get invoiceVoided => 'ملغاة';

  @override
  String get paymentCash => 'نقدي';

  @override
  String get paymentCredit => 'آجل';

  @override
  String get payment => 'الدفع';

  @override
  String get voidInvoice => 'إلغاء الفاتورة';

  @override
  String get voidConfirm =>
      'سيتم إلغاء الفاتورة وإرجاع الكميات إلى المخزون. لا يمكن التراجع عن ذلك.';

  @override
  String get voidDone => 'تم إلغاء الفاتورة';

  @override
  String get date => 'التاريخ';

  @override
  String get exchangeRateUsed => 'سعر الصرف المستخدم';

  @override
  String get storeName => 'اسم المتجر';

  @override
  String get allowNegativeStock => 'السماح بالبيع بأكثر من المتوفر';

  @override
  String get errEmptyCart => 'السلة فارغة';

  @override
  String get errInvalidAmount => 'المبلغ غير صحيح';

  @override
  String get errInsufficientStock =>
      'الكمية المطلوبة أكبر من المتوفر في المخزون';

  @override
  String get errAlreadyVoided => 'هذه الفاتورة ملغاة مسبقاً';

  @override
  String get errCustomerRequired => 'اختر زبوناً للبيع الآجل';

  @override
  String get customers => 'الزبائن';

  @override
  String get addCustomer => 'إضافة زبون';

  @override
  String get editCustomer => 'تعديل الزبون';

  @override
  String get customerName => 'اسم الزبون';

  @override
  String get phone => 'الهاتف';

  @override
  String get notes => 'ملاحظات';

  @override
  String get searchCustomers => 'ابحث بالاسم أو الهاتف';

  @override
  String get onlyWithDebt => 'من عليهم دين فقط';

  @override
  String get sortByName => 'الفرز بالاسم';

  @override
  String get sortByDebt => 'الفرز بأعلى دين';

  @override
  String get noCustomers => 'لا يوجد زبائن';

  @override
  String get totalDebts => 'إجمالي الديون المستحقة';

  @override
  String customersWithDebt(String count) {
    return 'عدد المدينين: $count';
  }

  @override
  String get debtEquivalent => 'ما يعادلها بالعملة الأساسية بسعر الصرف الحالي';

  @override
  String get balance => 'الرصيد';

  @override
  String get owes => 'عليه';

  @override
  String get creditInFavor => 'رصيد للزبون';

  @override
  String get noDebt => 'لا دين';

  @override
  String get recordPayment => 'تسجيل دفعة';

  @override
  String get copyStatement => 'نسخ ملخص الرصيد';

  @override
  String get statementCopied => 'تم نسخ ملخص الرصيد';

  @override
  String statementHeader(String name) {
    return 'كشف حساب الزبون: $name';
  }

  @override
  String statementDate(String date) {
    return 'التاريخ: $date';
  }

  @override
  String get statementOwed => 'المبلغ المستحق';

  @override
  String get statementCredit => 'رصيد لصالح الزبون';

  @override
  String get statementSettled => 'لا يوجد دين مستحق.';

  @override
  String ledgerInvoice(String number) {
    return 'فاتورة $number';
  }

  @override
  String get ledgerPayment => 'دفعة';

  @override
  String ledgerPaidIn(String amount) {
    return 'دُفع: $amount';
  }

  @override
  String get noEntries => 'لا توجد حركات بعد';

  @override
  String get paidNow => 'المدفوع الآن';

  @override
  String get remainingDebt => 'الدين المتبقي';

  @override
  String get customerLabel => 'الزبون';

  @override
  String get chooseCustomer => 'اختر الزبون';

  @override
  String get newCustomer => 'زبون جديد';

  @override
  String get debtAtSale => 'الدين وقت البيع';

  @override
  String get voidCreditNote =>
      'هذه فاتورة آجلة: سيتغير رصيد الزبون بعد إلغائها، وقد يصبح له رصيد إن كان سدّد منها.';

  @override
  String get payInCurrency => 'عملة الدفع';

  @override
  String get settleDebtIn => 'سداد الدين بعملة';

  @override
  String get debtLabel => 'الدين';

  @override
  String get paymentAmount => 'المبلغ المدفوع';

  @override
  String appliedAmountLabel(String amount) {
    return 'المخصوم من الدين: $amount';
  }

  @override
  String balanceAfter(String amount) {
    return 'الرصيد بعد الدفعة: $amount';
  }

  @override
  String get settleAll => 'سداد كامل';

  @override
  String get voidPayment => 'إلغاء الدفعة';

  @override
  String get voidPaymentConfirm =>
      'سيُلغى تسجيل هذه الدفعة ويعود الدين كما كان. تبقى الدفعة ظاهرة في الكشف مشطوبة.';

  @override
  String get paymentVoided => 'تم إلغاء الدفعة';

  @override
  String get hideCustomer => 'إخفاء الزبون';

  @override
  String get hideCustomerConfirm =>
      'سيختفي هذا الزبون من القوائم، وتبقى فواتيره القديمة.';

  @override
  String get errCustomerHasDebt => 'لا يمكن إخفاء زبون عليه دين أو له رصيد';

  @override
  String get errPaymentExceedsDebt => 'المبلغ أكبر من الدين المتبقي';

  @override
  String get errNoDebt => 'لا يوجد دين بهذه العملة على الزبون';
}
