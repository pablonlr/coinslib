import 'dart:typed_data';
import 'package:coinslib/src/payments/p2wsh.dart';

import 'models/networks.dart';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:coinslib/bech32/bech32.dart';
import 'payments/index.dart' show PaymentData;
import 'payments/p2pkh.dart';
import 'payments/p2wpkh.dart';
import 'payments/p2sh.dart';

class Address {
  static bool validateAddress(String address, [NetworkType? nw]) {
    try {
      addressToOutputScript(address, nw);
      return true;
    } catch (err) {
      return false;
    }
  }

  static bool _comparePrefixNetwork(
      List<int> keyBytes, Uint8List addresPrefix) {
    for (int i = 0; i < keyBytes.length; i++) {
      if (keyBytes[i] != addresPrefix[i]) {
        return false;
      }
    }
    return true;
  }

  static Uint8List addressToOutputScript(String address, [NetworkType? nw]) {
    NetworkType network = nw ?? bitcoin;
    var decodeBase58;
    var decodeBech32;

    try {
      decodeBase58 = bs58check.decode(address);
    } catch (err) {}

    if (decodeBase58 != null) {
      final prefix = decodeBase58.sublist(0, nw?.pubKeyHash.length);
      final data = decodeBase58.sublist(nw?.pubKeyHash.length);

      if (_comparePrefixNetwork(network.pubKeyHash, prefix)) {
        P2PKH p2pkh =
            P2PKH(data: PaymentData(address: address), network: network);
        return p2pkh.data.output!;
      }

      if (_comparePrefixNetwork(network.scriptHash, prefix)) {
        return createP2shOutputScript(data);
      }

      throw ArgumentError('Invalid version or Network mismatch');
    }

    try {
      decodeBech32 = segwit.decode(address);
    } catch (err) {}

    if (decodeBech32 != null) {
      if (network.bech32 != decodeBech32.hrp)
        throw new ArgumentError('Invalid prefix or Network mismatch');

      if (decodeBech32.version != 0)
        throw new ArgumentError('Invalid address version');

      final program = Uint8List.fromList(decodeBech32.program);
      final progLen = program.length;

      if (progLen == 20) {
        P2WPKH p2wpkh = new P2WPKH(
            data: new PaymentData(address: address), network: network);
        return p2wpkh.data.output!;
      }

      if (progLen == 32) {
        return createP2wshOutputScript(program);
      }

      throw ArgumentError('The bech32 witness program is not the correct size');
    }

    throw new ArgumentError(address + ' has no matching Script');
  }
}
