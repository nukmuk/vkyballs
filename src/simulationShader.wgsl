@group(0) @binding(0) var<storage, read_write> particles: array<ParticleData>;
@group(0) @binding(2) var<uniform> particles: array<ParticleData>;

struct ParticleData {
	pos: vec2f,
	vel: vec2f,
}

const g = -9.81;

@compute
@workgroup_size(1)
fn computeMain() {
	for (var i = 0u; i < arrayLength(&particles); i++) {
		particles[i].pos += particles[i].vel;
	}

}