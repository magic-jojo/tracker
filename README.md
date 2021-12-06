# Magic Tracker #

This is our little slave tracker and controller, designed for an ankle monitor or an implant.
Initially it will be touch control, but an owner hud would make implanting much easier.

# Architecture #

Because LSL is such a shit language, with shit for storage, a large chunk of the functionality
will actually be implemented in a web service we can run on a hosting site.  See [ConfigDB](/docs/ConfigDB.md)
for a detailed description of the Database.

The functionality that has to be in-world, namely a touch UI and actually controlling the avatar
is described in [InWorld](/docs/InWorld.md).
