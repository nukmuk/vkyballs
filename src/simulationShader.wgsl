@group(0) @binding(0) var<storage, read_write> particles: array<ParticleData>;
@group(0) @binding(1) var<uniform> canvas: vec2<u32>;
@group(0) @binding(2) var<uniform> deltaTime: f32;

struct ParticleData {
	pos: vec2f,
	vel: vec2f,
}

const g = -9.81;
const particleSize = 0.05;
const damp = 0.8;

@compute
@workgroup_size(1)
fn computeMain() {
	let dt = deltaTime / 1000;
	for (var i = 0u; i < arrayLength(&particles); i++) {

		let aspect = f32(canvas.x) / f32(canvas.y);

		let rWall= aspect/2;
		let lWall= -rWall;
		let floor = 0.0;

		if particles[i].pos.y < floor + particleSize {
			particles[i].vel.y *= -1 * damp;
			particles[i].pos.y = 0.0 + particleSize;
		}

		if particles[i].pos.y > 1 - particleSize {
			particles[i].vel.y *= -1 * damp;
			particles[i].pos.y = 1 - particleSize;
		}

		if particles[i].pos.x < lWall + particleSize {
			particles[i].vel.x *= -1 * damp;
			particles[i].pos.x = lWall + particleSize;
		}

		if particles[i].pos.x > rWall - particleSize {
			particles[i].vel.x *= -1 * damp;
			particles[i].pos.x = rWall - particleSize;
		}

		particles[i].vel.y += g * dt;
		particles[i].pos += particles[i].vel * dt;
	}

}