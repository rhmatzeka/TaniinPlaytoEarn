part of '../game_hud.dart';

enum _SwapMode { tani, tarikEth, isiKoin }

/// The swap house: three separate jobs instead of one generic from/to box.
class _SwapHousePanel extends StatelessWidget {
  const _SwapHousePanel({required this.farmState, required this.onClose});

  final FarmStateController farmState;
  final VoidCallback onClose;

  _SwapMode get _mode {
    if (farmState.swapFromAsset == SwapAsset.ethSepolia) return _SwapMode.isiKoin;
    if (farmState.swapToAsset == SwapAsset.ethSepolia) return _SwapMode.tarikEth;
    return _SwapMode.tani;
  }

  void _select(_SwapMode mode) {
    switch (mode) {
      case _SwapMode.tani:
        farmState.setSwapFromAsset(SwapAsset.gameCoin);
        farmState.setSwapToAsset(SwapAsset.taniSepolia);
      case _SwapMode.tarikEth:
        farmState.setSwapFromAsset(SwapAsset.gameCoin);
        farmState.setSwapToAsset(SwapAsset.ethSepolia);
      case _SwapMode.isiKoin:
        farmState.setSwapFromAsset(SwapAsset.ethSepolia);
        farmState.setSwapToAsset(SwapAsset.gameCoin);
    }
    farmState.prepareSwapAmount();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    return KayuPanel(
      title: 'Rumah Tukar',
      icon: Icons.swap_horiz,
      subtitle: 'Tukar Game Coin, token TANI, dan ETH Sepolia.',
      onClose: onClose,
      maxWidth: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwapBalances(farmState: farmState),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (m, label) in const [
                (_SwapMode.tani, 'Koin ⇄ TANI'),
                (_SwapMode.tarikEth, 'Tarik ETH'),
                (_SwapMode.isiKoin, 'Isi koin'),
              ])
                KayuButton(
                  label: label,
                  compact: true,
                  tone: m == mode ? KayuTone.utama : KayuTone.kedua,
                  onPressed: m == mode ? () {} : () => _select(m),
                ),
            ],
          ),
          const SizedBox(height: 16),
          switch (mode) {
            _SwapMode.tani => _SwapTani(farmState: farmState, onDone: onClose),
            _SwapMode.tarikEth => _SwapTarikEth(farmState: farmState, onDone: onClose),
            _SwapMode.isiKoin => _SwapIsiKoin(farmState: farmState),
          },
        ],
      ),
    );
  }
}

class _SwapBalances extends StatelessWidget {
  const _SwapBalances({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    final eth = farmState.walletNativeBalance;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _BalanceChip(label: 'Game Coin', child: CoinAmount(amount: farmState.coins, size: 20)),
        _BalanceChip(
          label: farmState.isLoggedIn ? 'TANI di wallet' : 'TANI (tamu)',
          child: Text('${farmState.tani}', style: Kayu.judul(20)),
        ),
        if (farmState.isLoggedIn)
          _BalanceChip(
            label: 'ETH Sepolia',
            child: Text(eth.isEmpty ? '…' : eth, style: Kayu.judul(20)),
          ),
      ],
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KayuWell(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Kayu.teks(14, color: Kayu.kremRedup)),
          child,
        ],
      ),
    );
  }
}

/// Amount picker shared by the three modes.
class _SwapAmount extends StatelessWidget {
  const _SwapAmount({required this.farmState, required this.unit, required this.max});

  final FarmStateController farmState;
  final String unit;
  final int max;

  @override
  Widget build(BuildContext context) {
    final amount = farmState.selectedSwapAmount.clamp(0, math.max(0, max)).toInt();
    return KayuWell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Jumlah', style: Kayu.teks(18))),
              Text('$amount $unit', style: Kayu.judul(24)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              activeTrackColor: Kayu.emas,
              inactiveTrackColor: Kayu.kayuGelap,
              thumbColor: Kayu.krem,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            ),
            child: Slider(
              value: amount.toDouble(),
              max: math.max(1, max).toDouble(),
              divisions: max > 0 && max <= 1000 ? max : null,
              onChanged: max <= 0 ? null : (v) => farmState.setSwapAmount(v.round()),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final (label, fraction) in const [('25%', 0.25), ('50%', 0.5), ('Semua', 1.0)])
                KayuButton(
                  label: label,
                  compact: true,
                  tone: KayuTone.kedua,
                  onPressed: max <= 0
                      ? null
                      : () => farmState.setSwapAmount(math.max(1, (max * fraction).round())),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwapNote extends StatelessWidget {
  const _SwapNote(this.lines);

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 10),
                  child: Icon(Icons.circle, size: 8, color: Kayu.emas),
                ),
                Expanded(child: Text(line, style: Kayu.teks(17))),
              ],
            ),
          ),
      ],
    );
  }
}

class _SwapResult extends StatelessWidget {
  const _SwapResult({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(text, style: Kayu.judul(24, color: Kayu.krem)),
    );
  }
}

class _NeedLogin extends StatelessWidget {
  const _NeedLogin({required this.farmState, required this.reason});

  final FarmStateController farmState;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return KayuWell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reason, style: Kayu.teks(18)),
          const SizedBox(height: 12),
          KayuButton(
            label: 'Masuk dengan Privy',
            icon: Icons.login,
            onPressed: farmState.canLogin
                ? () async {
                    final url = await farmState.prepareLoginUrl();
                    await PlatformBridge.openUrl(url, sameTab: true);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _SwapTani extends StatelessWidget {
  const _SwapTani({required this.farmState, required this.onDone});

  final FarmStateController farmState;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final toTani = farmState.swapFromAsset == SwapAsset.gameCoin;
    final max = farmState.swapSourceBalance;
    final amount = farmState.selectedSwapAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SwapNote([
          '1 Game Coin = 1 TANI.',
          farmState.onChainMode
              ? 'TANI adalah token ERC-20 di Sepolia, masuk ke wallet-mu.'
              : 'Mode tamu: tukar tersimpan di perangkat. Masuk supaya TANI masuk ke wallet.',
        ]),
        const SizedBox(height: 10),
        KayuButton(
          label: toTani ? 'Arah: Koin → TANI' : 'Arah: TANI → Koin',
          icon: Icons.swap_vert,
          compact: true,
          tone: KayuTone.kedua,
          onPressed: farmState.reverseSwapAssets,
        ),
        const SizedBox(height: 12),
        _SwapAmount(farmState: farmState, unit: toTani ? 'koin' : 'TANI', max: max),
        _SwapResult(text: toTani ? 'Kamu dapat $amount TANI' : 'Kamu dapat $amount Game Coin'),
        KayuButton(
          label: amount > 0 ? 'Tukar sekarang' : (toTani ? 'Koin kosong' : 'TANI kosong'),
          expand: true,
          onPressed: amount > 0
              ? () async {
                  if (await farmState.swapSelectedAssets()) onDone();
                }
              : null,
        ),
      ],
    );
  }
}

class _SwapTarikEth extends StatelessWidget {
  const _SwapTarikEth({required this.farmState, required this.onDone});

  final FarmStateController farmState;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    if (!farmState.onChainMode) {
      return _NeedLogin(
        farmState: farmState,
        reason: 'Tarik ETH mengirim Sepolia ETH sungguhan ke wallet-mu, jadi kamu perlu masuk dulu.',
      );
    }
    final max = farmState.swapSourceBalance;
    final amount = farmState.selectedSwapAmount;
    final min = FarmStateController.minEthSwapAmount;
    final enough = amount >= min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SwapNote([
          farmState.swapRateHintLabel.isEmpty
              ? 'Game Coin ditukar ke Sepolia ETH dan dikirim ke wallet-mu.'
              : farmState.swapRateHintLabel,
          'Minimal $min koin sekali tarik. Batas 0,01 ETH per hari per wallet.',
          'ETH dikirim dari server; tunggu konfirmasi Sepolia sekitar 15 detik.',
        ]),
        const SizedBox(height: 12),
        _SwapAmount(farmState: farmState, unit: 'koin', max: max),
        _SwapResult(
          text: 'Kamu dapat ${farmState.swapCardAmountLabel(SwapAsset.ethSepolia, amount, to: true)}',
        ),
        KayuButton(
          label: enough ? 'Tarik ETH' : 'Minimal $min koin',
          icon: Icons.outbox,
          expand: true,
          onPressed: enough
              ? () async {
                  if (await farmState.swapSelectedAssets()) onDone();
                }
              : null,
        ),
      ],
    );
  }
}

class _SwapIsiKoin extends StatelessWidget {
  const _SwapIsiKoin({required this.farmState});

  final FarmStateController farmState;

  @override
  Widget build(BuildContext context) {
    if (!farmState.onChainMode) {
      return _NeedLogin(
        farmState: farmState,
        reason: 'Isi koin dibayar dengan Sepolia ETH dari wallet-mu, jadi kamu perlu masuk dulu.',
      );
    }
    final amount = math.max(FarmStateController.minEthSwapAmount, farmState.selectedSwapAmount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SwapNote([
          'Bayar Sepolia ETH dari wallet Privy-mu, lalu Game Coin masuk ke kebun.',
          'Pembayaran dikonfirmasi di halaman Privy, setelah itu kamu kembali ke game.',
          'Minimal ${FarmStateController.minEthSwapAmount} koin.',
        ]),
        const SizedBox(height: 12),
        _SwapAmount(farmState: farmState, unit: 'koin', max: FarmStateController.maxOnChainSwapAmount),
        _SwapResult(text: 'Kamu bayar ${farmState.swapCardAmountLabel(SwapAsset.ethSepolia, amount, to: false)}'),
        KayuButton(
          label: 'Bayar dengan ETH',
          icon: Icons.account_balance_wallet,
          expand: true,
          onPressed: () => farmState.swapSelectedAssets(),
        ),
      ],
    );
  }
}
