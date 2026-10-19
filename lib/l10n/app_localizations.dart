import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'دكان'**
  String get appTitle;

  /// No description provided for @setupTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعداد الأولي'**
  String get setupTitle;

  /// No description provided for @baseCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة الأساسية'**
  String get baseCurrency;

  /// No description provided for @currencyUsd.
  ///
  /// In ar, this message translates to:
  /// **'دولار (USD)'**
  String get currencyUsd;

  /// No description provided for @currencySyp.
  ///
  /// In ar, this message translates to:
  /// **'ليرة (SYP)'**
  String get currencySyp;

  /// No description provided for @exchangeRateLabel.
  ///
  /// In ar, this message translates to:
  /// **'سعر الصرف (ليرة مقابل 1 دولار)'**
  String get exchangeRateLabel;

  /// No description provided for @roundingStepLabel.
  ///
  /// In ar, this message translates to:
  /// **'تقريب أسعار البيع بالليرة للأعلى'**
  String get roundingStepLabel;

  /// No description provided for @noRounding.
  ///
  /// In ar, this message translates to:
  /// **'بدون تقريب'**
  String get noRounding;

  /// No description provided for @startUsing.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الاستخدام'**
  String get startUsing;

  /// No description provided for @invalidRate.
  ///
  /// In ar, this message translates to:
  /// **'أدخل سعر صرف صحيحاً أكبر من صفر'**
  String get invalidRate;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @currentRate.
  ///
  /// In ar, this message translates to:
  /// **'سعر الصرف الحالي'**
  String get currentRate;

  /// No description provided for @updateRate.
  ///
  /// In ar, this message translates to:
  /// **'تحديث سعر الصرف'**
  String get updateRate;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @rateUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث سعر الصرف'**
  String get rateUpdated;

  /// No description provided for @largeChangeTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر كبير في السعر'**
  String get largeChangeTitle;

  /// No description provided for @largeChangeMessage.
  ///
  /// In ar, this message translates to:
  /// **'السعر الجديد ({newRate}) يختلف كثيراً عن السعر الحالي ({oldRate}). هل أنت متأكد؟'**
  String largeChangeMessage(String newRate, String oldRate);

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @showDualCurrency.
  ///
  /// In ar, this message translates to:
  /// **'عرض الأسعار بالعملتين'**
  String get showDualCurrency;

  /// No description provided for @digitStyle.
  ///
  /// In ar, this message translates to:
  /// **'أسلوب الأرقام'**
  String get digitStyle;

  /// No description provided for @digitsWestern.
  ///
  /// In ar, this message translates to:
  /// **'0-9'**
  String get digitsWestern;

  /// No description provided for @digitsArabicIndic.
  ///
  /// In ar, this message translates to:
  /// **'٠-٩'**
  String get digitsArabicIndic;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @languageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @homePlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'الشاشات القادمة: المنتجات، نقطة البيع، الزبائن'**
  String get homePlaceholder;

  /// No description provided for @homeDemoTitle.
  ///
  /// In ar, this message translates to:
  /// **'مثال على التحويل بسعر الصرف الحالي'**
  String get homeDemoTitle;

  /// No description provided for @products.
  ///
  /// In ar, this message translates to:
  /// **'المنتجات'**
  String get products;

  /// No description provided for @categories.
  ///
  /// In ar, this message translates to:
  /// **'الفئات'**
  String get categories;

  /// No description provided for @lowStock.
  ///
  /// In ar, this message translates to:
  /// **'المخزون المنخفض'**
  String get lowStock;

  /// No description provided for @searchProducts.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو الباركود'**
  String get searchProducts;

  /// No description provided for @allCategories.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get allCategories;

  /// No description provided for @uncategorized.
  ///
  /// In ar, this message translates to:
  /// **'بدون فئة'**
  String get uncategorized;

  /// No description provided for @noProducts.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منتجات'**
  String get noProducts;

  /// No description provided for @addProduct.
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتج'**
  String get addProduct;

  /// No description provided for @editProduct.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المنتج'**
  String get editProduct;

  /// No description provided for @productName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المنتج'**
  String get productName;

  /// No description provided for @category.
  ///
  /// In ar, this message translates to:
  /// **'الفئة'**
  String get category;

  /// No description provided for @barcode.
  ///
  /// In ar, this message translates to:
  /// **'الباركود'**
  String get barcode;

  /// No description provided for @costPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر التكلفة'**
  String get costPrice;

  /// No description provided for @salePrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر البيع'**
  String get salePrice;

  /// No description provided for @lowStockThresholdLabel.
  ///
  /// In ar, this message translates to:
  /// **'حد تنبيه المخزون (اختياري)'**
  String get lowStockThresholdLabel;

  /// No description provided for @initialQuantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية الافتتاحية (اختياري)'**
  String get initialQuantity;

  /// No description provided for @adjustStock.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المخزون'**
  String get adjustStock;

  /// No description provided for @addStock.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مخزون'**
  String get addStock;

  /// No description provided for @reduceStock.
  ///
  /// In ar, this message translates to:
  /// **'إنقاص / تصحيح'**
  String get reduceStock;

  /// No description provided for @quantityField.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get quantityField;

  /// No description provided for @note.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة (اختياري)'**
  String get note;

  /// No description provided for @currentQuantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية الحالية: {qty}'**
  String currentQuantity(String qty);

  /// No description provided for @quantityShort.
  ///
  /// In ar, this message translates to:
  /// **'الكمية: {qty}'**
  String quantityShort(String qty);

  /// No description provided for @thresholdValue.
  ///
  /// In ar, this message translates to:
  /// **'الحد: {threshold}'**
  String thresholdValue(String threshold);

  /// No description provided for @lowStockBadge.
  ///
  /// In ar, this message translates to:
  /// **'مخزون منخفض'**
  String get lowStockBadge;

  /// No description provided for @deactivate.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء المنتج'**
  String get deactivate;

  /// No description provided for @deactivateConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيختفي هذا المنتج من القوائم والبيع، وتبقى فواتيره القديمة كما هي.'**
  String get deactivateConfirm;

  /// No description provided for @profitMargin.
  ///
  /// In ar, this message translates to:
  /// **'هامش الربح التقريبي: {percent}'**
  String profitMargin(String percent);

  /// No description provided for @newCategory.
  ///
  /// In ar, this message translates to:
  /// **'فئة جديدة'**
  String get newCategory;

  /// No description provided for @categoryName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الفئة'**
  String get categoryName;

  /// No description provided for @rename.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تسمية'**
  String get rename;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @deleteCategoryConfirm.
  ///
  /// In ar, this message translates to:
  /// **'حذف هذه الفئة؟ ستصبح منتجاتها بدون فئة.'**
  String get deleteCategoryConfirm;

  /// No description provided for @noCategories.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فئات'**
  String get noCategories;

  /// No description provided for @noLowStock.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد منتجات منخفضة المخزون'**
  String get noLowStock;

  /// No description provided for @errInvalidName.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسماً صحيحاً'**
  String get errInvalidName;

  /// No description provided for @errInvalidPrice.
  ///
  /// In ar, this message translates to:
  /// **'أدخل سعراً صحيحاً'**
  String get errInvalidPrice;

  /// No description provided for @errInvalidQuantity.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كمية صحيحة'**
  String get errInvalidQuantity;

  /// No description provided for @errDuplicateBarcode.
  ///
  /// In ar, this message translates to:
  /// **'هذا الباركود مستخدم لمنتج آخر'**
  String get errDuplicateBarcode;

  /// No description provided for @errDuplicateCategory.
  ///
  /// In ar, this message translates to:
  /// **'اسم الفئة موجود مسبقاً'**
  String get errDuplicateCategory;

  /// No description provided for @errNegativeStock.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن أن تصبح الكمية أقل من صفر'**
  String get errNegativeStock;

  /// No description provided for @errNotFound.
  ///
  /// In ar, this message translates to:
  /// **'العنصر غير موجود'**
  String get errNotFound;

  /// No description provided for @scanBarcode.
  ///
  /// In ar, this message translates to:
  /// **'مسح الباركود'**
  String get scanBarcode;

  /// No description provided for @scanHint.
  ///
  /// In ar, this message translates to:
  /// **'وجّه الكاميرا نحو الباركود'**
  String get scanHint;

  /// No description provided for @enterManually.
  ///
  /// In ar, this message translates to:
  /// **'إدخال يدوي'**
  String get enterManually;

  /// No description provided for @torch.
  ///
  /// In ar, this message translates to:
  /// **'الفلاش'**
  String get torch;

  /// No description provided for @switchCamera.
  ///
  /// In ar, this message translates to:
  /// **'تبديل الكاميرا'**
  String get switchCamera;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'لم يُسمح للتطبيق باستخدام الكاميرا. فعّل صلاحية الكاميرا من إعدادات الجهاز ثم أعد المحاولة، أو أدخل الباركود يدوياً.'**
  String get cameraPermissionDenied;

  /// No description provided for @cameraUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا غير متوفرة على هذا الجهاز. أدخل الباركود يدوياً.'**
  String get cameraUnavailable;

  /// No description provided for @cameraError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل الكاميرا. أدخل الباركود يدوياً.'**
  String get cameraError;

  /// No description provided for @barcodeUsedBy.
  ///
  /// In ar, this message translates to:
  /// **'هذا الباركود مسجّل للمنتج: {name}'**
  String barcodeUsedBy(String name);

  /// No description provided for @barcodeUsedByHidden.
  ///
  /// In ar, this message translates to:
  /// **'هذا الباركود محجوز لمنتج مخفي: {name}'**
  String barcodeUsedByHidden(String name);

  /// No description provided for @openProduct.
  ///
  /// In ar, this message translates to:
  /// **'فتح المنتج'**
  String get openProduct;

  /// No description provided for @pos.
  ///
  /// In ar, this message translates to:
  /// **'نقطة البيع'**
  String get pos;

  /// No description provided for @salesHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل المبيعات'**
  String get salesHistory;

  /// No description provided for @searchOrScan.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو امسح الباركود'**
  String get searchOrScan;

  /// No description provided for @cartEmpty.
  ///
  /// In ar, this message translates to:
  /// **'السلة فارغة'**
  String get cartEmpty;

  /// No description provided for @clearCart.
  ///
  /// In ar, this message translates to:
  /// **'تفريغ السلة'**
  String get clearCart;

  /// No description provided for @clearCartConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تفريغ السلة من كل المنتجات؟'**
  String get clearCartConfirm;

  /// No description provided for @scanAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف: {name}'**
  String scanAdded(String name);

  /// No description provided for @scanNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد منتج بهذا الباركود: {code}'**
  String scanNotFound(String code);

  /// No description provided for @continuousScanHint.
  ///
  /// In ar, this message translates to:
  /// **'امسح المنتجات تباعاً، ثم ارجع لإتمام البيع'**
  String get continuousScanHint;

  /// No description provided for @quantityEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الكمية'**
  String get quantityEdit;

  /// No description provided for @setDiscount.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الخصم'**
  String get setDiscount;

  /// No description provided for @discount.
  ///
  /// In ar, this message translates to:
  /// **'الخصم'**
  String get discount;

  /// No description provided for @subtotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع'**
  String get subtotal;

  /// No description provided for @total.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get total;

  /// No description provided for @invoiceCurrency.
  ///
  /// In ar, this message translates to:
  /// **'عملة الفاتورة'**
  String get invoiceCurrency;

  /// No description provided for @checkout.
  ///
  /// In ar, this message translates to:
  /// **'إتمام البيع'**
  String get checkout;

  /// No description provided for @exceedsStock.
  ///
  /// In ar, this message translates to:
  /// **'الكمية أكبر من المتوفر في المخزون'**
  String get exceedsStock;

  /// No description provided for @exceedsStockWarning.
  ///
  /// In ar, this message translates to:
  /// **'بعض المنتجات تتجاوز الكمية المتوفرة في المخزون، وسيصبح مخزونها بالسالب. هل تريد المتابعة؟'**
  String get exceedsStockWarning;

  /// No description provided for @received.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المستلم'**
  String get received;

  /// No description provided for @receivedLessThanTotal.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المستلم أقل من الإجمالي'**
  String get receivedLessThanTotal;

  /// No description provided for @change.
  ///
  /// In ar, this message translates to:
  /// **'الباقي'**
  String get change;

  /// No description provided for @confirmSale.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد البيع'**
  String get confirmSale;

  /// No description provided for @saleDone.
  ///
  /// In ar, this message translates to:
  /// **'تمت عملية البيع'**
  String get saleDone;

  /// No description provided for @invoiceNumberLabel.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة رقم {number}'**
  String invoiceNumberLabel(String number);

  /// No description provided for @newInvoice.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة جديدة'**
  String get newInvoice;

  /// No description provided for @invoiceDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الفاتورة'**
  String get invoiceDetails;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @salesCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الفواتير: {count}'**
  String salesCount(String count);

  /// No description provided for @totalSalesBase.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المبيعات (بالعملة الأساسية)'**
  String get totalSalesBase;

  /// No description provided for @profit.
  ///
  /// In ar, this message translates to:
  /// **'الربح'**
  String get profit;

  /// No description provided for @cost.
  ///
  /// In ar, this message translates to:
  /// **'التكلفة'**
  String get cost;

  /// No description provided for @noInvoices.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فواتير في هذا اليوم'**
  String get noInvoices;

  /// No description provided for @invoiceVoided.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get invoiceVoided;

  /// No description provided for @paymentCash.
  ///
  /// In ar, this message translates to:
  /// **'نقدي'**
  String get paymentCash;

  /// No description provided for @paymentCredit.
  ///
  /// In ar, this message translates to:
  /// **'آجل'**
  String get paymentCredit;

  /// No description provided for @payment.
  ///
  /// In ar, this message translates to:
  /// **'الدفع'**
  String get payment;

  /// No description provided for @voidInvoice.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الفاتورة'**
  String get voidInvoice;

  /// No description provided for @voidConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إلغاء الفاتورة وإرجاع الكميات إلى المخزون. لا يمكن التراجع عن ذلك.'**
  String get voidConfirm;

  /// No description provided for @voidDone.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الفاتورة'**
  String get voidDone;

  /// No description provided for @date.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get date;

  /// No description provided for @exchangeRateUsed.
  ///
  /// In ar, this message translates to:
  /// **'سعر الصرف المستخدم'**
  String get exchangeRateUsed;

  /// No description provided for @storeName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المتجر'**
  String get storeName;

  /// No description provided for @allowNegativeStock.
  ///
  /// In ar, this message translates to:
  /// **'السماح بالبيع بأكثر من المتوفر'**
  String get allowNegativeStock;

  /// No description provided for @errEmptyCart.
  ///
  /// In ar, this message translates to:
  /// **'السلة فارغة'**
  String get errEmptyCart;

  /// No description provided for @errInvalidAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ غير صحيح'**
  String get errInvalidAmount;

  /// No description provided for @errInsufficientStock.
  ///
  /// In ar, this message translates to:
  /// **'الكمية المطلوبة أكبر من المتوفر في المخزون'**
  String get errInsufficientStock;

  /// No description provided for @errAlreadyVoided.
  ///
  /// In ar, this message translates to:
  /// **'هذه الفاتورة ملغاة مسبقاً'**
  String get errAlreadyVoided;

  /// No description provided for @errCustomerRequired.
  ///
  /// In ar, this message translates to:
  /// **'اختر زبوناً للبيع الآجل'**
  String get errCustomerRequired;

  /// No description provided for @customers.
  ///
  /// In ar, this message translates to:
  /// **'الزبائن'**
  String get customers;

  /// No description provided for @addCustomer.
  ///
  /// In ar, this message translates to:
  /// **'إضافة زبون'**
  String get addCustomer;

  /// No description provided for @editCustomer.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الزبون'**
  String get editCustomer;

  /// No description provided for @customerName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الزبون'**
  String get customerName;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف'**
  String get phone;

  /// No description provided for @notes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get notes;

  /// No description provided for @searchCustomers.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو الهاتف'**
  String get searchCustomers;

  /// No description provided for @onlyWithDebt.
  ///
  /// In ar, this message translates to:
  /// **'من عليهم دين فقط'**
  String get onlyWithDebt;

  /// No description provided for @sortByName.
  ///
  /// In ar, this message translates to:
  /// **'الفرز بالاسم'**
  String get sortByName;

  /// No description provided for @sortByDebt.
  ///
  /// In ar, this message translates to:
  /// **'الفرز بأعلى دين'**
  String get sortByDebt;

  /// No description provided for @noCustomers.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد زبائن'**
  String get noCustomers;

  /// No description provided for @totalDebts.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الديون المستحقة'**
  String get totalDebts;

  /// No description provided for @customersWithDebt.
  ///
  /// In ar, this message translates to:
  /// **'عدد المدينين: {count}'**
  String customersWithDebt(String count);

  /// No description provided for @debtEquivalent.
  ///
  /// In ar, this message translates to:
  /// **'ما يعادلها بالعملة الأساسية بسعر الصرف الحالي'**
  String get debtEquivalent;

  /// No description provided for @balance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get balance;

  /// No description provided for @owes.
  ///
  /// In ar, this message translates to:
  /// **'عليه'**
  String get owes;

  /// No description provided for @creditInFavor.
  ///
  /// In ar, this message translates to:
  /// **'رصيد للزبون'**
  String get creditInFavor;

  /// No description provided for @noDebt.
  ///
  /// In ar, this message translates to:
  /// **'لا دين'**
  String get noDebt;

  /// No description provided for @recordPayment.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دفعة'**
  String get recordPayment;

  /// No description provided for @copyStatement.
  ///
  /// In ar, this message translates to:
  /// **'نسخ ملخص الرصيد'**
  String get copyStatement;

  /// No description provided for @statementCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ ملخص الرصيد'**
  String get statementCopied;

  /// No description provided for @statementHeader.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب الزبون: {name}'**
  String statementHeader(String name);

  /// No description provided for @statementDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ: {date}'**
  String statementDate(String date);

  /// No description provided for @statementOwed.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المستحق'**
  String get statementOwed;

  /// No description provided for @statementCredit.
  ///
  /// In ar, this message translates to:
  /// **'رصيد لصالح الزبون'**
  String get statementCredit;

  /// No description provided for @statementSettled.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد دين مستحق.'**
  String get statementSettled;

  /// No description provided for @ledgerInvoice.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة {number}'**
  String ledgerInvoice(String number);

  /// No description provided for @ledgerPayment.
  ///
  /// In ar, this message translates to:
  /// **'دفعة'**
  String get ledgerPayment;

  /// No description provided for @ledgerPaidIn.
  ///
  /// In ar, this message translates to:
  /// **'دُفع: {amount}'**
  String ledgerPaidIn(String amount);

  /// No description provided for @noEntries.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حركات بعد'**
  String get noEntries;

  /// No description provided for @paidNow.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع الآن'**
  String get paidNow;

  /// No description provided for @remainingDebt.
  ///
  /// In ar, this message translates to:
  /// **'الدين المتبقي'**
  String get remainingDebt;

  /// No description provided for @customerLabel.
  ///
  /// In ar, this message translates to:
  /// **'الزبون'**
  String get customerLabel;

  /// No description provided for @chooseCustomer.
  ///
  /// In ar, this message translates to:
  /// **'اختر الزبون'**
  String get chooseCustomer;

  /// No description provided for @newCustomer.
  ///
  /// In ar, this message translates to:
  /// **'زبون جديد'**
  String get newCustomer;

  /// No description provided for @debtAtSale.
  ///
  /// In ar, this message translates to:
  /// **'الدين وقت البيع'**
  String get debtAtSale;

  /// No description provided for @voidCreditNote.
  ///
  /// In ar, this message translates to:
  /// **'هذه فاتورة آجلة: سيتغير رصيد الزبون بعد إلغائها، وقد يصبح له رصيد إن كان سدّد منها.'**
  String get voidCreditNote;

  /// No description provided for @payInCurrency.
  ///
  /// In ar, this message translates to:
  /// **'عملة الدفع'**
  String get payInCurrency;

  /// No description provided for @settleDebtIn.
  ///
  /// In ar, this message translates to:
  /// **'سداد الدين بعملة'**
  String get settleDebtIn;

  /// No description provided for @debtLabel.
  ///
  /// In ar, this message translates to:
  /// **'الدين'**
  String get debtLabel;

  /// No description provided for @paymentAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المدفوع'**
  String get paymentAmount;

  /// No description provided for @appliedAmountLabel.
  ///
  /// In ar, this message translates to:
  /// **'المخصوم من الدين: {amount}'**
  String appliedAmountLabel(String amount);

  /// No description provided for @balanceAfter.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد بعد الدفعة: {amount}'**
  String balanceAfter(String amount);

  /// No description provided for @settleAll.
  ///
  /// In ar, this message translates to:
  /// **'سداد كامل'**
  String get settleAll;

  /// No description provided for @voidPayment.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الدفعة'**
  String get voidPayment;

  /// No description provided for @voidPaymentConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُلغى تسجيل هذه الدفعة ويعود الدين كما كان. تبقى الدفعة ظاهرة في الكشف مشطوبة.'**
  String get voidPaymentConfirm;

  /// No description provided for @paymentVoided.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الدفعة'**
  String get paymentVoided;

  /// No description provided for @hideCustomer.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الزبون'**
  String get hideCustomer;

  /// No description provided for @hideCustomerConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيختفي هذا الزبون من القوائم، وتبقى فواتيره القديمة.'**
  String get hideCustomerConfirm;

  /// No description provided for @errCustomerHasDebt.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إخفاء زبون عليه دين أو له رصيد'**
  String get errCustomerHasDebt;

  /// No description provided for @errPaymentExceedsDebt.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ أكبر من الدين المتبقي'**
  String get errPaymentExceedsDebt;

  /// No description provided for @errNoDebt.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد دين بهذه العملة على الزبون'**
  String get errNoDebt;

  /// No description provided for @suppliers.
  ///
  /// In ar, this message translates to:
  /// **'الموردون'**
  String get suppliers;

  /// No description provided for @addSupplier.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مورد'**
  String get addSupplier;

  /// No description provided for @editSupplier.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المورد'**
  String get editSupplier;

  /// No description provided for @supplierName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المورد'**
  String get supplierName;

  /// No description provided for @searchSuppliers.
  ///
  /// In ar, this message translates to:
  /// **'ابحث بالاسم أو الهاتف'**
  String get searchSuppliers;

  /// No description provided for @noSuppliers.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد موردون'**
  String get noSuppliers;

  /// No description provided for @newSupplier.
  ///
  /// In ar, this message translates to:
  /// **'مورد جديد'**
  String get newSupplier;

  /// No description provided for @hideSupplier.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء المورد'**
  String get hideSupplier;

  /// No description provided for @hideSupplierConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيختفي هذا المورد من القوائم، وتبقى فواتير شرائه القديمة.'**
  String get hideSupplierConfirm;

  /// No description provided for @supplierLabel.
  ///
  /// In ar, this message translates to:
  /// **'المورد'**
  String get supplierLabel;

  /// No description provided for @chooseSupplier.
  ///
  /// In ar, this message translates to:
  /// **'اختر المورد'**
  String get chooseSupplier;

  /// No description provided for @noSupplierSelected.
  ///
  /// In ar, this message translates to:
  /// **'بدون مورد محدد'**
  String get noSupplierSelected;

  /// No description provided for @totalPayables.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي ما علينا للموردين'**
  String get totalPayables;

  /// No description provided for @onlyWeOwe.
  ///
  /// In ar, this message translates to:
  /// **'من نحن مدينون لهم'**
  String get onlyWeOwe;

  /// No description provided for @advanceWithSupplier.
  ///
  /// In ar, this message translates to:
  /// **'رصيد لنا عند المورد'**
  String get advanceWithSupplier;

  /// No description provided for @noPayable.
  ///
  /// In ar, this message translates to:
  /// **'لا دين للمورد'**
  String get noPayable;

  /// No description provided for @weOwe.
  ///
  /// In ar, this message translates to:
  /// **'علينا'**
  String get weOwe;

  /// No description provided for @suppliersWithDebt.
  ///
  /// In ar, this message translates to:
  /// **'عدد الموردين الدائنين: {count}'**
  String suppliersWithDebt(String count);

  /// No description provided for @statementSupplierHeader.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب المورد: {name}'**
  String statementSupplierHeader(String name);

  /// No description provided for @statementWeOwe.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المستحق للمورد'**
  String get statementWeOwe;

  /// No description provided for @statementAdvance.
  ///
  /// In ar, this message translates to:
  /// **'رصيد لنا عند المورد'**
  String get statementAdvance;

  /// No description provided for @statementNoPayable.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد مبلغ مستحق للمورد.'**
  String get statementNoPayable;

  /// No description provided for @ledgerPurchase.
  ///
  /// In ar, this message translates to:
  /// **'شراء {number}'**
  String ledgerPurchase(String number);

  /// No description provided for @purchases.
  ///
  /// In ar, this message translates to:
  /// **'المشتريات'**
  String get purchases;

  /// No description provided for @newPurchase.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة شراء جديدة'**
  String get newPurchase;

  /// No description provided for @purchasesHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل المشتريات'**
  String get purchasesHistory;

  /// No description provided for @purchaseDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل فاتورة الشراء'**
  String get purchaseDetails;

  /// No description provided for @unitCostLabel.
  ///
  /// In ar, this message translates to:
  /// **'تكلفة الوحدة'**
  String get unitCostLabel;

  /// No description provided for @supplierInvoiceNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم فاتورة المورد (اختياري)'**
  String get supplierInvoiceNumber;

  /// No description provided for @purchaseDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الشراء'**
  String get purchaseDate;

  /// No description provided for @purchaseRate.
  ///
  /// In ar, this message translates to:
  /// **'سعر الصرف لهذه الفاتورة'**
  String get purchaseRate;

  /// No description provided for @updateCosts.
  ///
  /// In ar, this message translates to:
  /// **'تحديث تكلفة المنتجات'**
  String get updateCosts;

  /// No description provided for @updateCostsHint.
  ///
  /// In ar, this message translates to:
  /// **'تصبح تكلفة كل منتج = سعر الوحدة في هذه الفاتورة'**
  String get updateCostsHint;

  /// No description provided for @addItems.
  ///
  /// In ar, this message translates to:
  /// **'أضف أصنافاً بالبحث أو بمسح الباركود'**
  String get addItems;

  /// No description provided for @searchOrScanProduct.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن منتج أو امسح الباركود'**
  String get searchOrScanProduct;

  /// No description provided for @savePurchase.
  ///
  /// In ar, this message translates to:
  /// **'حفظ فاتورة الشراء'**
  String get savePurchase;

  /// No description provided for @purchaseSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ فاتورة الشراء'**
  String get purchaseSaved;

  /// No description provided for @continuousScanHintPurchase.
  ///
  /// In ar, this message translates to:
  /// **'امسح الأصناف تباعاً (وحدة لكل قراءة)، ثم ارجع'**
  String get continuousScanHintPurchase;

  /// No description provided for @discardPurchase.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الفاتورة الحالية؟'**
  String get discardPurchase;

  /// No description provided for @discardPurchaseConfirm.
  ///
  /// In ar, this message translates to:
  /// **'ستفقد الأصناف التي أضفتها.'**
  String get discardPurchaseConfirm;

  /// No description provided for @keepEditing.
  ///
  /// In ar, this message translates to:
  /// **'متابعة التحرير'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get discard;

  /// No description provided for @previousCostLabel.
  ///
  /// In ar, this message translates to:
  /// **'التكلفة السابقة: {cost}'**
  String previousCostLabel(String cost);

  /// No description provided for @costChange.
  ///
  /// In ar, this message translates to:
  /// **'التغيّر: {percent}'**
  String costChange(String percent);

  /// No description provided for @purchasesCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الفواتير: {count}'**
  String purchasesCount(String count);

  /// No description provided for @totalPurchasesBase.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المشتريات (بالعملة الأساسية)'**
  String get totalPurchasesBase;

  /// No description provided for @noPurchases.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد فواتير شراء في هذا اليوم'**
  String get noPurchases;

  /// No description provided for @voidPurchase.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء فاتورة الشراء'**
  String get voidPurchase;

  /// No description provided for @voidPurchaseConfirm.
  ///
  /// In ar, this message translates to:
  /// **'ستُنقَص كميات الفاتورة من المخزون (وقد يصبح المخزون بالسالب إن بيعت البضاعة). لن تُسترجع تكلفة المنتجات السابقة. لا يمكن التراجع عن ذلك.'**
  String get voidPurchaseConfirm;

  /// No description provided for @voidPurchaseCreditNote.
  ///
  /// In ar, this message translates to:
  /// **'هذه فاتورة آجلة: سيتغير رصيد المورد بعد إلغائها.'**
  String get voidPurchaseCreditNote;

  /// No description provided for @purchaseVoided.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء فاتورة الشراء'**
  String get purchaseVoided;

  /// No description provided for @payableAtPurchase.
  ///
  /// In ar, this message translates to:
  /// **'الدين للمورد وقت الشراء'**
  String get payableAtPurchase;

  /// No description provided for @errSupplierRequired.
  ///
  /// In ar, this message translates to:
  /// **'اختر مورداً للشراء الآجل'**
  String get errSupplierRequired;

  /// No description provided for @errSupplierHasDebt.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إخفاء مورد له أو علينا له رصيد'**
  String get errSupplierHasDebt;

  /// No description provided for @errNoPayable.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد دين للمورد بهذه العملة'**
  String get errNoPayable;

  /// No description provided for @errEmptyPurchase.
  ///
  /// In ar, this message translates to:
  /// **'أضف صنفاً واحداً على الأقل'**
  String get errEmptyPurchase;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
