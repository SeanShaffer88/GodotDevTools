## Fixture: one half of a deliberate RefCounted reference circle.
class_name DemoChainA
extends RefCounted

## Typed partner reference - the other half points straight back here,
## so neither object can ever reach zero references.
var partner: DemoChainB
var label := "chain_a"
