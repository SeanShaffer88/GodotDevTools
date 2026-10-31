extends RefCounted
## Benchmark fixture: every bench_* method is timed by the Micro-Benchmark Harness.


func bench_sum_array() -> void:
    var total := 0
    for i in range(2000):
        total += i
    assert(total > 0)


func bench_string_build() -> void:
    var parts: PackedStringArray = []
    for i in range(200):
        parts.append(str(i))
    var _joined := ",".join(parts)


func helper_not_a_benchmark() -> int:
    return 1
