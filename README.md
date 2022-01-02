# Magic Tracker #

This is our little slave tracker and controller, designed for an ankle monitor or an implant.
Initially it will be touch control, but an owner hud would make implanting much easier.

# Architecture #

Because LSL is such a shit language, with shit for storage, a large chunk of the functionality
will actually be implemented in a web service we can run on a hosting site.  See [ConfigDB](/docs/ConfigDB.md)
for a detailed description of the Database.

The functionality that has to be in-world, namely a touch UI and actually controlling the avatar
is described in [InWorld](/docs/InWorld.md).

## Bugs

1. <s>Requesting and receiving travel auth while in an unpermitted sim doesn't cancel the TP timer.</s>
2. Adding the current sim doesn't cancel a TP timer (i.e. wearer leashed, owner adds).
