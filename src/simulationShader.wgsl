@group(0) @binding(0) var<storage, read_write> particles: array<ParticleData>;
@group(0) @binding(2) var<uniform> deltaTime: f32;

struct ParticleData {
	pos: vec2f,
	vel: vec2f,
}

const g = -9.81;
const particleSize = 0.05;
const damp = 0.9;

@compute
@workgroup_size(1)
fn computeMain() {
	let dt = deltaTime / 1000;
	for (var i = 0u; i < arrayLength(&particles); i++) {

		if (particles[i].pos.y < 0.0 + particleSize) {
			particles[i].vel.y *= -1 * damp;
			particles[i].pos.y = 0.0 + particleSize;
		}

		particles[i].pos += particles[i].vel * dt;
		particles[i].vel.y += g * dt;
	}

}