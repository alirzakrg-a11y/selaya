import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/di/providers.dart';
import '../../auth/data/auth_controller.dart';

/// Premium ürün ID'leri — Play Console'da AYNI ID'lerle oluşturulmalı:
/// monthly/yearly = abonelik (subscription), lifetime = tek seferlik (yönetilen ürün).
class PremiumIds {
  static const monthly = 'selaya_premium_monthly';
  static const yearly = 'selaya_premium_yearly';
  static const lifetime = 'selaya_premium_lifetime';
  static const all = <String>{monthly, yearly, lifetime};
}

class PurchaseState {
  final bool storeAvailable; // Play Billing erişilebilir mi
  final bool loading;
  final List<ProductDetails> products;
  final bool isPremium;
  final bool purchasePending;
  final String? error;

  const PurchaseState({
    this.storeAvailable = false,
    this.loading = true,
    this.products = const [],
    this.isPremium = false,
    this.purchasePending = false,
    this.error,
  });

  PurchaseState copyWith({
    bool? storeAvailable,
    bool? loading,
    List<ProductDetails>? products,
    bool? isPremium,
    bool? purchasePending,
    String? error,
  }) =>
      PurchaseState(
        storeAvailable: storeAvailable ?? this.storeAvailable,
        loading: loading ?? this.loading,
        products: products ?? this.products,
        isPremium: isPremium ?? this.isPremium,
        purchasePending: purchasePending ?? this.purchasePending,
        error: error, // transient — her durum değişiminde temizlenir
      );

  ProductDetails? byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Premium satın alma yöneticisi. Play Billing'i dinler; satın alma/geri yükleme
/// başarılı olunca [PrefKeys.isPremium]=true yazar ve [isPremiumProvider]'ı
/// geçersiz kılar → reklamlar anında gizlenir (adsActiveProvider).
class PurchaseController extends Notifier<PurchaseState> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  PurchaseState build() {
    final premium =
        ref.read(sharedPreferencesProvider).getBool(PrefKeys.isPremium) ?? false;
    ref.onDispose(() => _sub?.cancel());
    _init();
    return PurchaseState(isPremium: premium, loading: true);
  }

  Future<void> _init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      state = state.copyWith(storeAvailable: false, loading: false);
      return;
    }
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (e) => state = state.copyWith(error: '$e'),
    );
    final resp = await _iap.queryProductDetails(PremiumIds.all);
    state = state.copyWith(
      storeAvailable: true,
      loading: false,
      products: resp.productDetails,
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    var granted = false;
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(purchasePending: true);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          granted = true;
          break;
        case PurchaseStatus.error:
          state = state.copyWith(
              purchasePending: false, error: p.error?.message);
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(purchasePending: false);
          break;
      }
      // Her tamamlanmamış işlemi kapat (Play kuyrukta bırakmasın).
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    if (granted) await _grantPremium();
  }

  Future<void> _grantPremium() async {
    // Hesaba bağla: markPremiumPurchased() → /v1/me/premium + setBool(isPremium)
    // + isPremiumProvider invalidate → profilde/panelde görünür + reklam gizli.
    await ref.read(authControllerProvider.notifier).markPremiumPurchased();
    state = state.copyWith(isPremium: true, purchasePending: false);
  }

  /// Seçilen ürünü satın al (abonelik + tek-seferlik ikisi de buyNonConsumable).
  Future<void> buy(ProductDetails product) async {
    state = state.copyWith(purchasePending: true);
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  /// Önceki satın almaları geri yükle (yeni cihaz / yeniden kurulum).
  Future<void> restore() => _iap.restorePurchases();
}

final purchaseProvider =
    NotifierProvider<PurchaseController, PurchaseState>(PurchaseController.new);
