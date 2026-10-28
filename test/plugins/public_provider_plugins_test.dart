import 'package:flutter_test/flutter_test.dart';
import 'package:nlpa2/models/euicc_profile.dart';
import 'package:nlpa2/plugins/build_plugin_registry.dart';
import 'package:nlpa2/plugins/esim_cc_plugin.dart';
import 'package:nlpa2/plugins/esim_gg_plugin.dart';
import 'package:nlpa2/services/card_status_cache.dart';

void main() {
  tearDown(() => CardStatusCache().clear());

  test('public registry includes both provider integrations', () {
    final ids = BuildPluginRegistry.createPlugins().map((p) => p.id).toSet();
    expect(ids, containsAll(['esim_cc', 'esim_gg']));
  });

  test('provider integrations only match their own profile ranges', () {
    final cc = EuiccProfile(iccid: '8985223000000000001', enabled: false);
    final gg = EuiccProfile(iccid: '8937204010000000001', enabled: true);
    expect(EsimCcPlugin().isMatch(cc), isTrue);
    expect(EsimCcPlugin().isMatch(gg), isFalse);
    expect(EsimGgPlugin().isMatch(gg), isTrue);
    expect(EsimGgPlugin().isMatch(cc), isFalse);
    expect(EsimGgPlugin().getProfileCardBottomData(cc), isNull);
  });

  test('public eSIM.gg renders cached balance and package usage', () {
    final profile = EuiccProfile(iccid: '8937204010000000001', enabled: true);
    CardStatusCache().updateCache('esim_gg_${profile.iccid}', {
      'number': '3725000000',
      'balance': 12.345,
      'package_name': 'Test package',
      'total_data': 1000,
      'remaining_data': 250,
      'package_expiry': '2026-11-01',
    });
    final data = EsimGgPlugin().getProfileCardBottomData(profile)!;
    expect(data.balance, '12.35 €');
    expect(data.phoneNumber, startsWith('+372'));
    expect(data.packages.single.name, 'Test package');
    expect(data.packages.single.usedBytes, 750);
    expect(data.packages.single.totalBytes, 1000);
    expect(data.packages.single.expiry, '2026-11-01');
  });
}
