import 'package:flutter/material.dart';

/// What the player is trying to get when out of free help.
enum OfferKind { hint, undo, extraLife, unlockLevel }

/// Shared "Use N coins / Watch ad / Cancel" dialog used by every game.
/// Returns true if the player paid (coins or rewarded ad) and the game should
/// grant the item. Placeholder until the economy work lands: always false.
Future<bool> showContinueOffer(BuildContext context, OfferKind kind, {int? price}) async => false;
