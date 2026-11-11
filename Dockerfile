# GodotDevTools Docker image: Godot 4.3 + the full gate + every CLI.
# Build: docker build -t godot-dev-tools .
# Run a tool: docker run --rm -v "$PWD:/work" godot-dev-tools run naming_conventions --dir=res://demo/naming --fail-on=file_name
# Run the gate: docker run --rm -v "$PWD:/work" godot-dev-tools gate
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive GODOT_VERSION=4.3-stable
RUN apt-get update -qq && apt-get install -y -qq curl unzip ca-certificates xvfb libgl1-mesa-dri libglx-mesa0 >/dev/null && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /opt/godot && curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" && unzip -q /tmp/godot.zip -d /opt/godot && rm /tmp/godot.zip && chmod +x /opt/godot/Godot_v${GODOT_VERSION}_linux.x86_64 && ln -s /opt/godot/Godot_v${GODOT_VERSION}_linux.x86_64 /usr/local/bin/godot
COPY tools/gdt /usr/local/bin/gdt
RUN chmod +x /usr/local/bin/gdt
WORKDIR /work
ENTRYPOINT ["gdt"]
CMD ["--help"]
