extends RefCounted

# Fixture for the coverage estimate: only one helper is mentioned.
func exercise_sample(subject: RefCounted) -> void:
	subject.call("covered_helper")
