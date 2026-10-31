## Fixture: the other half of the deliberate RefCounted reference circle.
class_name DemoChainB
extends RefCounted

## Typed partner reference back to DemoChainA - the circle is complete.
var partner: DemoChainA
var label := "chain_b"
